import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { requireAdmin, verifyAccessToken } from "../src/access";
import { toBase64Url, utf8 } from "../src/encoding";
import type { Env } from "../src/env";

const TEAM = "djdx-test.cloudflareaccess.com";
const AUD = "aud-tag";
let keys: CryptoKeyPair;
let otherKeys: CryptoKeyPair;

async function generate(): Promise<CryptoKeyPair> {
  return (await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"],
  )) as CryptoKeyPair;
}

async function token(claims: Record<string, unknown>, signer = keys, kid = "key-1"): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = toBase64Url(utf8(JSON.stringify({ alg: "RS256", kid, typ: "JWT" })));
  const payload = toBase64Url(utf8(JSON.stringify({ aud: [AUD], iss: `https://${TEAM}`, exp: now + 600, iat: now, email: "admin@example.com", ...claims })));
  const signature = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", signer.privateKey, utf8(`${header}.${payload}`)));
  return `${header}.${payload}.${toBase64Url(signature)}`;
}

beforeAll(async () => {
  keys = await generate();
  otherKeys = await generate();
  const jwk = { ...(await crypto.subtle.exportKey("jwk", keys.publicKey)), kid: "key-1" };
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string) => {
      expect(url).toBe(`https://${TEAM}/cdn-cgi/access/certs`);
      return new Response(JSON.stringify({ keys: [jwk] }));
    }),
  );
});

afterEach(() => vi.clearAllMocks());

describe("verifyAccessToken", () => {
  it("returns the email for a valid token", async () => {
    await expect(verifyAccessToken(await token({}), TEAM, AUD)).resolves.toBe("admin@example.com");
  });

  it("rejects the wrong audience, issuer or an expired token", async () => {
    await expect(verifyAccessToken(await token({ aud: ["other"] }), TEAM, AUD)).rejects.toThrow();
    await expect(verifyAccessToken(await token({ iss: "https://evil.cloudflareaccess.com" }), TEAM, AUD)).rejects.toThrow();
    await expect(verifyAccessToken(await token({ exp: Math.floor(Date.now() / 1000) - 3600 }), TEAM, AUD)).rejects.toThrow();
  });

  it("rejects a token signed by another key", async () => {
    await expect(verifyAccessToken(await token({}, otherKeys), TEAM, AUD)).rejects.toThrow();
  });

  it("rejects an unknown key ID and a tampered payload", async () => {
    await expect(verifyAccessToken(await token({}, keys, "key-2"), TEAM, AUD)).rejects.toThrow();
    const [header, , signature] = (await token({})).split(".");
    const forged = toBase64Url(utf8(JSON.stringify({ aud: [AUD], iss: `https://${TEAM}`, exp: 9999999999, email: "attacker@example.com" })));
    await expect(verifyAccessToken(`${header}.${forged}.${signature}`, TEAM, AUD)).rejects.toThrow();
  });
});

describe("requireAdmin", () => {
  const env = { ACCESS_TEAM_DOMAIN: TEAM, ACCESS_AUD: AUD } as Env;

  it("only honours the dev token cookie on local hosts without Access configured", async () => {
    const devToken = "d".repeat(64);
    const bypass = { ACCESS_TEAM_DOMAIN: "", ACCESS_AUD: "", ADMIN_DEV_TOKEN: devToken } as Env;
    const local = (host: string, value = devToken) => new Request("http://127.0.0.1:8787/admin/", { headers: { Host: host, Cookie: `other=1; lamp_dev=${value}` } });
    const localURL = new URL("http://127.0.0.1:8787/admin/");
    await expect(requireAdmin(local("127.0.0.1:8787"), bypass, localURL)).resolves.toBe("local-dev");
    await expect(requireAdmin(local("localhost:8787"), bypass, localURL)).resolves.toBe("local-dev");
    await expect(requireAdmin(local("evil.example"), bypass, localURL)).rejects.toThrow();
    await expect(requireAdmin(local("127.0.0.1:8787", "wrong"), bypass, localURL)).rejects.toThrow();
    await expect(requireAdmin(new Request("http://127.0.0.1:8787/admin/", { headers: { Host: "127.0.0.1:8787" } }), bypass, localURL)).rejects.toThrow();
    await expect(
      requireAdmin(new Request("https://djdx.ktgk.app/admin/", { headers: { Host: "localhost", Cookie: `lamp_dev=${devToken}` } }), bypass, new URL("https://djdx.ktgk.app/admin/")),
    ).rejects.toThrow();
    await expect(requireAdmin(local("127.0.0.1:8787"), { ...env, ADMIN_DEV_TOKEN: devToken } as Env, localURL)).rejects.toThrow();
    await expect(requireAdmin(local("127.0.0.1:8787", "short"), { ...bypass, ADMIN_DEV_TOKEN: "short" } as Env, localURL)).rejects.toThrow();
  });

  it("is disabled when Access is not configured", async () => {
    const unconfigured = { ACCESS_TEAM_DOMAIN: "", ACCESS_AUD: "" } as Env;
    await expect(requireAdmin(new Request("https://djdx.ktgk.app/admin/"), unconfigured, new URL("https://djdx.ktgk.app/admin/"))).rejects.toMatchObject({ status: 404 });
  });

  it("accepts the Access header", async () => {
    const request = new Request("https://djdx.ktgk.app/admin/", { headers: { "Cf-Access-Jwt-Assertion": await token({}) } });
    await expect(requireAdmin(request, env, new URL(request.url))).resolves.toBe("admin@example.com");
  });
});
