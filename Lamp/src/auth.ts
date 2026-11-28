import { verifyAssertion } from "./appattest";
import { fromBase64, randomBytes, sha256, toBase64Url, utf8 } from "./encoding";
import type { Env } from "./env";
import { HttpError, nowSeconds } from "./http";

export type TrustTier = "attested_prod" | "attested_dev" | "unattested";

export const TIER_RANK: Record<TrustTier, number> = { unattested: 0, attested_dev: 1, attested_prod: 2 };

const CHALLENGE_TTL_SECONDS = 300;

export interface Contributor {
  id: string;
  public_key: ArrayBuffer;
  trust_tier: TrustTier;
  excluded: number;
}

export interface SignedRequest {
  contributor: Contributor;
  tier: TrustTier;
}

export function appIds(env: Env): string[] {
  return env.APP_ATTEST_APP_IDS.split(",").map((value) => value.trim()).filter(Boolean);
}

export async function issueChallenge(env: Env): Promise<{ challenge: string; expiresAt: number }> {
  const challenge = toBase64Url(randomBytes(32));
  const expiresAt = nowSeconds() + CHALLENGE_TTL_SECONDS;
  await env.DB.prepare("INSERT INTO challenges (value, expires_at) VALUES (?, ?)").bind(challenge, expiresAt).run();
  return { challenge, expiresAt };
}

export async function consumeChallenge(env: Env, challenge: string | null): Promise<string> {
  if (!challenge || challenge.length > 64) throw new HttpError(401, "missing_challenge");
  const row = await env.DB.prepare("DELETE FROM challenges WHERE value = ? AND expires_at > ? RETURNING value")
    .bind(challenge, nowSeconds())
    .first();
  if (!row) throw new HttpError(401, "invalid_challenge");
  return challenge;
}

export async function canonicalRequest(method: string, path: string, challenge: string, body: Uint8Array): Promise<string> {
  return ["LAMP1", method.toUpperCase(), path, challenge, toBase64Url(await sha256(body))].join("\n");
}

export function canonicalAttestKeyId(keyId: string): string {
  try {
    const bytes = fromBase64(keyId);
    if (bytes.length !== 32) throw new Error();
    return toBase64Url(bytes);
  } catch {
    throw new HttpError(401, "unknown_attest_key");
  }
}

export function attestationClientData(challenge: string, publicKey: string): string {
  return ["LAMP1-ATTEST", challenge, publicKey].join("\n");
}

export async function importContributorKey(publicKey: Uint8Array): Promise<CryptoKey> {
  if (publicKey.length !== 65 || publicKey[0] !== 0x04) throw new HttpError(400, "invalid_public_key");
  try {
    return await crypto.subtle.importKey("raw", publicKey, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
  } catch {
    throw new HttpError(400, "invalid_public_key");
  }
}

export async function verifyContributorSignature(publicKey: Uint8Array, signature: string | null, message: string): Promise<void> {
  if (!signature) throw new HttpError(401, "missing_signature");
  const key = await importContributorKey(publicKey);
  let raw: Uint8Array;
  try {
    raw = fromBase64(signature);
  } catch {
    throw new HttpError(401, "invalid_signature");
  }
  if (raw.length !== 64 || !(await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, raw, utf8(message)))) {
    throw new HttpError(401, "invalid_signature");
  }
}

export async function verifySignedRequest(request: Request, env: Env, body: Uint8Array): Promise<SignedRequest> {
  const contributorId = request.headers.get("X-Lamp-Contributor");
  if (!contributorId || contributorId.length > 64) throw new HttpError(401, "missing_contributor");
  const challenge = await consumeChallenge(env, request.headers.get("X-Lamp-Challenge"));

  const contributor = await env.DB.prepare("SELECT id, public_key, trust_tier, excluded FROM contributors WHERE id = ?")
    .bind(contributorId)
    .first<Contributor>();
  if (!contributor) throw new HttpError(401, "invalid_signature");

  const message = await canonicalRequest(request.method, new URL(request.url).pathname, challenge, body);
  await verifyContributorSignature(new Uint8Array(contributor.public_key), request.headers.get("X-Lamp-Signature"), message);

  let tier: TrustTier = "unattested";
  const keyId = request.headers.get("X-Lamp-Attest-Key");
  const assertion = request.headers.get("X-Lamp-Assertion");
  if (keyId && assertion) {
    const canonicalKeyId = canonicalAttestKeyId(keyId);
    const key = await env.DB.prepare("SELECT public_key, environment, counter FROM attest_keys WHERE key_id = ? AND contributor_id = ?")
      .bind(canonicalKeyId, contributor.id)
      .first<{ public_key: ArrayBuffer; environment: string; counter: number }>();
    if (!key) throw new HttpError(401, "unknown_attest_key");
    let counter: number;
    try {
      counter = await verifyAssertion({
        assertion: fromBase64(assertion),
        clientDataHash: await sha256(message),
        publicKey: new Uint8Array(key.public_key),
        previousCounter: key.counter,
        appIds: appIds(env),
      });
    } catch {
      throw new HttpError(401, "invalid_assertion");
    }
    const updated = await env.DB.prepare("UPDATE attest_keys SET counter = ? WHERE key_id = ? AND counter < ?").bind(counter, canonicalKeyId, counter).run();
    if (!updated.meta.changes) throw new HttpError(401, "invalid_assertion");
    tier = key.environment === "production" ? "attested_prod" : "attested_dev";
  } else if (env.ALLOW_UNATTESTED !== "true") {
    throw new HttpError(403, "attestation_required");
  }

  await env.DB.prepare("UPDATE contributors SET last_seen_at = ? WHERE id = ?").bind(nowSeconds(), contributor.id).run();
  return { contributor, tier };
}
