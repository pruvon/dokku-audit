ALTER TABLE pending_command_contexts ADD COLUMN actor_meta_json TEXT NOT NULL DEFAULT '{}';

CREATE TABLE pending_event_actor_contexts (
  app TEXT NOT NULL,
  event_kind TEXT NOT NULL,
  source_subcommand TEXT NOT NULL,
  command_text TEXT NOT NULL,
  actor_type TEXT NOT NULL DEFAULT 'system',
  actor_name TEXT,
  actor_meta_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (app, event_kind)
);

CREATE INDEX idx_pending_event_actor_contexts_updated_at ON pending_event_actor_contexts(updated_at);
