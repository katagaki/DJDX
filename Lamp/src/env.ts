export interface Env {
  DB: D1Database;
  SNAPSHOTS: R2Bucket;
  ASSETS: Fetcher;
  IP_LIMITER?: RateLimit;
  APP_ATTEST_APP_IDS: string;
  ALLOW_UNATTESTED: string;
  REPOSITORY_URL: string;
  ACCESS_TEAM_DOMAIN: string;
  ACCESS_AUD: string;
  ADMIN_DEV_TOKEN?: string;
  IP_HASH_SECRET?: string;
}
