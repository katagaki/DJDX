export type CBORValue =
  | number
  | bigint
  | string
  | boolean
  | null
  | undefined
  | Uint8Array
  | CBORValue[]
  | Map<CBORValue, CBORValue>;

const MAX_DEPTH = 16;

export function decodeCBOR(data: Uint8Array): CBORValue {
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  let offset = 0;

  const take = (length: number): Uint8Array => {
    if (offset + length > data.length) throw new Error("CBOR: truncated");
    const out = data.subarray(offset, offset + length);
    offset += length;
    return out;
  };

  const readLength = (info: number): number => {
    if (info < 24) return info;
    if (info === 24) return take(1)[0]!;
    if (info === 25) return view.getUint16(take(2).byteOffset - data.byteOffset);
    if (info === 26) return view.getUint32(take(4).byteOffset - data.byteOffset);
    if (info === 27) {
      const value = view.getBigUint64(take(8).byteOffset - data.byteOffset);
      if (value > BigInt(Number.MAX_SAFE_INTEGER)) throw new Error("CBOR: length too large");
      return Number(value);
    }
    throw new Error("CBOR: unsupported length encoding");
  };

  const read = (depth: number): CBORValue => {
    if (depth > MAX_DEPTH) throw new Error("CBOR: too deep");
    const initial = take(1)[0]!;
    const major = initial >> 5;
    const info = initial & 0x1f;
    switch (major) {
      case 0:
        return readLength(info);
      case 1:
        return -1 - readLength(info);
      case 2:
        return take(readLength(info));
      case 3:
        return new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(take(readLength(info)));
      case 4: {
        const length = readLength(info);
        const out: CBORValue[] = [];
        for (let i = 0; i < length; i++) out.push(read(depth + 1));
        return out;
      }
      case 5: {
        const length = readLength(info);
        const out = new Map<CBORValue, CBORValue>();
        for (let i = 0; i < length; i++) {
          const key = read(depth + 1);
          out.set(key, read(depth + 1));
        }
        return out;
      }
      case 6:
        readLength(info);
        return read(depth + 1);
      case 7:
        if (info === 20) return false;
        if (info === 21) return true;
        if (info === 22) return null;
        if (info === 23) return undefined;
        throw new Error("CBOR: unsupported simple value");
      default:
        throw new Error("CBOR: unsupported major type");
    }
  };

  const value = read(0);
  if (offset !== data.length) throw new Error("CBOR: trailing bytes");
  return value;
}

export function encodeCBOR(value: CBORValue): Uint8Array {
  const out: number[] = [];

  const head = (major: number, length: number) => {
    if (length < 24) out.push((major << 5) | length);
    else if (length < 0x100) out.push((major << 5) | 24, length);
    else if (length < 0x10000) out.push((major << 5) | 25, length >> 8, length & 0xff);
    else out.push((major << 5) | 26, (length >>> 24) & 0xff, (length >> 16) & 0xff, (length >> 8) & 0xff, length & 0xff);
  };

  const write = (item: CBORValue) => {
    if (item instanceof Uint8Array) {
      head(2, item.length);
      out.push(...item);
    } else if (typeof item === "string") {
      const bytes = new TextEncoder().encode(item);
      head(3, bytes.length);
      out.push(...bytes);
    } else if (typeof item === "number" && Number.isInteger(item)) {
      if (item >= 0) head(0, item);
      else head(1, -1 - item);
    } else if (Array.isArray(item)) {
      head(4, item.length);
      item.forEach(write);
    } else if (item instanceof Map) {
      head(5, item.size);
      for (const [key, entry] of item) {
        write(key);
        write(entry);
      }
    } else if (item === false) out.push(0xf4);
    else if (item === true) out.push(0xf5);
    else if (item === null) out.push(0xf6);
    else throw new Error("CBOR: unsupported value");
  };

  write(value);
  return new Uint8Array(out);
}

export function mapGet(value: CBORValue, key: string): CBORValue {
  if (!(value instanceof Map)) throw new Error("CBOR: expected map");
  return value.get(key);
}

export function asBytes(value: CBORValue, name: string): Uint8Array {
  if (!(value instanceof Uint8Array)) throw new Error(`CBOR: ${name} is not bytes`);
  return value;
}
