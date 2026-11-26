import { toBase64Url, utf8 } from "./encoding";
import type { Env } from "./env";
import { HttpError, nowSeconds } from "./http";

export const IP_WINDOW_SECONDS = 3600;

export const IP_HOURLY_LIMITS = {
  upload: 3,
  enroll: 3,
  report: 10,
} as const;

export type IPLimitedAction = keyof typeof IP_HOURLY_LIMITS;

export function rateLimitSubject(ip: string): string {
  if (!ip.includes(":")) return ip;
  const groups = ip.split("::");
  const head = groups[0] ? groups[0].split(":") : [];
  const tail = groups.length > 1 && groups[1] ? groups[1].split(":") : [];
  const full = [...head, ...new Array(Math.max(0, 8 - head.length - tail.length)).fill("0"), ...tail];
  return `${full.slice(0, 4).map((group) => group.toLowerCase().replace(/^0+(?=.)/, "")).join(":")}::/64`;
}

async function hashIP(secret: string, ip: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", utf8(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return toBase64Url(new Uint8Array(await crypto.subtle.sign("HMAC", key, utf8(rateLimitSubject(ip)))));
}

export function purgeExpiredIPWindows(env: Env): D1PreparedStatement {
  return env.DB.prepare("DELETE FROM ip_windows WHERE expires_at <= ?").bind(nowSeconds());
}

export async function consumeIPQuota(request: Request, env: Env, action: IPLimitedAction): Promise<void> {
  if (!env.IP_HASH_SECRET) throw new HttpError(503, "rate_limit_unavailable");
  const ip = request.headers.get("CF-Connecting-IP");
  if (!ip) throw new HttpError(400, "missing_client_ip");
  const now = nowSeconds();
  const [, result] = await env.DB.batch<{ count: number; expires_at: number }>([
    purgeExpiredIPWindows(env),
    env.DB.prepare(
      `INSERT INTO ip_windows (ip_hash, action, count, expires_at) VALUES (?, ?, 1, ?)
       ON CONFLICT (ip_hash, action) DO UPDATE SET count = count + 1
       RETURNING count, expires_at`,
    ).bind(await hashIP(env.IP_HASH_SECRET, ip), action, now + IP_WINDOW_SECONDS),
  ]);
  const row = result?.results[0];
  if (row && row.count > IP_HOURLY_LIMITS[action]) {
    throw new HttpError(429, `ip_${action}_limit_reached`, String(Math.max(1, row.expires_at - now)));
  }
}
