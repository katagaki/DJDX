import { equalBytes } from "./encoding";

export interface DERNode {
  tag: number;
  raw: Uint8Array;
  value: Uint8Array;
}

export function readDER(data: Uint8Array, offset = 0): { node: DERNode; next: number } {
  const start = offset;
  const tag = data[offset++];
  if (tag === undefined || (tag & 0x1f) === 0x1f) throw new Error("DER: unsupported tag");
  let length = data[offset++];
  if (length === undefined) throw new Error("DER: truncated");
  if (length & 0x80) {
    const count = length & 0x7f;
    if (count === 0 || count > 4) throw new Error("DER: unsupported length");
    length = 0;
    for (let i = 0; i < count; i++) {
      const byte = data[offset++];
      if (byte === undefined) throw new Error("DER: truncated");
      length = length * 256 + byte;
    }
  }
  const end = offset + length;
  if (end > data.length) throw new Error("DER: truncated");
  return { node: { tag, raw: data.subarray(start, end), value: data.subarray(offset, end) }, next: end };
}

export function children(node: DERNode): DERNode[] {
  const out: DERNode[] = [];
  let offset = 0;
  while (offset < node.value.length) {
    const { node: child, next } = readDER(node.value, offset);
    out.push(child);
    offset = next;
  }
  return out;
}

export function parseSingle(data: Uint8Array): DERNode {
  const { node, next } = readDER(data);
  if (next !== data.length) throw new Error("DER: trailing bytes");
  return node;
}

export function decodeOID(value: Uint8Array): string {
  const parts: number[] = [];
  let current = 0;
  for (const byte of value) {
    current = current * 128 + (byte & 0x7f);
    if (!(byte & 0x80)) {
      parts.push(current);
      current = 0;
    }
  }
  const first = parts.shift() ?? 0;
  const head = first < 80 ? [Math.floor(first / 40), first % 40] : [2, first - 80];
  return [...head, ...parts].join(".");
}

function parseTime(node: DERNode): Date {
  const text = new TextDecoder().decode(node.value);
  let match: RegExpMatchArray | null;
  if (node.tag === 0x17 && (match = text.match(/^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/))) {
    const year = Number(match[1]);
    return new Date(Date.UTC(year >= 50 ? 1900 + year : 2000 + year, Number(match[2]) - 1, Number(match[3]), Number(match[4]), Number(match[5]), Number(match[6])));
  }
  if (node.tag === 0x18 && (match = text.match(/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/))) {
    return new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]), Number(match[4]), Number(match[5]), Number(match[6])));
  }
  throw new Error("DER: unsupported time");
}

const CURVES: Record<string, { name: string; size: number }> = {
  "1.2.840.10045.3.1.7": { name: "P-256", size: 32 },
  "1.3.132.0.34": { name: "P-384", size: 48 },
};

const SIGNATURE_HASHES: Record<string, string> = {
  "1.2.840.10045.4.3.2": "SHA-256",
  "1.2.840.10045.4.3.3": "SHA-384",
};

export interface Certificate {
  tbs: Uint8Array;
  signatureHash: string;
  signature: Uint8Array;
  issuer: Uint8Array;
  subject: Uint8Array;
  notBefore: Date;
  notAfter: Date;
  spki: Uint8Array;
  curve: { name: string; size: number };
  publicKeyPoint: Uint8Array;
  extensions: Map<string, Uint8Array>;
}

export function parseCertificate(der: Uint8Array): Certificate {
  const [tbsNode, algorithmNode, signatureNode] = children(parseSingle(der));
  if (!tbsNode || !algorithmNode || signatureNode?.tag !== 0x03) throw new Error("X.509: malformed certificate");
  const tbsFields = children(tbsNode);
  let index = tbsFields[0]?.tag === 0xa0 ? 1 : 0;
  index += 2;
  const issuer = tbsFields[index++];
  const validity = tbsFields[index++];
  const subject = tbsFields[index++];
  const spki = tbsFields[index++];
  if (!issuer || !validity || !subject || !spki) throw new Error("X.509: malformed TBS");

  const [notBefore, notAfter] = children(validity);
  if (!notBefore || !notAfter) throw new Error("X.509: malformed validity");

  const [spkiAlgorithm, spkiKey] = children(spki);
  const curveOID = spkiAlgorithm ? children(spkiAlgorithm)[1] : undefined;
  const curve = curveOID ? CURVES[decodeOID(curveOID.value)] : undefined;
  if (!curve || !spkiKey || spkiKey.tag !== 0x03) throw new Error("X.509: unsupported public key");

  const signatureOID = children(algorithmNode)[0];
  const signatureHash = signatureOID ? SIGNATURE_HASHES[decodeOID(signatureOID.value)] : undefined;
  if (!signatureHash) throw new Error("X.509: unsupported signature algorithm");

  const extensions = new Map<string, Uint8Array>();
  const extensionsWrapper = tbsFields.slice(index).find((node) => node.tag === 0xa3);
  if (extensionsWrapper) {
    const sequence = children(extensionsWrapper)[0];
    for (const extension of sequence ? children(sequence) : []) {
      const parts = children(extension);
      const oid = parts[0];
      const value = parts[parts.length - 1];
      if (oid?.tag === 0x06 && value?.tag === 0x04) extensions.set(decodeOID(oid.value), value.value);
    }
  }

  return {
    tbs: tbsNode.raw,
    signatureHash,
    signature: signatureNode.value.subarray(1),
    issuer: issuer.raw,
    subject: subject.raw,
    notBefore: parseTime(notBefore),
    notAfter: parseTime(notAfter),
    spki: spki.raw,
    curve,
    publicKeyPoint: spkiKey.value.subarray(1),
    extensions,
  };
}

export function derSignatureToRaw(signature: Uint8Array, size: number): Uint8Array {
  const [r, s] = children(parseSingle(signature));
  if (r?.tag !== 0x02 || s?.tag !== 0x02) throw new Error("ECDSA: malformed signature");
  const out = new Uint8Array(size * 2);
  for (const [i, integer] of [r.value, s.value].entries()) {
    let bytes = integer;
    while (bytes.length > size && bytes[0] === 0) bytes = bytes.subarray(1);
    if (bytes.length > size) throw new Error("ECDSA: integer too large");
    out.set(bytes, i * size + (size - bytes.length));
  }
  return out;
}

export async function importCertificateKey(certificate: Certificate): Promise<CryptoKey> {
  return crypto.subtle.importKey("spki", certificate.spki, { name: "ECDSA", namedCurve: certificate.curve.name }, false, ["verify"]);
}

export async function verifyIssuedBy(certificate: Certificate, issuer: Certificate, now: Date): Promise<void> {
  if (!equalBytes(certificate.issuer, issuer.subject)) throw new Error("X.509: issuer mismatch");
  if (now < certificate.notBefore || now > certificate.notAfter) throw new Error("X.509: certificate expired or not yet valid");
  const key = await importCertificateKey(issuer);
  const signature = derSignatureToRaw(certificate.signature, issuer.curve.size);
  const valid = await crypto.subtle.verify({ name: "ECDSA", hash: certificate.signatureHash }, key, signature, certificate.tbs);
  if (!valid) throw new Error("X.509: bad certificate signature");
}
