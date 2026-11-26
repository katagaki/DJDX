CREATE TABLE contributors (
  id TEXT PRIMARY KEY,
  public_key BLOB NOT NULL,
  deletion_hash TEXT NOT NULL UNIQUE,
  trust_tier TEXT NOT NULL,
  excluded INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL
);

CREATE INDEX contributors_last_seen ON contributors (last_seen_at);

CREATE TABLE attest_keys (
  key_id TEXT PRIMARY KEY,
  contributor_id TEXT NOT NULL REFERENCES contributors (id) ON DELETE CASCADE,
  public_key BLOB NOT NULL,
  environment TEXT NOT NULL,
  counter INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE INDEX attest_keys_contributor ON attest_keys (contributor_id);

CREATE TABLE challenges (
  value TEXT PRIMARY KEY,
  expires_at INTEGER NOT NULL
);

CREATE TABLE scores (
  contributor_id TEXT NOT NULL REFERENCES contributors (id) ON DELETE CASCADE,
  game TEXT NOT NULL,
  source TEXT NOT NULL,
  song_key TEXT NOT NULL,
  play_type TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  lamp INTEGER NOT NULL,
  ex_score INTEGER NOT NULL,
  pgreat INTEGER,
  great INTEGER,
  miss_count INTEGER,
  trust_tier TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (contributor_id, game, source, song_key, play_type, difficulty)
);

CREATE INDEX scores_chart ON scores (game, source, song_key, play_type, difficulty);

CREATE TABLE dirty_snapshots (
  game TEXT NOT NULL,
  source TEXT NOT NULL,
  marked_at INTEGER NOT NULL,
  PRIMARY KEY (game, source)
);

CREATE TABLE chart_rules (
  game TEXT NOT NULL,
  song_key TEXT NOT NULL,
  play_type TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  max_notes INTEGER,
  hidden INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (game, song_key, play_type, difficulty)
);

CREATE TABLE song_aliases (
  game TEXT NOT NULL,
  alias_key TEXT NOT NULL,
  canonical_key TEXT NOT NULL,
  PRIMARY KEY (game, alias_key)
);

CREATE TABLE reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  contributor_id TEXT REFERENCES contributors (id) ON DELETE SET NULL,
  game TEXT NOT NULL,
  source TEXT NOT NULL,
  song_key TEXT NOT NULL,
  play_type TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  reason TEXT NOT NULL,
  note TEXT,
  snapshot_at INTEGER,
  status TEXT NOT NULL DEFAULT 'open',
  created_at INTEGER NOT NULL,
  resolved_at INTEGER,
  resolved_by TEXT,
  UNIQUE (contributor_id, game, source, song_key, play_type, difficulty)
);

CREATE INDEX reports_status ON reports (status, created_at);

CREATE TABLE usage_counters (
  contributor_id TEXT NOT NULL REFERENCES contributors (id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  day INTEGER NOT NULL,
  count INTEGER NOT NULL,
  PRIMARY KEY (contributor_id, action, day)
);
