import type { TrustTier } from "./auth";
import type { Env } from "./env";
import { rateLimitSubject } from "./iplimit";
import { HttpError, nowSeconds } from "./http";

export type LimitedAction = "upload" | "report" | "heartbeat";

const DAILY_LIMITS: Record<LimitedAction, Record<TrustTier, number>> = {
  upload: { attested_prod: 50, attested_dev: 50, unattested: 10 },
  report: { attested_prod: 20, attested_dev: 20, unattested: 5 },
  heartbeat: { attested_prod: 3, attested_dev: 3, unattested: 3 },
};

export function today(): number {
  return Math.floor(nowSeconds() / 86400);
}

export async function consumeDailyQuota(env: Env, contributorId: string, action: LimitedAction, tier: TrustTier): Promise<void> {
  const row = await env.DB.prepare(
    `INSERT INTO usage_counters (contributor_id, action, day, count) VALUES (?, ?, ?, 1)
     ON CONFLICT (contributor_id, action, day) DO UPDATE SET count = count + 1
     RETURNING count`,
  )
    .bind(contributorId, action, today())
    .first<{ count: number }>();
  if ((row?.count ?? 0) > DAILY_LIMITS[action][tier]) throw new HttpError(429, "daily_limit_reached");
}

export async function limitByIP(request: Request, env: Env, scope: string): Promise<void> {
  if (!env.IP_LIMITER) return;
  const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
  const { success } = await env.IP_LIMITER.limit({ key: `${scope}:${rateLimitSubject(ip)}` });
  if (!success) throw new HttpError(429, "rate_limited");
}
