import { verifyAttestation } from "../appattest";
import {
  TIER_RANK,
  appIds,
  attestationClientData,
  canonicalAttestKeyId,
  canonicalRequest,
  consumeChallenge,
  importContributorKey,
  verifyContributorSignature,
  verifySignedRequest,
  type TrustTier,
} from "../auth";
import { fromBase64, sha256, toBase64Url, toHex } from "../encoding";
import type { Env } from "../env";
import { HttpError, json, nowSeconds, parseJSON, readBody, requireString } from "../http";
import { consumeIPQuota } from "../iplimit";
import { consumeDailyQuota, limitByIP } from "../limits";
import { markDirtyForContributor } from "../snapshots";

export async function contributorIdFor(publicKey: Uint8Array): Promise<string> {
  return toBase64Url((await sha256(publicKey)).subarray(0, 16));
}

export function normalizeDeletionCode(code: string): string {
  return code.toUpperCase().replace(/[^0-9A-Z]/g, "");
}

export async function enroll(request: Request, env: Env): Promise<Response> {
  await limitByIP(request, env, "enroll");
  await consumeIPQuota(request, env, "enroll");
  const body = await readBody(request);
  const payload = parseJSON(body);
  const challenge = await consumeChallenge(env, request.headers.get("X-Lamp-Challenge"));

  const publicKeyText = requireString(payload.publicKey, "publicKey", 128);
  let publicKey: Uint8Array;
  try {
    publicKey = fromBase64(publicKeyText);
  } catch {
    throw new HttpError(400, "invalid_public_key");
  }
  await importContributorKey(publicKey);
  const deletionHash = requireString(payload.deletionCodeHash, "deletionCodeHash", 64).toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(deletionHash)) throw new HttpError(400, "invalid_field", "deletionCodeHash");

  const message = await canonicalRequest(request.method, new URL(request.url).pathname, challenge, body);
  await verifyContributorSignature(publicKey, request.headers.get("X-Lamp-Signature"), message);

  let tier: TrustTier = "unattested";
  let attestedKey: { keyId: string; publicKey: Uint8Array; environment: string } | null = null;
  if (payload.attestation !== undefined && payload.attestation !== null) {
    const attestation = payload.attestation as Record<string, unknown>;
    const keyId = canonicalAttestKeyId(requireString(attestation.keyId, "attestation.keyId", 128));
    const object = requireString(attestation.object, "attestation.object", 16384);
    try {
      const verified = await verifyAttestation({
        attestationObject: fromBase64(object),
        keyId,
        clientDataHash: await sha256(attestationClientData(challenge, publicKeyText)),
        appIds: appIds(env),
      });
      attestedKey = { keyId, publicKey: verified.publicKey, environment: verified.environment };
      tier = verified.environment === "production" ? "attested_prod" : "attested_dev";
    } catch (error) {
      console.warn("attestation rejected", error instanceof Error ? error.message : error);
      throw new HttpError(401, "invalid_attestation");
    }
  } else if (env.ALLOW_UNATTESTED !== "true") {
    throw new HttpError(403, "attestation_required");
  }

  const contributorId = await contributorIdFor(publicKey);
  const now = nowSeconds();
  const existing = await env.DB.prepare("SELECT trust_tier FROM contributors WHERE id = ?").bind(contributorId).first<{ trust_tier: TrustTier }>();
  const storedTier = existing && TIER_RANK[existing.trust_tier] > TIER_RANK[tier] ? existing.trust_tier : tier;

  const statements = [
    env.DB.prepare(
      `INSERT INTO contributors (id, public_key, deletion_hash, trust_tier, created_at, last_seen_at) VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT (id) DO UPDATE SET deletion_hash = excluded.deletion_hash, trust_tier = ?, last_seen_at = excluded.last_seen_at`,
    ).bind(contributorId, publicKey, deletionHash, storedTier, now, now, storedTier),
  ];
  if (attestedKey) {
    const owner = await env.DB.prepare("SELECT contributor_id FROM attest_keys WHERE key_id = ?").bind(attestedKey.keyId).first<{ contributor_id: string }>();
    if (owner && owner.contributor_id !== contributorId) throw new HttpError(409, "attest_key_in_use");
    statements.push(
      env.DB.prepare(
        `INSERT INTO attest_keys (key_id, contributor_id, public_key, environment, counter, created_at) VALUES (?, ?, ?, ?, 0, ?)
         ON CONFLICT (key_id) DO NOTHING`,
      ).bind(attestedKey.keyId, contributorId, attestedKey.publicKey, attestedKey.environment, now),
    );
  }
  try {
    await env.DB.batch(statements);
  } catch (error) {
    if (String(error).includes("UNIQUE")) throw new HttpError(409, "deletion_code_in_use");
    throw error;
  }
  return json({ contributorId, trustTier: storedTier }, existing ? 200 : 201);
}

async function deleteContributor(env: Env, contributorId: string): Promise<void> {
  await env.DB.batch([
    markDirtyForContributor(env, contributorId),
    env.DB.prepare("DELETE FROM scores WHERE contributor_id = ?").bind(contributorId),
    env.DB.prepare("DELETE FROM attest_keys WHERE contributor_id = ?").bind(contributorId),
    env.DB.prepare("DELETE FROM usage_counters WHERE contributor_id = ?").bind(contributorId),
    env.DB.prepare("DELETE FROM reports WHERE contributor_id = ?").bind(contributorId),
    env.DB.prepare("DELETE FROM contributors WHERE id = ?").bind(contributorId),
  ]);
}

export async function deleteSelf(request: Request, env: Env): Promise<Response> {
  const body = await readBody(request);
  const { contributor } = await verifySignedRequest(request, env, body);
  await deleteContributor(env, contributor.id);
  return json({ deleted: true });
}

export async function heartbeat(request: Request, env: Env): Promise<Response> {
  const body = await readBody(request);
  const { contributor, tier } = await verifySignedRequest(request, env, body);
  await consumeDailyQuota(env, contributor.id, "heartbeat", tier);
  return json({ ok: true });
}

export async function deleteWithCode(request: Request, env: Env): Promise<Response> {
  await limitByIP(request, env, "deletion");
  const payload = parseJSON(await readBody(request));
  const code = normalizeDeletionCode(requireString(payload.deletionCode, "deletionCode", 128));
  if (code.length < 16) throw new HttpError(400, "invalid_field", "deletionCode");
  const hash = toHex(await sha256(code));
  const contributor = await env.DB.prepare("SELECT id FROM contributors WHERE deletion_hash = ?").bind(hash).first<{ id: string }>();
  if (contributor) await deleteContributor(env, contributor.id);
  return json({ deleted: !!contributor });
}

export async function purgeInactiveContributors(env: Env, maxIdleSeconds: number): Promise<number> {
  const cutoff = nowSeconds() - maxIdleSeconds;
  let purged = 0;
  for (let page = 0; page < 10; page++) {
    const stale = await env.DB.prepare("SELECT id FROM contributors WHERE last_seen_at < ? LIMIT 200").bind(cutoff).all<{ id: string }>();
    for (const { id } of stale.results) await deleteContributor(env, id);
    purged += stale.results.length;
    if (stale.results.length < 200) break;
  }
  return purged;
}
