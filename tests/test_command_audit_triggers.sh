#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env command_audit_run
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:01:00Z' SSH_USER=dokku SSH_NAME=alice "$REPO_ROOT/user-auth" dokku alice run myapp ls -lah
assert_status 0
run_at '2026-04-08T20:01:01Z' "$REPO_ROOT/scheduler-run" docker-local myapp ls -lah
assert_status 0
run_at '2026-04-08T20:01:02Z' "$REPO_ROOT/scheduler-post-run" docker-local myapp myapp.run.123
assert_status 0

assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE category = 'command';")"
assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM events WHERE classification = 'dokku_command';")"
assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE classification = 'dokku_run';")"
assert_eq 'alice' "$(db_query_single "SELECT actor_name FROM events WHERE classification = 'dokku_run' LIMIT 1;")"
assert_eq 'SSH_NAME' "$(db_query_single "SELECT json_extract(meta_json, '$.actor_source') FROM events WHERE classification = 'dokku_run' LIMIT 1;")"
assert_eq 'dokku' "$(db_query_single "SELECT json_extract(meta_json, '$.ssh_user') FROM events WHERE classification = 'dokku_run' LIMIT 1;")"
assert_eq 'alice' "$(db_query_single "SELECT json_extract(meta_json, '$.ssh_name') FROM events WHERE classification = 'dokku_run' LIMIT 1;")"
assert_eq 'dokku run myapp ls -lah' "$(db_query_single "SELECT json_extract(meta_json, '$.command') FROM events WHERE classification = 'dokku_run' LIMIT 1;")"
assert_eq 'ls' "$(db_query_single "SELECT json_extract(meta_json, '$.args[0]') FROM events WHERE classification = 'dokku_run' LIMIT 1;")"
assert_eq '-lah' "$(db_query_single "SELECT json_extract(meta_json, '$.args[1]') FROM events WHERE classification = 'dokku_run' LIMIT 1;")"
assert_eq 'myapp.run.123' "$(db_query_single "SELECT json_extract(meta_json, '$.container_id') FROM events WHERE classification = 'dokku_run' LIMIT 1;")"
assert_eq 'container_created' "$(db_query_single "SELECT json_extract(meta_json, '$.success_hint') FROM events WHERE classification = 'dokku_run' LIMIT 1;")"
assert_eq 'yes' "$(db_query_single "SELECT CASE WHEN COALESCE(json_extract(meta_json, '$.hostname'), '') != '' THEN 'yes' ELSE 'no' END FROM events WHERE classification = 'dokku_run' LIMIT 1;")"
assert_eq '0' "$(db_query_single 'SELECT COUNT(1) FROM pending_command_contexts;')"
assert_eq '0' "$(db_query_single 'SELECT COUNT(1) FROM pending_runtime_events;')"

setup_test_env command_audit_skip_noisy
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:01:00Z' "$REPO_ROOT/user-auth" dokku alice apps:list
assert_status 0
run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:01:01Z' "$REPO_ROOT/user-auth" dokku alice postgres:list
assert_status 0
run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:01:02Z' "$REPO_ROOT/user-auth" dokku alice config:show myapp
assert_status 0
run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:01:03Z' "$REPO_ROOT/user-auth" dokku alice report myapp
assert_status 0
run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:01:04Z' "$REPO_ROOT/user-auth" dokku alice ps:retire myapp web.1
assert_status 0
run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:01:05Z' "$REPO_ROOT/user-auth" dokku alice audit:recent
assert_status 0
run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:01:06Z' "$REPO_ROOT/user-auth" dokku alice --version
assert_status 0
run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:01:07Z' "$REPO_ROOT/user-auth" dokku alice postgres:links database
assert_status 0
run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:01:08Z' "$REPO_ROOT/user-auth" dokku alice redis:app-links myapp
assert_status 0
run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:01:09Z' "$REPO_ROOT/user-auth" dokku alice postgres:connect database
assert_status 0
run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:01:10Z' "$REPO_ROOT/user-auth" dokku alice logs myapp
assert_status 0
run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:01:11Z' "$REPO_ROOT/user-auth" dokku alice config myapp
assert_status 0
run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:01:12Z' "$REPO_ROOT/user-auth" dokku alice resource:limit myapp
assert_status 0

assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE category = 'command';")"
assert_eq '0' "$(db_query_single 'SELECT COUNT(1) FROM pending_command_contexts;')"
assert_eq 'postgres:connect' "$(db_query_single "SELECT json_extract(meta_json, '$.subcommand') FROM events WHERE classification = 'dokku_command' LIMIT 1;")"
assert_eq 'database' "$(db_query_single "SELECT json_extract(meta_json, '$.args[0]') FROM events WHERE classification = 'dokku_command' LIMIT 1;")"

setup_test_env command_audit_enter
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:02:00Z' SSH_USER=dokku SSH_NAME=alice "$REPO_ROOT/user-auth" dokku alice enter myapp --container-id abc123 echo hi
assert_status 0
run_at '2026-04-08T20:02:01Z' "$REPO_ROOT/scheduler-enter" docker-local myapp --container-id abc123 echo hi
assert_status 0

assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE category = 'command';")"
assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM events WHERE classification = 'dokku_command';")"
assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE classification = 'dokku_enter';")"
assert_eq 'abc123' "$(db_query_single "SELECT json_extract(meta_json, '$.container_id') FROM events WHERE classification = 'dokku_enter' LIMIT 1;")"
assert_eq 'dokku' "$(db_query_single "SELECT json_extract(meta_json, '$.ssh_user') FROM events WHERE classification = 'dokku_enter' LIMIT 1;")"
assert_eq 'alice' "$(db_query_single "SELECT json_extract(meta_json, '$.ssh_name') FROM events WHERE classification = 'dokku_enter' LIMIT 1;")"
assert_eq 'echo' "$(db_query_single "SELECT json_extract(meta_json, '$.args[0]') FROM events WHERE classification = 'dokku_enter' LIMIT 1;")"
assert_eq 'hi' "$(db_query_single "SELECT json_extract(meta_json, '$.args[1]') FROM events WHERE classification = 'dokku_enter' LIMIT 1;")"
assert_eq 'dokku enter myapp --container-id abc123 echo hi' "$(db_query_single "SELECT json_extract(meta_json, '$.command') FROM events WHERE classification = 'dokku_enter' LIMIT 1;")"
assert_eq 'enter_requested' "$(db_query_single "SELECT json_extract(meta_json, '$.success_hint') FROM events WHERE classification = 'dokku_enter' LIMIT 1;")"
assert_eq '0' "$(db_query_single 'SELECT COUNT(1) FROM pending_command_contexts;')"

setup_test_env command_audit_redaction
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:03:00Z' SSH_USER=dokku SSH_NAME=alice "$REPO_ROOT/user-auth" dokku alice config:set --no-restart myapp SECRET_KEY_BASE=supersecret RAILS_ENV=production
assert_status 0
run_at '2026-04-08T20:03:01Z' "$REPO_ROOT/post-config-update" myapp set SECRET_KEY_BASE=supersecret RAILS_ENV=production
assert_status 0

assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM events WHERE classification = 'dokku_command';")"
assert_eq 'myapp' "$(db_query_single "SELECT app FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'alice' "$(db_query_single "SELECT actor_name FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'user' "$(db_query_single "SELECT actor_type FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'SSH_NAME' "$(db_query_single "SELECT json_extract(meta_json, '$.actor_source') FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'dokku' "$(db_query_single "SELECT json_extract(meta_json, '$.ssh_user') FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'alice' "$(db_query_single "SELECT json_extract(meta_json, '$.ssh_name') FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'config:set' "$(db_query_single "SELECT json_extract(meta_json, '$.triggered_by_subcommand') FROM events WHERE classification = 'config_change' LIMIT 1;")"
command_meta="$(db_query_single "SELECT json_extract(meta_json, '$.triggered_by_command') FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_contains "$command_meta" 'SECRET_KEY_BASE=[REDACTED]'
assert_contains "$command_meta" 'RAILS_ENV=[REDACTED]'
assert_not_contains "$command_meta" 'supersecret'
assert_eq '0' "$(db_query_single 'SELECT COUNT(1) FROM pending_event_actor_contexts;')"

setup_test_env command_audit_resource_limit
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_cmd env DOKKU_AUDIT_NOW='2026-04-08T20:04:00Z' SSH_USER=dokku SSH_NAME=alice "$REPO_ROOT/user-auth" dokku alice resource:limit myapp --memory 512m --cpu 2
assert_status 0

assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE classification = 'dokku_command';")"
assert_eq 'myapp' "$(db_query_single "SELECT app FROM events WHERE classification = 'dokku_command' LIMIT 1;")"
assert_eq '--memory' "$(db_query_single "SELECT json_extract(meta_json, '$.args[0]') FROM events WHERE classification = 'dokku_command' LIMIT 1;")"
assert_eq '512m' "$(db_query_single "SELECT json_extract(meta_json, '$.args[1]') FROM events WHERE classification = 'dokku_command' LIMIT 1;")"
assert_eq '--cpu' "$(db_query_single "SELECT json_extract(meta_json, '$.args[2]') FROM events WHERE classification = 'dokku_command' LIMIT 1;")"
assert_eq '2' "$(db_query_single "SELECT json_extract(meta_json, '$.args[3]') FROM events WHERE classification = 'dokku_command' LIMIT 1;")"

run_cmd "$REPO_ROOT/subcommands/recent" --limit 1
assert_status 0
assert_contains "$RUN_OUTPUT" 'ACTOR'
assert_contains "$RUN_OUTPUT" 'myapp'
assert_contains "$RUN_OUTPUT" 'ssh-key:alice'
assert_contains "$RUN_OUTPUT" 'dokku resource:limit myapp --memory 512m --cpu 2'
