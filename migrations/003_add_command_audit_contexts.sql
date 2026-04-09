CREATE TABLE pending_command_contexts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  app TEXT,
  subcommand TEXT NOT NULL,
  command_text TEXT NOT NULL,
  args_json TEXT NOT NULL DEFAULT '[]',
  actor_type TEXT NOT NULL DEFAULT 'system',
  actor_name TEXT,
  actor_source TEXT,
  hostname TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE pending_runtime_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id INTEGER NOT NULL,
  app TEXT NOT NULL,
  subcommand TEXT NOT NULL,
  args_json TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(event_id) REFERENCES events(id) ON DELETE CASCADE
);

CREATE INDEX idx_pending_command_contexts_lookup ON pending_command_contexts(subcommand, app, created_at DESC);
CREATE UNIQUE INDEX idx_pending_runtime_events_event_id ON pending_runtime_events(event_id);
CREATE INDEX idx_pending_runtime_events_lookup ON pending_runtime_events(subcommand, app, created_at DESC);
