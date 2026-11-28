import { concat } from "./encoding";

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message?: string,
  ) {
    super(message ?? code);
  }
}

export function json(body: unknown, status = 200, headers: HeadersInit = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff", ...headers },
  });
}

export function errorResponse(error: unknown): Response {
  if (error instanceof HttpError) {
    const headers: Record<string, string> = error.status === 429 && /^\d+$/.test(error.message) ? { "Retry-After": error.message } : {};
    return json({ error: error.code, message: error.message }, error.status, headers);
  }
  console.error(error);
  return json({ error: "internal_error" }, 500);
}

const MAX_BODY_BYTES = 1024 * 1024;

export async function readBody(request: Request): Promise<Uint8Array> {
  const declared = Number(request.headers.get("Content-Length") ?? "0");
  if (declared > MAX_BODY_BYTES) throw new HttpError(413, "body_too_large");
  if (!request.body) return new Uint8Array();
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > MAX_BODY_BYTES) {
      await reader.cancel();
      throw new HttpError(413, "body_too_large");
    }
    chunks.push(value);
  }
  return concat(...chunks);
}

export function parseJSON(body: Uint8Array): Record<string, unknown> {
  try {
    const value = JSON.parse(new TextDecoder().decode(body));
    if (value && typeof value === "object" && !Array.isArray(value)) return value as Record<string, unknown>;
  } catch {}
  throw new HttpError(400, "invalid_json");
}

export function requireString(value: unknown, name: string, maxLength = 256): string {
  if (typeof value !== "string" || value.length === 0 || value.length > maxLength) throw new HttpError(400, "invalid_field", name);
  return value;
}

export function optionalString(value: unknown, name: string, maxLength = 256): string | null {
  if (value === undefined || value === null) return null;
  return requireString(value, name, maxLength);
}

export function nowSeconds(): number {
  return Math.floor(Date.now() / 1000);
}
