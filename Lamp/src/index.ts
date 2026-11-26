import { issueChallenge } from "./auth";
import type { Env } from "./env";
import { HttpError, errorResponse, json, nowSeconds } from "./http";
import { purgeExpiredIPWindows } from "./iplimit";
import { limitByIP, today } from "./limits";
import { handleAdmin } from "./routes/admin";
import { deleteSelf, deleteWithCode, enroll, heartbeat, purgeInactiveContributors } from "./routes/contributors";
import { submitReport } from "./routes/reports";
import { uploadScores } from "./routes/scores";
import { rebuildAllSnapshots, serveSnapshot } from "./snapshots";

const INACTIVITY_LIMIT_SECONDS = 180 * 86400;
const CLOSED_REPORT_RETENTION_SECONDS = 90 * 86400;
const DAILY_REBUILD_CRON = "0 20 * * *";

async function route(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const { pathname } = url;
  const method = request.method;

  if (pathname === "/" && (method === "GET" || method === "HEAD")) return Response.redirect(env.REPOSITORY_URL, 302);
  if (pathname === "/admin" || pathname.startsWith("/admin/")) return handleAdmin(request, env, url);

  if (method === "GET" || method === "HEAD") {
    const snapshot = pathname.match(/^\/v1\/snapshots\/((?:index)|(?:[a-z]+\/[a-z0-9-]+))\.json$/);
    if (snapshot) return serveSnapshot(request, env, `${snapshot[1]}.json`);
  }

  if (method === "POST" && pathname === "/v1/challenge") {
    await limitByIP(request, env, "challenge");
    return json(await issueChallenge(env));
  }
  if (method === "POST" && pathname === "/v1/contributors") return enroll(request, env);
  if (method === "DELETE" && pathname === "/v1/contributors/me") return deleteSelf(request, env);
  if (method === "POST" && pathname === "/v1/heartbeat") return heartbeat(request, env);
  if (method === "POST" && pathname === "/v1/deletions") return deleteWithCode(request, env);
  if (method === "POST" && pathname === "/v1/scores") return uploadScores(request, env);
  if (method === "POST" && pathname === "/v1/reports") return submitReport(request, env);

  throw new HttpError(404, "not_found");
}

export default {
  async fetch(request, env): Promise<Response> {
    try {
      return await route(request, env);
    } catch (error) {
      return errorResponse(error);
    }
  },

  async scheduled(controller, env, ctx): Promise<void> {
    ctx.waitUntil(
      (async () => {
        await env.DB.batch([
          env.DB.prepare("DELETE FROM challenges WHERE expires_at <= ?").bind(nowSeconds()),
          env.DB.prepare("DELETE FROM usage_counters WHERE day < ?").bind(today() - 2),
          env.DB.prepare("DELETE FROM reports WHERE status != 'open' AND resolved_at < ?").bind(nowSeconds() - CLOSED_REPORT_RETENTION_SECONDS),
          purgeExpiredIPWindows(env),
        ]);
        if (controller.cron !== DAILY_REBUILD_CRON) return;
        await purgeInactiveContributors(env, INACTIVITY_LIMIT_SECONDS);
        await rebuildAllSnapshots(env);
      })(),
    );
  },
} satisfies ExportedHandler<Env>;
