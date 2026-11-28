import { equalBytes, fromBase64, sha256 } from "./encoding";
import type { Env } from "./env";
import { HttpError, nowSeconds } from "./http";

const JWKS_TTL_MS = 10 * 60 * 1000;
const JWKS_MIN_REFRESH_INTERVAL_MS = 30 * 1000;
const CLOCK_SKEW_SECONDS = 60;
const LOCAL_HOSTS = new Set(["127.0.0.1", "localhost", "[::1]"]);
const DEV_COOKIE = "lamp_dev";
const MIN_DEV_TOKEN_LENGTH = 32;

interface AccessJWK extends JsonWebKey {
  kid?: string;
}

let jwksCache: { teamDomain: string; keys: AccessJWK[]; fetchedAt: number } | null = null;

async function signingKeys(teamDomain: string, forceRefresh: boolean): Promise<AccessJWK[]> {
  if (jwksCache?.teamDomain === teamDomain) {
    const age = Date.now() - jwksCache.fetchedAt;
    if (age < (forceRefresh ? JWKS_MIN_REFRESH_INTERVAL_MS : JWKS_TTL_MS)) return jwksCache.keys;
  }
  const response = await fetch(`https://${teamDomain}/cdn-cgi/access/certs`);
  if (!response.ok) throw new HttpError(503, "access_keys_unavailable");
  const { keys } = await response.json<{ keys: AccessJWK[] }>();
  jwksCache = { teamDomain, keys, fetchedAt: Date.now() };
  return keys;
}

function decodeSegment<T>(segment: string): T {
  return JSON.parse(new TextDecoder().decode(fromBase64(segment))) as T;
}

export async function verifyAccessToken(token: string, teamDomain: string, audience: string): Promise<string> {
  const [headerSegment, payloadSegment, signatureSegment] = token.split(".");
  if (!headerSegment || !payloadSegment || !signatureSegment) throw new HttpError(401, "invalid_access_token");

  let header: { alg?: string; kid?: string };
  let claims: { aud?: string | string[]; iss?: string; exp?: number; nbf?: number; email?: string; sub?: string };
  try {
    header = decodeSegment(headerSegment);
    claims = decodeSegment(payloadSegment);
  } catch {
    throw new HttpError(401, "invalid_access_token");
  }
  if (header.alg !== "RS256" || !header.kid) throw new HttpError(401, "invalid_access_token");

  let jwk = (await signingKeys(teamDomain, false)).find((key) => key.kid === header.kid);
  jwk ??= (await signingKeys(teamDomain, true)).find((key) => key.kid === header.kid);
  if (!jwk) throw new HttpError(401, "invalid_access_token");

  const key = await crypto.subtle.importKey("jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    fromBase64(signatureSegment),
    new TextEncoder().encode(`${headerSegment}.${payloadSegment}`),
  );
  if (!valid) throw new HttpError(401, "invalid_access_token");

  const now = nowSeconds();
  const audiences = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (!audiences.includes(audience)) throw new HttpError(401, "invalid_access_token");
  if (claims.iss !== `https://${teamDomain}`) throw new HttpError(401, "invalid_access_token");
  if (typeof claims.exp !== "number" || claims.exp < now - CLOCK_SKEW_SECONDS) throw new HttpError(401, "access_token_expired");
  if (typeof claims.nbf === "number" && claims.nbf > now + CLOCK_SKEW_SECONDS) throw new HttpError(401, "invalid_access_token");
  return claims.email ?? claims.sub ?? "unknown";
}

function hostnameOf(host: string): string {
  return host.startsWith("[") ? host.slice(0, host.indexOf("]") + 1) : host.split(":")[0]!;
}

function isLocalRequest(request: Request, url: URL): boolean {
  const host = request.headers.get("Host");
  return LOCAL_HOSTS.has(url.hostname) && host !== null && LOCAL_HOSTS.has(hostnameOf(host).toLowerCase());
}

function devToken(env: Env, request: Request, url: URL): string | null {
  const token = env.ADMIN_DEV_TOKEN;
  if (!token || token.length < MIN_DEV_TOKEN_LENGTH || env.ACCESS_AUD || !isLocalRequest(request, url)) return null;
  return token;
}

async function matches(provided: string | null | undefined, expected: string): Promise<boolean> {
  return !!provided && equalBytes(await sha256(provided), await sha256(expected));
}

function cookie(request: Request, name: string): string | undefined {
  return request.headers
    .get("Cookie")
    ?.split(";")
    .map((part) => part.trim().split("="))
    .find(([key]) => key === name)?.[1];
}

export async function devSignIn(request: Request, env: Env, url: URL): Promise<Response | null> {
  const token = devToken(env, request, url);
  if (!token || request.method !== "GET" || !(await matches(url.searchParams.get("dev"), token))) return null;
  return new Response(null, {
    status: 303,
    headers: { Location: "/admin/", "Set-Cookie": `${DEV_COOKIE}=${token}; Path=/admin; HttpOnly; SameSite=Strict`, "Cache-Control": "no-store" },
  });
}

export async function requireAdmin(request: Request, env: Env, url: URL): Promise<string> {
  const localToken = devToken(env, request, url);
  if (localToken && (await matches(cookie(request, DEV_COOKIE), localToken))) return "local-dev";
  if (!env.ACCESS_TEAM_DOMAIN || !env.ACCESS_AUD) throw new HttpError(404, "not_found");
  const token = request.headers.get("Cf-Access-Jwt-Assertion");
  if (!token) throw new HttpError(401, "access_required");
  return verifyAccessToken(token, env.ACCESS_TEAM_DOMAIN, env.ACCESS_AUD);
}

export function requireSameOrigin(request: Request, url: URL): void {
  if (request.method === "GET" || request.method === "HEAD") return;
  const origin = request.headers.get("Origin");
  if (origin !== null && origin !== url.origin) throw new HttpError(403, "cross_origin");
  if (!request.headers.get("Content-Type")?.startsWith("application/json")) throw new HttpError(415, "json_required");
}
