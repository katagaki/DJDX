import type { Env } from "./env";
import { LAMP_COUNT } from "./games/iidx";
import { nowSeconds } from "./http";

export const MIN_SAMPLE = 10;
export const SCORE_BUCKET_WIDTH = 10;
export const MIN_BUCKET_COUNT = 3;
export const MIN_CONTRIBUTOR_AGE_SECONDS = 3 * 86400;
const INDEX_KEY = "index.json";

interface ChartSnapshot {
  n: number;
  lamps: number[];
  rates: number[];
  scores: [number, number][];
}

export function snapshotKey(game: string, source: string): string {
  return `${game}/${source}.json`;
}

export async function markDirty(env: Env, game: string, source: string): Promise<void> {
  await env.DB.prepare("INSERT OR REPLACE INTO dirty_snapshots (game, source, marked_at) VALUES (?, ?, ?)").bind(game, source, Date.now()).run();
}

export function markDirtyForContributor(env: Env, contributorId: string): D1PreparedStatement {
  return env.DB.prepare(
    "INSERT OR REPLACE INTO dirty_snapshots (game, source, marked_at) SELECT DISTINCT game, source, ? FROM scores WHERE contributor_id = ?",
  ).bind(Date.now(), contributorId);
}

function chartFilter(): string {
  return `FROM scores s
    JOIN contributors c ON c.id = s.contributor_id
    LEFT JOIN chart_rules r ON r.game = s.game AND r.song_key = s.song_key AND r.play_type = s.play_type AND r.difficulty = s.difficulty
    WHERE s.game = ? AND s.source = ? AND c.excluded = 0 AND c.created_at <= ? AND COALESCE(r.hidden, 0) = 0`;
}

export function mergeSmallBuckets(buckets: [number, number][], minimum = MIN_BUCKET_COUNT): [number, number][] {
  const merged: [number, number][] = [];
  let carry = 0;
  for (let i = buckets.length - 1; i >= 0; i--) {
    const [start, count] = buckets[i]!;
    carry += count;
    if (carry >= minimum) {
      merged.unshift([start, carry]);
      carry = 0;
    }
  }
  if (carry > 0) {
    const lowest = merged[0];
    if (lowest) lowest[1] += carry;
    else if (buckets[0]) merged.push([buckets[0][0], carry]);
  }
  if (merged[0] && buckets[0]) merged[0][0] = buckets[0][0];
  return merged;
}

function round(value: number): number {
  return Math.round(value * 10000) / 10000;
}

export async function rebuildSnapshot(env: Env, game: string, source: string): Promise<number> {
  const cutoff = nowSeconds() - MIN_CONTRIBUTOR_AGE_SECONDS;
  const [lampRows, scoreRows] = await env.DB.batch<{ song_key: string; play_type: string; difficulty: string; bucket: number; n: number }>([
    env.DB.prepare(`SELECT s.song_key, s.play_type, s.difficulty, s.lamp AS bucket, COUNT(*) AS n ${chartFilter()} GROUP BY 1, 2, 3, 4`).bind(game, source, cutoff),
    env.DB.prepare(`SELECT s.song_key, s.play_type, s.difficulty, s.ex_score / ? AS bucket, COUNT(*) AS n ${chartFilter()} GROUP BY 1, 2, 3, 4 ORDER BY 4`).bind(
      SCORE_BUCKET_WIDTH,
      game,
      source,
      cutoff,
    ),
  ]);

  const charts = new Map<string, { songKey: string; playType: string; difficulty: string; snapshot: ChartSnapshot }>();
  const chartFor = (row: { song_key: string; play_type: string; difficulty: string }) => {
    const key = `${row.song_key}\u0000${row.play_type}\u0000${row.difficulty}`;
    let chart = charts.get(key);
    if (!chart) {
      chart = {
        songKey: row.song_key,
        playType: row.play_type,
        difficulty: row.difficulty,
        snapshot: { n: 0, lamps: new Array(LAMP_COUNT).fill(0), rates: [], scores: [] },
      };
      charts.set(key, chart);
    }
    return chart.snapshot;
  };

  for (const row of lampRows?.results ?? []) {
    const snapshot = chartFor(row);
    snapshot.lamps[row.bucket - 1] = row.n;
    snapshot.n += row.n;
  }
  for (const row of scoreRows?.results ?? []) chartFor(row).scores.push([row.bucket * SCORE_BUCKET_WIDTH, row.n]);

  const songs: Record<string, Record<string, Record<string, ChartSnapshot>>> = {};
  let published = 0;
  for (const { songKey, playType, difficulty, snapshot } of charts.values()) {
    if (snapshot.n < MIN_SAMPLE) continue;
    snapshot.scores = mergeSmallBuckets(snapshot.scores);
    let atLeast = snapshot.n;
    snapshot.rates = snapshot.lamps.map((count) => {
      const rate = round(atLeast / snapshot.n);
      atLeast -= count;
      return rate;
    });
    ((songs[songKey] ??= {})[playType] ??= {})[difficulty] = snapshot;
    published++;
  }

  const generatedAt = nowSeconds();
  const body = JSON.stringify({
    version: 1,
    game,
    source,
    generatedAt,
    minSample: MIN_SAMPLE,
    scoreBucketWidth: SCORE_BUCKET_WIDTH,
    lampOrder: ["FAILED", "ASSIST CLEAR", "EASY CLEAR", "CLEAR", "HARD CLEAR", "EX HARD CLEAR", "FULLCOMBO CLEAR"],
    songs,
  });
  await env.SNAPSHOTS.put(snapshotKey(game, source), body, {
    httpMetadata: { contentType: "application/json; charset=utf-8" },
    customMetadata: { game, source, generatedAt: String(generatedAt), charts: String(published) },
  });
  return published;
}

export async function rebuildIndex(env: Env): Promise<void> {
  const sources: { game: string; source: string; generatedAt: number; charts: number; path: string }[] = [];
  let cursor: string | undefined;
  do {
    const page = await env.SNAPSHOTS.list({ cursor, include: ["customMetadata"] });
    for (const object of page.objects) {
      const meta = object.customMetadata;
      if (object.key === INDEX_KEY || !meta?.game || !meta.source) continue;
      sources.push({
        game: meta.game,
        source: meta.source,
        generatedAt: Number(meta.generatedAt),
        charts: Number(meta.charts),
        path: `/v1/snapshots/${object.key}`,
      });
    }
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor);
  await env.SNAPSHOTS.put(INDEX_KEY, JSON.stringify({ version: 1, generatedAt: nowSeconds(), sources }), {
    httpMetadata: { contentType: "application/json; charset=utf-8" },
  });
}

export async function rebuildSnapshots(env: Env, sources: { game: string; source: string }[]): Promise<{ game: string; source: string; charts: number }[]> {
  const rebuilt: { game: string; source: string; charts: number }[] = [];
  for (const { game, source } of sources) {
    rebuilt.push({ game, source, charts: await rebuildSnapshot(env, game, source) });
    await env.DB.prepare("DELETE FROM dirty_snapshots WHERE game = ? AND source = ?").bind(game, source).run();
  }
  if (rebuilt.length > 0) await rebuildIndex(env);
  return rebuilt;
}

export async function rebuildAllSnapshots(env: Env): Promise<{ game: string; source: string; charts: number }[]> {
  const sources = await env.DB.prepare(
    "SELECT DISTINCT game, source FROM scores UNION SELECT game, source FROM dirty_snapshots ORDER BY 1, 2",
  ).all<{ game: string; source: string }>();
  return rebuildSnapshots(env, sources.results);
}

export async function serveSnapshot(request: Request, env: Env, key: string): Promise<Response> {
  const object = await env.SNAPSHOTS.get(key, { onlyIf: request.headers });
  if (!object) return new Response("Not Found", { status: 404 });
  const headers = new Headers({
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "public, max-age=300",
    ETag: object.httpEtag,
    "Access-Control-Allow-Origin": "*",
  });
  if (!("body" in object)) return new Response(null, { status: 304, headers });
  return new Response(object.body, { headers });
}
