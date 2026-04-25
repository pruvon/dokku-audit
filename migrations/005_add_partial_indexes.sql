CREATE INDEX idx_events_deploy ON events(ts DESC) WHERE category = 'deploy';
