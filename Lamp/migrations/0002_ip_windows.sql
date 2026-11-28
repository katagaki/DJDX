CREATE TABLE ip_windows (
  ip_hash TEXT NOT NULL,
  action TEXT NOT NULL,
  count INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  PRIMARY KEY (ip_hash, action)
);

CREATE INDEX ip_windows_expiry ON ip_windows (expires_at);
