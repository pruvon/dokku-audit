#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env maintenance_doctor
seed_source_deploy_flow

run_cmd "$REPO_ROOT/subcommands/backup" audit:backup
assert_status 0
backup_path="$RUN_OUTPUT"
[[ -f "$backup_path" ]] || fail "backup file was not created"
assert_eq 'ok' "$(sqlite3 "$backup_path" 'PRAGMA integrity_check;')"

run_cmd "$REPO_ROOT/subcommands/doctor"
assert_status 0
assert_contains "$RUN_OUTPUT" 'ok: integrity_check returned ok'

run_cmd "$REPO_ROOT/subcommands/vacuum"
assert_status 0
assert_eq 'vacuum completed' "$RUN_OUTPUT"
assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE category = 'maintenance' AND action = 'vacuum';")"

run_cmd "$REPO_ROOT/report"
assert_status 0
assert_contains "$RUN_OUTPUT" 'audit plugin enabled: true'
assert_contains "$RUN_OUTPUT" 'audit schema version: 5'
assert_contains "$RUN_OUTPUT" 'audit pending deploys: 0'

setup_test_env prune_command
seed_source_deploy_flow
run_cmd "$REPO_ROOT/subcommands/prune" audit:prune --older-than 0 --category app
assert_status 1
assert_contains "$RUN_OUTPUT" 'refusing to prune without --yes'
run_cmd "$REPO_ROOT/subcommands/prune" audit:prune --older-than 0 --category app --yes
assert_status 0
assert_eq 'deleted events: 1' "$RUN_OUTPUT"
assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM events WHERE category = 'app';")"
assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE category = 'maintenance' AND action = 'prune';")"

setup_test_env doctor_stale_pending
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate" audit:migrate
assert_status 0
sqlite3 "$(db_path)" "INSERT INTO pending_deploys(app, correlation_id, source_type, rev, metadata_json, first_seen_ts, updated_ts) VALUES('orphan', 'aud_old', 'git-push', NULL, '{}', '2026-04-06T20:00:00Z', '2026-04-06T20:00:00Z');"
run_cmd "$REPO_ROOT/subcommands/doctor"
assert_status 1
assert_contains "$RUN_OUTPUT" 'issue: stale pending deploy rows detected: 1'

setup_test_env doctor_stale_contexts
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate" audit:migrate
assert_status 0
sqlite3 "$(db_path)" <<'SQL'
INSERT INTO pending_command_contexts(app, subcommand, command_text, args_json, actor_type, actor_name, actor_source, hostname, created_at, actor_meta_json)
VALUES('myapp', 'run', 'dokku run myapp env', '["env"]', 'user', 'alice', 'SSH_NAME', 'host-a', '2026-04-06T20:00:00Z', '{}');
INSERT INTO events(ts, app, category, action, status, classification, source_trigger, source_type, image_tag, rev, actor_type, actor_name, correlation_id, message, meta_json, created_at)
VALUES('2026-04-08T20:00:01Z', 'myapp', 'command', 'run', 'success', 'dokku_run', 'scheduler-run', NULL, NULL, NULL, 'user', 'alice', NULL, 'dokku run scheduled', '{}', '2026-04-08T20:00:01Z');
INSERT INTO pending_runtime_events(event_id, app, subcommand, args_json, created_at, updated_at)
VALUES(1, 'myapp', 'run', '["env"]', '2026-04-06T20:00:00Z', '2026-04-06T20:00:00Z');
INSERT INTO pending_event_actor_contexts(app, event_kind, source_subcommand, command_text, actor_type, actor_name, actor_meta_json, created_at, updated_at)
VALUES('myapp', 'config', 'config:set', 'dokku config:set myapp FOO=[REDACTED]', 'user', 'alice', '{}', '2026-04-06T20:00:00Z', '2026-04-06T20:00:00Z');
SQL
run_cmd "$REPO_ROOT/subcommands/doctor"
assert_status 1
assert_contains "$RUN_OUTPUT" 'issue: stale pending command context rows detected: 1'
assert_contains "$RUN_OUTPUT" 'issue: stale pending runtime event rows detected: 1'
assert_contains "$RUN_OUTPUT" 'issue: stale pending event actor context rows detected: 1'

setup_test_env doctor_app_id
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate" audit:migrate
assert_status 0
sqlite3 "$(db_path)" 'PRAGMA application_id = 999;'
run_cmd "$REPO_ROOT/subcommands/doctor"
assert_status 1
assert_contains "$RUN_OUTPUT" 'issue: application_id mismatch: expected 1145132356, got 999'

setup_test_env maintenance_local_actor
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:01:00Z' DOKKU_AUDIT_SUDO_USER=ubuntu DOKKU_AUDIT_LOCAL_USER=root DOKKU_AUDIT_EFFECTIVE_USER=root "$REPO_ROOT/update"
assert_status 0
assert_eq 'ubuntu' "$(db_query_single "SELECT actor_name FROM events WHERE classification = 'maintenance_migrate' AND message = 'plugin update maintenance completed' LIMIT 1;")"
assert_eq 'SUDO_USER' "$(db_query_single "SELECT json_extract(meta_json, '$.actor_source') FROM events WHERE classification = 'maintenance_migrate' AND message = 'plugin update maintenance completed' LIMIT 1;")"
assert_eq 'ubuntu' "$(db_query_single "SELECT json_extract(meta_json, '$.sudo_user') FROM events WHERE classification = 'maintenance_migrate' AND message = 'plugin update maintenance completed' LIMIT 1;")"

run_cmd "$REPO_ROOT/subcommands/recent" --limit 1
assert_status 0
assert_contains "$RUN_OUTPUT" 'sudo-user:ubuntu'
assert_contains "$RUN_OUTPUT" 'plugin update maintenance completed'
