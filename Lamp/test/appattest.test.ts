import "reflect-metadata";
import * as x509 from "@peculiar/x509";
import { beforeAll, describe, expect, it } from "vitest";
import { APPLE_APP_ATTEST_ROOT, verifyAssertion, verifyAttestation } from "../src/appattest";
import { parseCertificate, verifyIssuedBy } from "../src/der";
import { encodeCBOR } from "../src/cbor";
import { concat, pemToDer, sha256, toBase64Url, utf8 } from "../src/encoding";

const APP_ID = "YYM4Z6MU8F.com.tsubuzaki.DJDX";
const P384 = { name: "ECDSA", namedCurve: "P-384", hash: "SHA-384" };
const P256 = { name: "ECDSA", namedCurve: "P-256" };

function rawToDer(raw: Uint8Array): Uint8Array {
  const integer = (bytes: Uint8Array) => {
    let start = 0;
    while (start < bytes.length - 1 && bytes[start] === 0) start++;
    let value = bytes.subarray(start);
    if (value[0]! & 0x80) value = concat(new Uint8Array([0]), value);
    return concat(new Uint8Array([0x02, value.length]), value);
  };
  const half = raw.length / 2;
  const body = concat(integer(raw.subarray(0, half)), integer(raw.subarray(half)));
  return concat(new Uint8Array([0x30, body.length]), body);
}

function counterBytes(value: number): Uint8Array {
  const out = new Uint8Array(4);
  new DataView(out.buffer).setUint32(0, value);
  return out;
}

interface Fixture {
  rootPem: string;
  intermediate: x509.X509Certificate;
  intermediateKeys: CryptoKeyPair;
  leafKeys: CryptoKeyPair;
  publicKey: Uint8Array;
  keyId: string;
}

let fixture: Fixture;

async function makeLeaf(nonce: Uint8Array, keys: CryptoKeyPair = fixture.leafKeys): Promise<x509.X509Certificate> {
  const extension = concat(new Uint8Array([0x30, 0x24, 0xa1, 0x22, 0x04, 0x20]), nonce);
  return x509.X509CertificateGenerator.create({
    serialNumber: "03",
    subject: "CN=Test Credential",
    issuer: fixture.intermediate.subject,
    notBefore: new Date(Date.now() - 86400000),
    notAfter: new Date(Date.now() + 86400000),
    publicKey: keys.publicKey,
    signingKey: fixture.intermediateKeys.privateKey,
    signingAlgorithm: { name: "ECDSA", hash: "SHA-256" },
    extensions: [new x509.Extension("1.2.840.113635.100.8.2", false, extension)],
  });
}

async function makeAttestation(options: { clientDataHash: Uint8Array; appId?: string; aaguid?: Uint8Array; nonceOverride?: Uint8Array }) {
  const keyIdBytes = await sha256(fixture.publicKey);
  const authData = concat(
    await sha256(options.appId ?? APP_ID),
    new Uint8Array([0x40]),
    counterBytes(0),
    options.aaguid ?? concat(utf8("appattest"), new Uint8Array(7)),
    new Uint8Array([0, 32]),
    keyIdBytes,
    new Uint8Array([0xa0]),
  );
  const nonce = options.nonceOverride ?? (await sha256(concat(authData, options.clientDataHash)));
  const leaf = await makeLeaf(nonce);
  return encodeCBOR(
    new Map<string, unknown>([
      ["fmt", "apple-appattest"],
      [
        "attStmt",
        new Map<string, unknown>([
          ["x5c", [new Uint8Array(leaf.rawData), new Uint8Array(fixture.intermediate.rawData)]],
          ["receipt", new Uint8Array([1, 2, 3])],
        ]),
      ],
      ["authData", authData],
    ]) as never,
  );
}

async function makeAssertion(clientDataHash: Uint8Array, counter: number, appId = APP_ID): Promise<Uint8Array> {
  const authData = concat(await sha256(appId), new Uint8Array([0x40]), counterBytes(counter));
  const nonce = await sha256(concat(authData, clientDataHash));
  const raw = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, fixture.leafKeys.privateKey, nonce));
  return encodeCBOR(new Map<string, unknown>([["signature", rawToDer(raw)], ["authenticatorData", authData]]) as never);
}

beforeAll(async () => {
  x509.cryptoProvider.set(crypto);
  const notBefore = new Date(Date.now() - 86400000);
  const notAfter = new Date(Date.now() + 10 * 86400000);
  const rootKeys = (await crypto.subtle.generateKey(P384, true, ["sign", "verify"])) as CryptoKeyPair;
  const root = await x509.X509CertificateGenerator.createSelfSigned({
    serialNumber: "01",
    name: "CN=Test App Attest Root",
    notBefore,
    notAfter,
    keys: rootKeys,
    signingAlgorithm: P384,
    extensions: [new x509.BasicConstraintsExtension(true, 1, true)],
  });
  const intermediateKeys = (await crypto.subtle.generateKey(P384, true, ["sign", "verify"])) as CryptoKeyPair;
  const intermediate = await x509.X509CertificateGenerator.create({
    serialNumber: "02",
    subject: "CN=Test App Attest CA",
    issuer: root.subject,
    notBefore,
    notAfter,
    publicKey: intermediateKeys.publicKey,
    signingKey: rootKeys.privateKey,
    signingAlgorithm: P384,
    extensions: [new x509.BasicConstraintsExtension(true, 0, true)],
  });
  const leafKeys = (await crypto.subtle.generateKey(P256, true, ["sign", "verify"])) as CryptoKeyPair;
  const publicKey = new Uint8Array((await crypto.subtle.exportKey("raw", leafKeys.publicKey)) as ArrayBuffer);
  fixture = {
    rootPem: root.toString("pem"),
    intermediate,
    intermediateKeys,
    leafKeys,
    publicKey,
    keyId: toBase64Url(await sha256(publicKey)),
  };
});

describe("verifyAttestation", () => {
  it("accepts a valid production attestation", async () => {
    const clientDataHash = await sha256("enroll");
    const result = await verifyAttestation({
      attestationObject: await makeAttestation({ clientDataHash }),
      keyId: fixture.keyId,
      clientDataHash,
      appIds: [APP_ID],
      rootPem: fixture.rootPem,
    });
    expect(result.environment).toBe("production");
    expect(result.appId).toBe(APP_ID);
    expect(result.publicKey).toEqual(fixture.publicKey);
  });

  it("detects the development environment", async () => {
    const clientDataHash = await sha256("enroll");
    const result = await verifyAttestation({
      attestationObject: await makeAttestation({ clientDataHash, aaguid: utf8("appattestdevelop") }),
      keyId: fixture.keyId,
      clientDataHash,
      appIds: [APP_ID],
      rootPem: fixture.rootPem,
    });
    expect(result.environment).toBe("development");
  });

  it("rejects a different client data hash", async () => {
    const attestationObject = await makeAttestation({ clientDataHash: await sha256("enroll") });
    await expect(
      verifyAttestation({ attestationObject, keyId: fixture.keyId, clientDataHash: await sha256("other"), appIds: [APP_ID], rootPem: fixture.rootPem }),
    ).rejects.toThrow(/nonce mismatch/);
  });

  it("rejects an unknown app ID", async () => {
    const clientDataHash = await sha256("enroll");
    await expect(
      verifyAttestation({
        attestationObject: await makeAttestation({ clientDataHash, appId: "XXXXXXXXXX.com.example.Other" }),
        keyId: fixture.keyId,
        clientDataHash,
        appIds: [APP_ID],
        rootPem: fixture.rootPem,
      }),
    ).rejects.toThrow(/unknown app ID/);
  });

  it("rejects a mismatched key ID", async () => {
    const clientDataHash = await sha256("enroll");
    await expect(
      verifyAttestation({
        attestationObject: await makeAttestation({ clientDataHash }),
        keyId: toBase64Url(await sha256("someone else")),
        clientDataHash,
        appIds: [APP_ID],
        rootPem: fixture.rootPem,
      }),
    ).rejects.toThrow(/key ID mismatch/);
  });

  it("rejects an unexpected AAGUID", async () => {
    const clientDataHash = await sha256("enroll");
    await expect(
      verifyAttestation({
        attestationObject: await makeAttestation({ clientDataHash, aaguid: utf8("notappattest0000") }),
        keyId: fixture.keyId,
        clientDataHash,
        appIds: [APP_ID],
        rootPem: fixture.rootPem,
      }),
    ).rejects.toThrow(/AAGUID/);
  });

  it("rejects chains that do not lead to Apple's root", async () => {
    const clientDataHash = await sha256("enroll");
    await expect(
      verifyAttestation({ attestationObject: await makeAttestation({ clientDataHash }), keyId: fixture.keyId, clientDataHash, appIds: [APP_ID] }),
    ).rejects.toThrow(/issuer mismatch/);
  });
});

describe("verifyAssertion", () => {
  it("accepts an increasing counter and rejects replays", async () => {
    const clientDataHash = await sha256("upload");
    const assertion = await makeAssertion(clientDataHash, 1);
    const counter = await verifyAssertion({ assertion, clientDataHash, publicKey: fixture.publicKey, previousCounter: 0, appIds: [APP_ID] });
    expect(counter).toBe(1);
    await expect(
      verifyAssertion({ assertion, clientDataHash, publicKey: fixture.publicKey, previousCounter: counter, appIds: [APP_ID] }),
    ).rejects.toThrow(/counter/);
  });

  it("rejects an assertion for a different request", async () => {
    const assertion = await makeAssertion(await sha256("upload"), 1);
    await expect(
      verifyAssertion({ assertion, clientDataHash: await sha256("tampered"), publicKey: fixture.publicKey, previousCounter: 0, appIds: [APP_ID] }),
    ).rejects.toThrow(/signature/);
  });

  it("rejects an assertion from another app", async () => {
    const clientDataHash = await sha256("upload");
    const assertion = await makeAssertion(clientDataHash, 1, "XXXXXXXXXX.com.example.Other");
    await expect(
      verifyAssertion({ assertion, clientDataHash, publicKey: fixture.publicKey, previousCounter: 0, appIds: [APP_ID] }),
    ).rejects.toThrow(/unknown app ID/);
  });
});

describe("Apple root", () => {
  it("parses and self-verifies", async () => {
    const root = parseCertificate(pemToDer(APPLE_APP_ATTEST_ROOT));
    expect(root.curve.name).toBe("P-384");
    expect(root.notAfter.toISOString()).toBe("2045-03-15T00:00:00.000Z");
    await verifyIssuedBy(root, root, new Date());
  });
});
