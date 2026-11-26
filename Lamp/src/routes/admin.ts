import { devSignIn, requireAdmin, requireSameOrigin } from "../access";
import type { Env } from "../env";
import { DIFFICULTIES, PLAY_TYPES, normalizeSongKey } from "../games/iidx";
import { HttpError, json, nowSeconds, parseJSON, readBody, requireString } from "../http";
import { rebuildAllSnapshots, rebuildSnapshots } from "../snapshots";
import { requireGameAndSource } from "./scores";

const REPORT_STATUSES = ["open", "resolved", "dismissed"];

function chartFields(payload: Record<string, unknown>): { songKey: string; playType: string; difficulty: string } {
  const songKey = normalizeSongKey(requireString(payload.title, "title", 200));
  if (!PLAY_TYPES.includes(payload.playType as (typeof PLAY_TYPES)[number])) throw new HttpError(400, "invalid_field", "playType");
  if (!DIFFICULTIES.includes(payload.difficulty as (typeof DIFFICULTIES)[number])) throw new HttpError(400, "invalid_field", "difficulty");
  return { songKey, playType: payload.playType as string, difficulty: payload.difficulty as string };
}

type SourceRef = { game: string; source: string };

async function affectedSources(env: Env, where: string, ...bindings: unknown[]): Promise<SourceRef[]> {
  const rows = await env.DB.prepare(`SELECT DISTINCT game, source FROM scores WHERE ${where}`).bind(...bindings).all<SourceRef>();
  return rows.results;
}

function queryObject(url: URL): Record<string, unknown> {
  return Object.fromEntries(url.searchParams.entries());
}

const ADMIN_PAGE_HEADERS = {
  "Content-Security-Policy": "default-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "no-referrer",
  "Cache-Control": "no-store",
};

async function serveAdminAsset(request: Request, env: Env): Promise<Response> {
  const asset = await env.ASSETS.fetch(request);
  const response = new Response(asset.body, asset);
  for (const [name, value] of Object.entries(ADMIN_PAGE_HEADERS)) response.headers.set(name, value);
  return response;
}

export async function handleAdmin(request: Request, env: Env, url: URL): Promise<Response> {
  const signIn = await devSignIn(request, env, url);
  if (signIn) return signIn;
  const admin = await requireAdmin(request, env, url);
  requireSameOrigin(request, url);
  const path = url.pathname.replace(/^\/admin/, "");
  const method = request.method;

  if (method === "GET" && (path === "" || path === "/" || path === "/app.js" || path === "/app.css")) {
    if (path === "") return Response.redirect(`${url.origin}/admin/`, 301);
    return serveAdminAsset(request, env);
  }
  if (method === "GET" && path === "/api/me") return json({ admin });

  if (method === "GET" && path === "/reports") {
    const status = url.searchParams.get("status") ?? "open";
    if (!REPORT_STATUSES.includes(status)) throw new HttpError(400, "invalid_field", "status");
    const rows = await env.DB.prepare(
      `SELECT r.id, r.game, r.source, r.song_key, r.play_type, r.difficulty, r.reason, r.note, r.snapshot_at, r.status, r.created_at, r.resolved_at, r.resolved_by,
         (SELECT COUNT(*) FROM reports o WHERE o.game = r.game AND o.source = r.source AND o.song_key = r.song_key
           AND o.play_type = r.play_type AND o.difficulty = r.difficulty AND o.status = 'open') AS open_reports_for_chart
       FROM reports r WHERE r.status = ? ORDER BY open_reports_for_chart DESC, r.created_at DESC LIMIT 200`,
    )
      .bind(status)
      .all();
    return json({ reports: rows.results });
  }

  const reportMatch = path.match(/^\/reports\/(\d+)$/);
  if (method === "PATCH" && reportMatch) {
    const payload = parseJSON(await readBody(request));
    if (!["resolved", "dismissed", "open"].includes(payload.status as string)) throw new HttpError(400, "invalid_field", "status");
    const reopened = payload.status === "open";
    const result = await env.DB.prepare("UPDATE reports SET status = ?, resolved_at = ?, resolved_by = ? WHERE id = ?")
      .bind(payload.status, reopened ? null : nowSeconds(), reopened ? null : admin, Number(reportMatch[1]))
      .run();
    if (!result.meta.changes) throw new HttpError(404, "not_found");
    return json({ updated: true });
  }

  if (method === "GET" && path === "/charts") {
    const query = queryObject(url);
    const { game, source } = requireGameAndSource(query);
    const { songKey, playType, difficulty } = chartFields(query);
    const rows = await env.DB.prepare(
      `SELECT s.contributor_id, s.trust_tier, s.lamp, s.ex_score, s.pgreat, s.great, s.miss_count, s.updated_at, c.excluded
       FROM scores s JOIN contributors c ON c.id = s.contributor_id
       WHERE s.game = ? AND s.source = ? AND s.song_key = ? AND s.play_type = ? AND s.difficulty = ?
       ORDER BY s.ex_score DESC LIMIT 1000`,
    )
      .bind(game, source, songKey, playType, difficulty)
      .all();
    const rule = await env.DB.prepare("SELECT max_notes, hidden FROM chart_rules WHERE game = ? AND song_key = ? AND play_type = ? AND difficulty = ?")
      .bind(game, songKey, playType, difficulty)
      .first();
    return json({ songKey, rule, rows: rows.results });
  }

  if (method === "POST" && path === "/purge") {
    const payload = parseJSON(await readBody(request));
    const { game, source } = requireGameAndSource(payload);
    const conditions = ["game = ?", "source = ?"];
    const bindings: unknown[] = [game, source];
    if (payload.contributorId !== undefined) {
      conditions.push("contributor_id = ?");
      bindings.push(requireString(payload.contributorId, "contributorId", 64));
    }
    if (payload.title !== undefined) {
      const chart = chartFields(payload);
      conditions.push("song_key = ?", "play_type = ?", "difficulty = ?");
      bindings.push(chart.songKey, chart.playType, chart.difficulty);
    }
    if (payload.minExScore !== undefined) {
      if (typeof payload.minExScore !== "number") throw new HttpError(400, "invalid_field", "minExScore");
      conditions.push("ex_score >= ?");
      bindings.push(payload.minExScore);
    }
    if (bindings.length === 2) throw new HttpError(400, "purge_requires_filter");
    const result = await env.DB.prepare(`DELETE FROM scores WHERE ${conditions.join(" AND ")}`).bind(...bindings).run();
    await rebuildSnapshots(env, [{ game, source }]);
    return json({ deleted: result.meta.changes });
  }

  const quarantineMatch = path.match(/^\/contributors\/([A-Za-z0-9_-]{1,64})\/quarantine$/);
  if (method === "POST" && quarantineMatch) {
    const payload = parseJSON(await readBody(request));
    const excluded = payload.excluded === false ? 0 : 1;
    const contributorId = quarantineMatch[1]!;
    const result = await env.DB.prepare("UPDATE contributors SET excluded = ? WHERE id = ?").bind(excluded, contributorId).run();
    if (!result.meta.changes) throw new HttpError(404, "not_found");
    await rebuildSnapshots(env, await affectedSources(env, "contributor_id = ?", contributorId));
    return json({ contributorId, excluded: excluded === 1 });
  }

  if (method === "PUT" && path === "/chart-rules") {
    const payload = parseJSON(await readBody(request));
    if (payload.game !== "iidx") throw new HttpError(400, "unsupported_game");
    const { songKey, playType, difficulty } = chartFields(payload);
    const maxNotes = payload.maxNotes === null || payload.maxNotes === undefined ? null : payload.maxNotes;
    if (maxNotes !== null && (typeof maxNotes !== "number" || !Number.isInteger(maxNotes) || maxNotes < 1 || maxNotes > 5000)) {
      throw new HttpError(400, "invalid_field", "maxNotes");
    }
    const hidden = payload.hidden === true ? 1 : 0;
    await env.DB.prepare(
      `INSERT INTO chart_rules (game, song_key, play_type, difficulty, max_notes, hidden) VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT (game, song_key, play_type, difficulty) DO UPDATE SET max_notes = excluded.max_notes, hidden = excluded.hidden`,
    )
      .bind(payload.game, songKey, playType, difficulty, maxNotes, hidden)
      .run();
    const chartWhere = "song_key = ? AND play_type = ? AND difficulty = ?";
    const sources = await affectedSources(env, `game = ? AND ${chartWhere}`, payload.game, songKey, playType, difficulty);
    let purged = 0;
    if (maxNotes !== null) {
      const result = await env.DB.prepare(
        `DELETE FROM scores WHERE game = ? AND ${chartWhere}
         AND (ex_score > ? OR COALESCE(miss_count, 0) > ? OR COALESCE(pgreat, 0) + COALESCE(great, 0) > ?)`,
      )
        .bind(payload.game, songKey, playType, difficulty, 2 * maxNotes, maxNotes, maxNotes)
        .run();
      purged = result.meta.changes;
    }
    await rebuildSnapshots(env, sources);
    return json({ songKey, maxNotes, hidden: hidden === 1, purged });
  }

  if (method === "PUT" && path === "/song-aliases") {
    const payload = parseJSON(await readBody(request));
    if (payload.game !== "iidx") throw new HttpError(400, "unsupported_game");
    const alias = normalizeSongKey(requireString(payload.alias, "alias", 200));
    const canonical = normalizeSongKey(requireString(payload.canonical, "canonical", 200));
    if (alias === canonical) throw new HttpError(400, "invalid_field", "alias");
    const sources = await affectedSources(env, "game = ? AND song_key = ?", payload.game, alias);
    await env.DB.batch([
      env.DB.prepare(
        `INSERT INTO song_aliases (game, alias_key, canonical_key) VALUES (?, ?, ?)
         ON CONFLICT (game, alias_key) DO UPDATE SET canonical_key = excluded.canonical_key`,
      ).bind(payload.game, alias, canonical),
      env.DB.prepare("UPDATE song_aliases SET canonical_key = ? WHERE game = ? AND canonical_key = ?").bind(canonical, payload.game, alias),
      env.DB.prepare("UPDATE OR REPLACE scores SET song_key = ? WHERE game = ? AND song_key = ?").bind(canonical, payload.game, alias),
    ]);
    await rebuildSnapshots(env, sources);
    return json({ alias, canonical });
  }

  if (method === "POST" && path === "/rebuild") {
    const payload = parseJSON(await readBody(request));
    if (payload.game !== undefined || payload.source !== undefined) {
      return json({ rebuilt: await rebuildSnapshots(env, [requireGameAndSource(payload)]) });
    }
    return json({ rebuilt: await rebuildAllSnapshots(env) });
  }

  throw new HttpError(404, "not_found");
}
