import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { readFileSync } from "node:fs";

const BASE = process.env.LAMP_URL ?? "http://127.0.0.1:8787";
const DEV_TOKEN = readFileSync(new URL("../.dev.vars", import.meta.url), "utf8").match(/^ADMIN_DEV_TOKEN=(.+)$/m)?.[1]?.trim();
const SOURCE = `arcade-${30 + Math.floor(Math.random() * 20)}`;
const SONG = `E2E Song ${randomBytes(4).toString("hex")}`;

const b64url = (bytes) => Buffer.from(bytes).toString("base64url");
const sha256 = (data) => createHash("sha256").update(data).digest();
let passed = 0;

function backdate(ids, days) {
  const list = ids.map((id) => `'${id.replace(/[^A-Za-z0-9_-]/g, "")}'`).join(",");
  execFileSync("npx", ["wrangler", "d1", "execute", "djdx-lamp", "--local", "--command", `UPDATE contributors SET created_at = created_at - ${days * 86400} WHERE id IN (${list})`], {
    cwd: new URL("..", import.meta.url),
    stdio: "ignore",
  });
}

async function step(name, fn) {
  await fn();
  passed++;
  console.log(`✓ ${name}`);
}

async function challenge() {
  const response = await fetch(`${BASE}/v1/challenge`, { method: "POST", headers: { "CF-Connecting-IP": `10.0.${randomBytes(1)[0]}.${randomBytes(1)[0]}` } });
  assert.equal(response.status, 200);
  return (await response.json()).challenge;
}

function canonical(method, path, challengeValue, body) {
  return ["LAMP1", method, path, challengeValue, b64url(sha256(body))].join("\n");
}

async function sign(keys, message) {
  return b64url(new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, keys.privateKey, new TextEncoder().encode(message))));
}

async function newContributor() {
  const keys = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const publicKey = b64url(new Uint8Array(await crypto.subtle.exportKey("raw", keys.publicKey)));
  const deletionCode = randomBytes(16).toString("hex").toUpperCase().match(/.{4}/g).join("-");
  return { keys, publicKey, deletionCode, id: null, ip: `10.1.${randomBytes(1)[0]}.${randomBytes(1)[0]}` };
}

async function enroll(contributor, extra = {}) {
  const body = JSON.stringify({
    publicKey: contributor.publicKey,
    deletionCodeHash: sha256(contributor.deletionCode.replace(/[^0-9A-Z]/g, "")).toString("hex"),
    ...extra,
  });
  const value = await challenge();
  const response = await fetch(`${BASE}/v1/contributors`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "CF-Connecting-IP": contributor.ip,
      "X-Lamp-Challenge": value,
      "X-Lamp-Signature": await sign(contributor.keys, canonical("POST", "/v1/contributors", value, body)),
    },
    body,
  });
  const json = await response.json();
  if (response.ok) contributor.id = json.contributorId;
  return { status: response.status, json };
}

async function signed(contributor, method, path, payload, { challengeValue, tamper } = {}) {
  const body = payload === undefined ? "" : JSON.stringify(payload);
  const value = challengeValue ?? (await challenge());
  const signature = await sign(contributor.keys, canonical(method, path, value, body));
  const response = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      "CF-Connecting-IP": contributor.ip,
      "X-Lamp-Contributor": contributor.id,
      "X-Lamp-Challenge": value,
      "X-Lamp-Signature": signature,
    },
    body: method === "GET" ? undefined : tamper ? body.replace("CLEAR", "FULLCOMBO CLEAR") : body,
  });
  return { status: response.status, json: await response.json(), retryAfter: response.headers.get("Retry-After") };
}

async function admin(method, path, payload) {
  const response = await fetch(`${BASE}/admin${path}`, {
    method,
    headers: { "Content-Type": "application/json", Cookie: `lamp_dev=${DEV_TOKEN}` },
    body: payload === undefined ? undefined : JSON.stringify(payload),
  });
  return { status: response.status, json: await response.json() };
}

async function snapshot() {
  await admin("POST", "/rebuild", { game: "iidx", source: SOURCE });
  const response = await fetch(`${BASE}/v1/snapshots/iidx/${SOURCE}.json`);
  assert.equal(response.status, 200);
  return { json: await response.json(), etag: response.headers.get("ETag") };
}

const chartOf = (json, title = SONG) => json.songs[title.normalize("NFKC").toLowerCase().replace(/\s+/gu, "")]?.SP?.ANOTHER;
const LAMPS = ["FAILED", "ASSIST CLEAR", "EASY CLEAR", "CLEAR", "HARD CLEAR", "EX HARD CLEAR", "FULLCOMBO CLEAR"];
const contributors = [];

await step("GET / redirects to the repository", async () => {
  const response = await fetch(`${BASE}/`, { redirect: "manual" });
  assert.equal(response.status, 302);
  assert.equal(response.headers.get("Location"), "https://github.com/katagaki/DJDX");
});

await step("enrolls 12 unattested contributors", async () => {
  for (let i = 0; i < 12; i++) {
    const contributor = await newContributor();
    const { status, json } = await enroll(contributor);
    assert.equal(status, 201, JSON.stringify(json));
    assert.equal(json.trustTier, "unattested");
    contributors.push(contributor);
  }
});

await step("re-enrolling the same key is idempotent", async () => {
  const { status, json } = await enroll(contributors[0]);
  assert.equal(status, 200);
  assert.equal(json.contributorId, contributors[0].id);
});

await step("rejects a forged App Attest attestation", async () => {
  const { status, json } = await enroll(await newContributor(), { attestation: { keyId: b64url(randomBytes(32)), object: b64url(randomBytes(64)) } });
  assert.equal(status, 401);
  assert.equal(json.error, "invalid_attestation");
});

await step("rejects enrollment signed by a different key", async () => {
  const contributor = await newContributor();
  const other = await newContributor();
  const body = JSON.stringify({ publicKey: contributor.publicKey, deletionCodeHash: "0".repeat(64) });
  const value = await challenge();
  const response = await fetch(`${BASE}/v1/contributors`, {
    method: "POST",
    headers: { "X-Lamp-Challenge": value, "X-Lamp-Signature": await sign(other.keys, canonical("POST", "/v1/contributors", value, body)) },
    body,
  });
  assert.equal(response.status, 401);
});

await step("uploads scores and rejects inconsistent records", async () => {
  for (const [i, contributor] of contributors.entries()) {
    const lamp = LAMPS[i % LAMPS.length];
    const exScore = 2000 + i * 50;
    const records = [
      { title: SONG, playType: "SP", difficulty: "ANOTHER", clearType: lamp, exScore, pgreat: (exScore - 100) / 2, great: 100, missCount: lamp === "FULLCOMBO CLEAR" ? 0 : 5 },
      { title: `${SONG} rare`, playType: "SP", difficulty: "ANOTHER", clearType: "CLEAR", exScore: 100 },
    ];
    if (i === 0) records.push({ title: SONG, playType: "SP", difficulty: "HYPER", clearType: "CLEAR", exScore: 999, pgreat: 100, great: 100 });
    const { status, json } = await signed(contributor, "POST", "/v1/scores", { game: "iidx", source: SOURCE, records });
    assert.equal(status, 200, JSON.stringify(json));
    assert.equal(json.accepted, 2);
    assert.deepEqual(json.rejected, i === 0 ? [{ index: 2, reason: "ex_score_mismatch" }] : []);
  }
});

await step("rejects a replayed challenge", async () => {
  const value = await challenge();
  const first = await signed(contributors[1], "POST", "/v1/scores", { game: "iidx", source: SOURCE, records: [] }, { challengeValue: value });
  assert.equal(first.status, 200);
  const replay = await signed(contributors[1], "POST", "/v1/scores", { game: "iidx", source: SOURCE, records: [] }, { challengeValue: value });
  assert.equal(replay.status, 401);
  assert.equal(replay.json.error, "invalid_challenge");
});

await step("rejects a tampered body", async () => {
  const { status, json } = await signed(
    contributors[1],
    "POST",
    "/v1/scores",
    { game: "iidx", source: SOURCE, records: [{ title: SONG, playType: "SP", difficulty: "ANOTHER", clearType: "CLEAR", exScore: 1 }] },
    { tamper: true },
  );
  assert.equal(status, 401);
  assert.equal(json.error, "invalid_signature");
});

await step("limits each IP to 3 uploads per hour", async () => {
  const contributor = contributors[6];
  contributor.ip = `10.2.${randomBytes(1)[0]}.${randomBytes(1)[0]}`;
  const upload = () => signed(contributor, "POST", "/v1/scores", { game: "iidx", source: SOURCE, records: [] });
  for (let i = 0; i < 3; i++) assert.equal((await upload()).status, 200);
  const limited = await upload();
  assert.equal(limited.status, 429);
  assert.equal(limited.json.error, "ip_upload_limit_reached");
  assert.ok(Number(limited.retryAfter) > 3500 && Number(limited.retryAfter) <= 3600);
  contributor.ip = `10.3.${randomBytes(1)[0]}.${randomBytes(1)[0]}`;
  assert.equal((await upload()).status, 200);
});

await step("rejects requests from unknown contributors", async () => {
  const stranger = await newContributor();
  stranger.id = "unknown";
  const { status, json } = await signed(stranger, "POST", "/v1/scores", { game: "iidx", source: SOURCE, records: [] });
  assert.equal(status, 401);
  assert.equal(json.error, "invalid_signature");
});

await step("limits each IP to 3 enrolments per hour", async () => {
  const ip = `10.4.${randomBytes(1)[0]}.${randomBytes(1)[0]}`;
  const results = [];
  for (let i = 0; i < 4; i++) {
    const contributor = await newContributor();
    contributor.ip = ip;
    results.push(await enroll(contributor));
  }
  assert.deepEqual(results.map((r) => r.status), [201, 201, 201, 429]);
  assert.equal(results[3].json.error, "ip_enroll_limit_reached");
});

await step("heartbeat succeeds and is capped per day", async () => {
  const statuses = [];
  for (let i = 0; i < 4; i++) statuses.push((await signed(contributors[7], "POST", "/v1/heartbeat")).status);
  assert.deepEqual(statuses, [200, 200, 200, 429]);
});

await step("contributors younger than 3 days are left out of snapshots", async () => {
  assert.equal(chartOf((await snapshot()).json), undefined);
  backdate(contributors.map((c) => c.id), 4);
});

let etag;
await step("publishes a snapshot with n ≥ 10 charts only", async () => {
  const result = await snapshot();
  etag = result.etag;
  const chart = chartOf(result.json);
  assert.equal(chart.n, 12);
  assert.deepEqual(chart.lamps, [2, 2, 2, 2, 2, 1, 1]);
  assert.deepEqual(chart.rates, [1, 0.8333, 0.6667, 0.5, 0.3333, 0.1667, 0.0833]);
  assert.equal(chart.scores.reduce((sum, [, count]) => sum + count, 0), 12);
  assert.ok(chart.scores.every(([, count]) => count >= 3));
  assert.equal(result.json.minSample, 10);
  assert.ok(chartOf(result.json, `${SONG} rare`));
  assert.equal(result.json.songs[SONG.toLowerCase().replace(/\s+/g, "")]?.SP?.HYPER, undefined);
});

await step("serves 304 for an unchanged snapshot and lists it in the index", async () => {
  const response = await fetch(`${BASE}/v1/snapshots/iidx/${SOURCE}.json`, { headers: { "If-None-Match": etag } });
  assert.equal(response.status, 304);
  const index = await (await fetch(`${BASE}/v1/snapshots/index.json`)).json();
  assert.ok(index.sources.some((entry) => entry.source === SOURCE && entry.charts === 2));
});

await step("accepts a report and deduplicates repeats", async () => {
  const payload = { game: "iidx", source: SOURCE, title: SONG, playType: "SP", difficulty: "ANOTHER", reason: "impossible_score", note: "Top score looks wrong" };
  const first = await signed(contributors[2], "POST", "/v1/reports", payload);
  assert.equal(first.status, 201);
  const second = await signed(contributors[2], "POST", "/v1/reports", payload);
  assert.equal(second.status, 200);
  assert.equal(second.json.duplicate, true);
  const invalid = await signed(contributors[2], "POST", "/v1/reports", { ...payload, reason: "spam" });
  assert.equal(invalid.status, 400);
});

await step("admin requires the dev sign-in cookie locally", async () => {
  assert.equal((await fetch(`${BASE}/admin/api/me`)).status, 404);
  assert.equal((await fetch(`${BASE}/admin/api/me`, { headers: { Cookie: "lamp_dev=wrong" } })).status, 404);
  assert.equal((await fetch(`${BASE}/admin/?dev=wrong`, { redirect: "manual" })).status, 404);
  const signIn = await fetch(`${BASE}/admin/?dev=${DEV_TOKEN}`, { redirect: "manual" });
  assert.equal(signIn.status, 303);
  assert.match(signIn.headers.get("Set-Cookie"), /^lamp_dev=.+; Path=\/admin; HttpOnly; SameSite=Strict$/);
});

await step("admin page is served with a strict CSP", async () => {
  const response = await fetch(`${BASE}/admin/`, { headers: { Cookie: `lamp_dev=${DEV_TOKEN}` } });
  assert.equal(response.status, 200);
  assert.match(await response.text(), /Lamp Admin/);
  assert.match(response.headers.get("Content-Security-Policy"), /default-src 'self'/);
  assert.equal((await fetch(`${BASE}/admin/app.js`, { headers: { Cookie: `lamp_dev=${DEV_TOKEN}` } })).status, 200);
});

await step("admin writes reject cross-origin and non-JSON requests", async () => {
  const crossOrigin = await fetch(`${BASE}/admin/rebuild`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Origin: "https://evil.example", Cookie: `lamp_dev=${DEV_TOKEN}` },
    body: "{}",
  });
  assert.equal(crossOrigin.status, 403);
  const form = await fetch(`${BASE}/admin/rebuild`, { method: "POST", headers: { "Content-Type": "text/plain", Cookie: `lamp_dev=${DEV_TOKEN}` }, body: "{}" });
  assert.equal(form.status, 415);
});

let reportId;
await step("admin lists reports and inspects anonymized chart rows", async () => {
  const { json } = await admin("GET", "/reports");
  const report = json.reports.find((entry) => entry.source === SOURCE);
  assert.ok(report);
  reportId = report.id;
  const chart = await admin("GET", `/charts?game=iidx&source=${SOURCE}&title=${encodeURIComponent(SONG)}&playType=SP&difficulty=ANOTHER`);
  assert.equal(chart.json.rows.length, 12);
  assert.deepEqual(Object.keys(chart.json.rows[0]).sort(), ["contributor_id", "ex_score", "excluded", "great", "lamp", "miss_count", "pgreat", "trust_tier", "updated_at"]);
});

await step("quarantined contributors drop out of snapshots and are shadow-ignored", async () => {
  const { status } = await admin("POST", `/contributors/${contributors[11].id}/quarantine`, { excluded: true });
  assert.equal(status, 200);
  assert.equal(chartOf((await snapshot()).json).n, 11);
  const upload = await signed(contributors[11], "POST", "/v1/scores", {
    game: "iidx",
    source: SOURCE,
    records: [{ title: `${SONG} quarantine`, playType: "SP", difficulty: "ANOTHER", clearType: "CLEAR", exScore: 1 }],
  });
  assert.equal(upload.status, 200);
  const rows = await admin("GET", `/charts?game=iidx&source=${SOURCE}&title=${encodeURIComponent(`${SONG} quarantine`)}&playType=SP&difficulty=ANOTHER`);
  assert.equal(rows.json.rows.length, 0);
});

await step("chart rules purge rows above the note cap", async () => {
  const { json } = await admin("PUT", "/chart-rules", { game: "iidx", title: SONG, playType: "SP", difficulty: "ANOTHER", maxNotes: 1200 });
  assert.equal(json.purged, 5);
  const upload = await signed(contributors[3], "POST", "/v1/scores", {
    game: "iidx",
    source: SOURCE,
    records: [{ title: SONG, playType: "SP", difficulty: "ANOTHER", clearType: "CLEAR", exScore: 2401 }],
  });
  assert.deepEqual(upload.json.rejected, [{ index: 0, reason: "ex_score_above_max" }]);
  assert.equal(chartOf((await snapshot()).json), undefined);
  await admin("PUT", "/chart-rules", { game: "iidx", title: SONG, playType: "SP", difficulty: "ANOTHER", maxNotes: null });
});

await step("hidden charts are left out of snapshots", async () => {
  await admin("PUT", "/chart-rules", { game: "iidx", title: `${SONG} rare`, playType: "SP", difficulty: "ANOTHER", hidden: true });
  assert.equal(chartOf((await snapshot()).json, `${SONG} rare`), undefined);
  await admin("PUT", "/chart-rules", { game: "iidx", title: `${SONG} rare`, playType: "SP", difficulty: "ANOTHER", hidden: false });
  assert.ok(chartOf((await snapshot()).json, `${SONG} rare`));
});

await step("admin resolves the report", async () => {
  const { status } = await admin("PATCH", `/reports/${reportId}`, { status: "resolved" });
  assert.equal(status, 200);
});

await step("contributors delete themselves with a signed request", async () => {
  const { status, json } = await signed(contributors[4], "DELETE", "/v1/contributors/me");
  assert.equal(status, 200);
  assert.equal(json.deleted, true);
  const after = await signed(contributors[4], "POST", "/v1/scores", { game: "iidx", source: SOURCE, records: [] });
  assert.equal(after.status, 401);
});

await step("deleting a contributor also deletes their reports", async () => {
  assert.equal((await signed(contributors[2], "DELETE", "/v1/contributors/me")).status, 200);
  const { json } = await admin("GET", "/reports?status=resolved");
  assert.ok(!json.reports.some((report) => report.id === reportId));
});

await step("contributors delete themselves with the deletion code", async () => {
  const response = await fetch(`${BASE}/v1/deletions`, { method: "POST", body: JSON.stringify({ deletionCode: contributors[5].deletionCode.toLowerCase() }) });
  assert.deepEqual(await response.json(), { deleted: true });
  const again = await fetch(`${BASE}/v1/deletions`, { method: "POST", body: JSON.stringify({ deletionCode: contributors[5].deletionCode }) });
  assert.deepEqual(await again.json(), { deleted: false });
  assert.equal(chartOf((await snapshot()).json, `${SONG} rare`), undefined);
});

await step("scheduled handler runs", async () => {
  assert.equal((await fetch(`${BASE}/__scheduled?cron=*/5+*+*+*+*`)).status, 200);
  assert.equal((await fetch(`${BASE}/__scheduled?cron=0+20+*+*+*`)).status, 200);
});

console.log(`\n${passed} checks passed against ${BASE} (${SOURCE})`);
