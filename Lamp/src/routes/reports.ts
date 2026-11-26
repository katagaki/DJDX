import { verifySignedRequest } from "../auth";
import type { Env } from "../env";
import { DIFFICULTIES, PLAY_TYPES, normalizeSongKey } from "../games/iidx";
import { HttpError, json, nowSeconds, optionalString, parseJSON, readBody, requireString } from "../http";
import { consumeIPQuota } from "../iplimit";
import { consumeDailyQuota } from "../limits";
import { loadSongAliases, requireGameAndSource } from "./scores";

export const REPORT_REASONS = ["impossible_score", "anomalous_rate", "duplicate_chart", "wrong_metadata", "other"] as const;

export async function submitReport(request: Request, env: Env): Promise<Response> {
  const body = await readBody(request);
  const { contributor, tier } = await verifySignedRequest(request, env, body);
  const payload = parseJSON(body);
  const { game, source } = requireGameAndSource(payload);
  const title = requireString(payload.title, "title", 200);
  if (!PLAY_TYPES.includes(payload.playType as (typeof PLAY_TYPES)[number])) throw new HttpError(400, "invalid_field", "playType");
  if (!DIFFICULTIES.includes(payload.difficulty as (typeof DIFFICULTIES)[number])) throw new HttpError(400, "invalid_field", "difficulty");
  if (!REPORT_REASONS.includes(payload.reason as (typeof REPORT_REASONS)[number])) throw new HttpError(400, "invalid_field", "reason");
  const note = optionalString(payload.note, "note", 280);
  const snapshotAt = typeof payload.snapshotAt === "number" && Number.isInteger(payload.snapshotAt) ? payload.snapshotAt : null;
  await consumeIPQuota(request, env, "report");
  await consumeDailyQuota(env, contributor.id, "report", tier);

  const key = normalizeSongKey(title);
  const songKey = (await loadSongAliases(env, game)).get(key) ?? key;
  const result = await env.DB.prepare(
    `INSERT INTO reports (contributor_id, game, source, song_key, play_type, difficulty, reason, note, snapshot_at, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT (contributor_id, game, source, song_key, play_type, difficulty) DO NOTHING`,
  )
    .bind(contributor.id, game, source, songKey, payload.playType, payload.difficulty, payload.reason, note, snapshotAt, nowSeconds())
    .run();
  return json({ received: true, duplicate: result.meta.changes === 0 }, result.meta.changes === 0 ? 200 : 201);
}
