CREATE TABLE events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT NOT NULL,
  app TEXT,
  category TEXT NOT NULL,
  action TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'success',
  classification TEXT,
  source_trigger TEXT NOT NULL,
  source_type TEXT,
  image_tag TEXT,
  rev TEXT,
  actor_type TEXT NOT NULL DEFAULT 'system',
  actor_name TEXT,
  correlation_id TEXT,
  message TEXT,
  meta_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL
);

CREATE TABLE pending_deploys (
  app TEXT PRIMARY KEY,
  correlation_id TEXT NOT NULL,
  source_type TEXT,
  rev TEXT,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  first_seen_ts TEXT NOT NULL,
  updated_ts TEXT NOT NULL
);

CREATE TABLE meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);