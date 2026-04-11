#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env deploy_classification
seed_source_deploy_flow

assert_eq 'source_deploy' "$(db_query_single "SELECT classification FROM events WHERE app = 'myapp' AND action = 'finish' LIMIT 1;")"
assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM pending_deploys WHERE app = 'myapp';")"

run_at '2026-04-08T20:05:00Z' "$REPO_ROOT/post-deploy" rebuildapp 5000 172.17.0.9 dokku/rebuildapp:latest
assert_status 0

assert_eq 'release_only' "$(db_query_single "SELECT classification FROM events WHERE app = 'rebuildapp' AND action = 'finish' LIMIT 1;")"
assert_eq '' "$(db_query_single "SELECT COALESCE(source_type, '') FROM events WHERE app = 'rebuildapp' AND action = 'finish' LIMIT 1;")"

setup_test_env deploy_classification_git_push_noise
run_at '2026-04-08T21:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_cmd env DOKKU_AUDIT_NOW='2026-04-08T21:00:01Z' SSH_USER=dokku SSH_NAME=admin "$REPO_ROOT/user-auth" dokku admin "git-receive-pack '/home/dokku/myapp.git'"
assert_status 0
run_cmd env DOKKU_AUDIT_NOW='2026-04-08T21:00:02Z' SSH_USER=dokku SSH_NAME=admin "$REPO_ROOT/user-auth" dokku admin "git-hook /home/dokku/myapp.git"
assert_status 0
run_at '2026-04-08T21:00:03Z' "$REPO_ROOT/post-config-update" myapp set GIT_REV=abcdef1234567890
assert_status 0
run_at '2026-04-08T21:00:04Z' "$REPO_ROOT/post-extract" myapp /tmp/work abcdef1234567890
assert_status 0
run_at '2026-04-08T21:00:05Z' "$REPO_ROOT/post-config-update" myapp set DOKKU_APP_TYPE=herokuish
assert_status 0
run_at '2026-04-08T21:00:06Z' "$REPO_ROOT/post-config-update" myapp set DOKKU_APP_RESTORE=1
assert_status 0
run_at '2026-04-08T21:00:07Z' "$REPO_ROOT/post-deploy" myapp 5000 172.17.0.8 dokku/myapp:latest
assert_status 0
run_at '2026-04-08T21:00:08Z' "$REPO_ROOT/deploy-source-set" myapp git-push branch=main
assert_status 0

assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM events WHERE classification = 'dokku_command';")"
assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM events WHERE category = 'config' AND app = 'myapp';")"
assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM events WHERE classification = 'source_extracted';")"
assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM events WHERE classification = 'deploy_source_metadata';")"
assert_eq 'source_deploy' "$(db_query_single "SELECT classification FROM events WHERE app = 'myapp' AND action = 'finish' LIMIT 1;")"
assert_eq 'git-push' "$(db_query_single "SELECT COALESCE(source_type, '') FROM events WHERE app = 'myapp' AND action = 'finish' LIMIT 1;")"
assert_eq 'admin' "$(db_query_single "SELECT actor_name FROM events WHERE app = 'myapp' AND action = 'finish' LIMIT 1;")"
assert_eq 'git:push' "$(db_query_single "SELECT json_extract(meta_json, '$.triggered_by_subcommand') FROM events WHERE app = 'myapp' AND action = 'finish' LIMIT 1;")"
assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM pending_deploys WHERE app = 'myapp';")"

run_cmd "$REPO_ROOT/subcommands/timeline" myapp
assert_status 0
assert_not_contains "$RUN_OUTPUT" 'git-receive-pack'
assert_not_contains "$RUN_OUTPUT" 'git-hook'
assert_not_contains "$RUN_OUTPUT" 'config keys set: GIT_REV'
assert_not_contains "$RUN_OUTPUT" 'config keys set: DOKKU_APP_TYPE'
assert_not_contains "$RUN_OUTPUT" 'config keys set: DOKKU_APP_RESTORE'
assert_not_contains "$RUN_OUTPUT" 'source extracted'
assert_not_contains "$RUN_OUTPUT" 'deploy source metadata recorded'
assert_contains "$RUN_OUTPUT" 'source deploy finished'
