import { asBytes, decodeCBOR, mapGet } from "./cbor";
import { children, derSignatureToRaw, parseCertificate, parseSingle, verifyIssuedBy } from "./der";
import { concat, equalBytes, fromBase64, pemToDer, sha256, utf8 } from "./encoding";

export const APPLE_APP_ATTEST_ROOT = `-----BEGIN CERTIFICATE-----
MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
Fw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
Yen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
oyFraWVIyd/dganmrduC1bmTBGwD
-----END CERTIFICATE-----`;

const NONCE_EXTENSION = "1.2.840.113635.100.8.2";
const AAGUID_PRODUCTION = concat(utf8("appattest"), new Uint8Array(7));
const AAGUID_DEVELOPMENT = utf8("appattestdevelop");

export type AttestEnvironment = "production" | "development";

export interface AttestedKey {
  publicKey: Uint8Array;
  environment: AttestEnvironment;
  appId: string;
}

async function matchAppId(rpIdHash: Uint8Array, appIds: string[]): Promise<string> {
  for (const appId of appIds) {
    if (equalBytes(rpIdHash, await sha256(appId))) return appId;
  }
  throw new Error("App Attest: unknown app ID");
}

function readCounter(authData: Uint8Array): number {
  return new DataView(authData.buffer, authData.byteOffset + 33, 4).getUint32(0);
}

export async function verifyAttestation(options: {
  attestationObject: Uint8Array;
  keyId: string;
  clientDataHash: Uint8Array;
  appIds: string[];
  rootPem?: string;
  now?: Date;
}): Promise<AttestedKey> {
  const now = options.now ?? new Date();
  const attestation = decodeCBOR(options.attestationObject);
  if (mapGet(attestation, "fmt") !== "apple-appattest") throw new Error("App Attest: unexpected format");
  const statement = mapGet(attestation, "attStmt");
  const authData = asBytes(mapGet(attestation, "authData"), "authData");
  const chain = mapGet(statement, "x5c");
  if (!Array.isArray(chain) || chain.length < 2) throw new Error("App Attest: missing certificate chain");

  const credential = parseCertificate(asBytes(chain[0]!, "credential certificate"));
  const intermediate = parseCertificate(asBytes(chain[1]!, "intermediate certificate"));
  const root = parseCertificate(pemToDer(options.rootPem ?? APPLE_APP_ATTEST_ROOT));
  await verifyIssuedBy(intermediate, root, now);
  await verifyIssuedBy(credential, intermediate, now);

  const nonce = await sha256(concat(authData, options.clientDataHash));
  const extension = credential.extensions.get(NONCE_EXTENSION);
  if (!extension) throw new Error("App Attest: missing nonce extension");
  const tagged = children(parseSingle(extension))[0];
  const octets = tagged?.tag === 0xa1 ? children(tagged)[0] : undefined;
  if (octets?.tag !== 0x04 || !equalBytes(octets.value, nonce)) throw new Error("App Attest: nonce mismatch");

  const keyId = fromBase64(options.keyId);
  if (credential.curve.name !== "P-256") throw new Error("App Attest: unexpected key type");
  if (!equalBytes(await sha256(credential.publicKeyPoint), keyId)) throw new Error("App Attest: key ID mismatch");

  if (authData.length < 55) throw new Error("App Attest: authData too short");
  const appId = await matchAppId(authData.subarray(0, 32), options.appIds);
  if (readCounter(authData) !== 0) throw new Error("App Attest: counter not zero");

  const aaguid = authData.subarray(37, 53);
  let environment: AttestEnvironment;
  if (equalBytes(aaguid, AAGUID_PRODUCTION)) environment = "production";
  else if (equalBytes(aaguid, AAGUID_DEVELOPMENT)) environment = "development";
  else throw new Error("App Attest: unexpected AAGUID");

  const credentialIdLength = new DataView(authData.buffer, authData.byteOffset + 53, 2).getUint16(0);
  const credentialId = authData.subarray(55, 55 + credentialIdLength);
  if (!equalBytes(credentialId, keyId)) throw new Error("App Attest: credential ID mismatch");

  return { publicKey: credential.publicKeyPoint, environment, appId };
}

export async function verifyAssertion(options: {
  assertion: Uint8Array;
  clientDataHash: Uint8Array;
  publicKey: Uint8Array;
  previousCounter: number;
  appIds: string[];
}): Promise<number> {
  const assertion = decodeCBOR(options.assertion);
  const signature = asBytes(mapGet(assertion, "signature"), "signature");
  const authData = asBytes(mapGet(assertion, "authenticatorData"), "authenticatorData");
  if (authData.length < 37) throw new Error("App Attest: authenticatorData too short");

  const key = await crypto.subtle.importKey("raw", options.publicKey, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
  const nonce = await sha256(concat(authData, options.clientDataHash));
  const valid = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, derSignatureToRaw(signature, 32), nonce);
  if (!valid) throw new Error("App Attest: bad assertion signature");

  await matchAppId(authData.subarray(0, 32), options.appIds);
  const counter = readCounter(authData);
  if (counter <= options.previousCounter) throw new Error("App Attest: counter did not increase");
  return counter;
}
