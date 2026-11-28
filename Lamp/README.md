# Lamp

Opt-in community score server for DJDX (Cloudflare Workers + D1 + R2), served at `djdx.ktgk.app`.

## Local development

```sh
npm install
cp .dev.vars.example .dev.vars   # fill both values with `openssl rand -hex 32`
npm run db:migrate:local
npm run dev            # http://127.0.0.1:8787
npm test               # unit tests (App Attest verifier, IIDX validation)
npm run e2e            # end-to-end checks against the running dev server
npm run typecheck
```

## Client protocol

Every write uses a one-time challenge from `POST /v1/challenge` (valid 5 minutes).

Canonical request string, signed with the contributor's P-256 key (ECDSA SHA-256, raw 64-byte `r‖s`, base64url):

```
LAMP1\n{METHOD}\n{path}\n{challenge}\n{base64url(SHA-256(body))}
```

| Header | Value |
| --- | --- |
| `X-Lamp-Contributor` | contributor ID (not sent on enrolment) |
| `X-Lamp-Challenge` | challenge |
| `X-Lamp-Signature` | contributor signature over the canonical string |
| `X-Lamp-Attest-Key` | App Attest key ID (optional) |
| `X-Lamp-Assertion` | App Attest assertion, base64, with `clientDataHash = SHA-256(canonical string)` (optional) |

Without an assertion the request is `unattested` and gets lower daily limits.

Per IP (IPv6 grouped by /64), each hour allows 3 uploads, 3 enrolments and 10 reports; going over returns `429` with `Retry-After`. Only an HMAC of the IP (keyed with the `IP_HASH_SECRET` secret) is stored, and each row is deleted when its hour ends (checked on every request and by the 5-minute cron).

Contributors count towards snapshots only once they are 3 days old. Snapshots rebuild once a day at 05:00 JST; admin actions rebuild the affected versions immediately. Contributors inactive for 180 days are deleted, so the app should send a heartbeat about once every 24 hours while contribution is on.

### Endpoints

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/` | Redirects to the GitHub repository |
| `POST` | `/v1/challenge` | `{ challenge, expiresAt }` |
| `POST` | `/v1/contributors` | Enrol or add an App Attest key: `{ publicKey, deletionCodeHash, attestation?: { keyId, object } }` |
| `DELETE` | `/v1/contributors/me` | Signed; deletes the contributor and all their rows |
| `POST` | `/v1/heartbeat` | Signed, empty body; keeps the contributor active (at most 3 per day) |
| `POST` | `/v1/deletions` | `{ deletionCode }`; deletes without the key |
| `POST` | `/v1/scores` | Signed; `{ game: "iidx", source, records: [...] }`, at most 5000 records |
| `POST` | `/v1/reports` | Signed; `{ game, source, title, playType, difficulty, reason, note?, snapshotAt? }` |
| `GET` | `/v1/snapshots/index.json` | Available snapshots |
| `GET` | `/v1/snapshots/iidx/{source}.json` | Per-version aggregates, no authentication |

- `publicKey`: base64url of the uncompressed X9.63 point (65 bytes, `P256.Signing.PublicKey.x963Representation`).
- Contributor ID: base64url of the first 16 bytes of `SHA-256(publicKey)`.
- Enrolment attestation: `clientDataHash = SHA-256("LAMP1-ATTEST\n{challenge}\n{publicKey}")`.
- Deletion code: uppercase it and strip everything except `0-9A-Z`; `deletionCodeHash` is the hex SHA-256 of that string.
- `source`: `arcade-{version}` (e.g. `arcade-33`) or `infinitas`.
- Score record: `{ title, playType: "SP"|"DP", difficulty, clearType, exScore, pgreat?, great?, missCount? }`, with `clearType` using `IIDXClearType` raw values except `NO PLAY`.
- Snapshot song keys: title → NFKC → lowercase → whitespace removed.
- Snapshot charts: `lamps` holds the player count per lamp and `rates` the share of players with that lamp or better, both in `lampOrder` (so `rates[3]` is CLEAR+ and `rates[6]` is FC).
- Snapshot `scores`: `[start, count]` pairs in ascending order. Each bucket covers EX scores from `start` up to the next bucket's `start` (the last is open-ended), and holds at least 3 players.

### Admin

The admin page is at `/admin/` (locally http://127.0.0.1:8787/admin/). In production it is protected by Cloudflare Access:

1. Create a self-hosted Access application for `djdx.ktgk.app/admin` with a policy allowing your email.
2. Set `ACCESS_TEAM_DOMAIN` (e.g. `<team>.cloudflareaccess.com`) and `ACCESS_AUD` (the application's AUD tag) in `wrangler.jsonc`.

The Worker verifies the `Cf-Access-Jwt-Assertion` token on every admin request, and admin routes return 404 while those values are empty. Locally, open `http://127.0.0.1:8787/admin/?dev=<ADMIN_DEV_TOKEN>` once to get a sign-in cookie; this only works on `localhost`/`127.0.0.1` while Access is not configured. Admin writes must be same-origin JSON requests.

Set the IP hashing secret with `npx wrangler secret put IP_HASH_SECRET` (generate it with `openssl rand -hex 32`); uploads return `503` without it.

The D1 database `djdx-lamp` and R2 bucket `djdx-lamp-snapshots` are created by Wrangler on the first deploy, which then writes the database ID into `wrangler.jsonc`.

| Method | Path | Body / query |
| --- | --- | --- |
| `GET` | `/admin/reports` | `?status=open\|resolved\|dismissed` |
| `PATCH` | `/admin/reports/{id}` | `{ status }` |
| `GET` | `/admin/charts` | `?game&source&title&playType&difficulty` |
| `POST` | `/admin/purge` | `{ game, source, contributorId?, title?+playType+difficulty, minExScore? }` |
| `POST` | `/admin/contributors/{id}/quarantine` | `{ excluded }` |
| `PUT` | `/admin/chart-rules` | `{ game, title, playType, difficulty, maxNotes?, hidden? }` |
| `PUT` | `/admin/song-aliases` | `{ game, alias, canonical }` |
| `POST` | `/admin/rebuild` | `{ game?, source? }` |
