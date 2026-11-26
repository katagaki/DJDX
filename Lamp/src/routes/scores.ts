import { verifySignedRequest } from "../auth";
import type { Env } from "../env";
import { chartRuleKey, isValidSource, parseRecord, validateRecord, type ChartRule } from "../games/iidx";
import { HttpError, json, nowSeconds, parseJSON, readBody } from "../http";
import { consumeIPQuota } from "../iplimit";
import { consumeDailyQuota } from "../limits";
import { markDirty } from "../snapshots";

const MAX_RECORDS = 5000;
const BATCH_SIZE = 200;

export async function loadSongAliases(env: Env, game: string): Promise<Map<string, string>> {
  const rows = await env.DB.prepare("SELECT alias_key, canonical_key FROM song_aliases WHERE game = ?").bind(game).all<{
    alias_key: string;
    canonical_key: string;
  }>();
  return new Map(rows.results.map((row) => [row.alias_key, row.canonical_key]));
}

export function requireGameAndSource(payload: Record<string, unknown>): { game: string; source: string } {
  if (payload.game !== "iidx") throw new HttpError(400, "unsupported_game");
  if (!isValidSource(payload.source)) throw new HttpError(400, "invalid_field", "source");
  return { game: payload.game, source: payload.source };
}

export async function uploadScores(request: Request, env: Env): Promise<Response> {
  const body = await readBody(request);
  const { contributor, tier } = await verifySignedRequest(request, env, body);
  const payload = parseJSON(body);
  const { game, source } = requireGameAndSource(payload);
  if (!Array.isArray(payload.records) || payload.records.length > MAX_RECORDS) throw new HttpError(400, "invalid_field", "records");
  await consumeIPQuota(request, env, "upload");
  await consumeDailyQuota(env, contributor.id, "upload", tier);

  const aliases = await loadSongAliases(env, game);
  const ruleRows = await env.DB.prepare("SELECT song_key, play_type, difficulty, max_notes FROM chart_rules WHERE game = ?").bind(game).all<{
    song_key: string;
    play_type: string;
    difficulty: string;
    max_notes: number | null;
  }>();
  const rules = new Map<string, ChartRule>(
    ruleRows.results.map((row) => [chartRuleKey(row.song_key, row.play_type, row.difficulty), { maxNotes: row.max_notes }]),
  );

  const rejected: { index: number; reason: string }[] = [];
  const now = nowSeconds();
  const statements: D1PreparedStatement[] = [];
  payload.records.forEach((input, index) => {
    const record = parseRecord(input, (key) => aliases.get(key) ?? key);
    if (typeof record === "string") return rejected.push({ index, reason: record });
    const reason = validateRecord(record, rules.get(chartRuleKey(record.songKey, record.playType, record.difficulty)));
    if (reason) return rejected.push({ index, reason });
    statements.push(
      env.DB.prepare(
        `INSERT INTO scores (contributor_id, game, source, song_key, play_type, difficulty, lamp, ex_score, pgreat, great, miss_count, trust_tier, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT (contributor_id, game, source, song_key, play_type, difficulty) DO UPDATE SET
           lamp = excluded.lamp, ex_score = excluded.ex_score, pgreat = excluded.pgreat, great = excluded.great,
           miss_count = excluded.miss_count, trust_tier = excluded.trust_tier, updated_at = excluded.updated_at`,
      ).bind(
        contributor.id,
        game,
        source,
        record.songKey,
        record.playType,
        record.difficulty,
        record.lamp,
        record.exScore,
        record.pgreat,
        record.great,
        record.missCount,
        tier,
        now,
      ),
    );
  });

  if (contributor.excluded === 0) {
    for (let i = 0; i < statements.length; i += BATCH_SIZE) await env.DB.batch(statements.slice(i, i + BATCH_SIZE));
    if (statements.length > 0) await markDirty(env, game, source);
  }
  return json({ accepted: statements.length, rejected, trustTier: tier });
}
