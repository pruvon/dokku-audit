CREATE INDEX idx_events_ts ON events(ts DESC);
CREATE INDEX idx_events_app_ts ON events(app, ts DESC);
CREATE INDEX idx_events_category_ts ON events(category, ts DESC);
CREATE INDEX idx_events_classification_ts ON events(classification, ts DESC);
CREATE INDEX idx_events_rev ON events(rev);
CREATE INDEX idx_events_correlation_id ON events(correlation_id);