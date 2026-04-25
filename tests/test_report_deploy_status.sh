#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env report_deploy_status_success
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/report-deploy-status" myapp success
assert_status 0
assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM events WHERE app = 'myapp';")"

setup_test_env report_deploy_status_failure
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/receive-app" myapp abcdef123456
assert_status 0
run_at '2026-04-08T20:00:01Z' "$REPO_ROOT/deploy-source-set" myapp git-push branch=main
assert_status 0

run_at '2026-04-08T20:00:05Z' "$REPO_ROOT/subcommands/report-deploy-status" myapp failure
assert_status 0

assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE app = 'myapp' AND action = 'finish' AND status = 'error';")"
assert_eq 'deploy_failed' "$(db_query_single "SELECT classification FROM events WHERE app = 'myapp' AND action = 'finish' AND status = 'error' LIMIT 1;")"
assert_eq 'failure' "$(db_query_single "SELECT json_extract(meta_json, '$.deploy_status') FROM events WHERE app = 'myapp' AND action = 'finish' AND status = 'error' LIMIT 1;")"
assert_eq 'git-push' "$(db_query_single "SELECT COALESCE(source_type, '') FROM events WHERE app = 'myapp' AND action = 'finish' AND status = 'error' LIMIT 1;")"
assert_eq 'abcdef123456' "$(db_query_single "SELECT COALESCE(rev, '') FROM events WHERE app = 'myapp' AND action = 'finish' AND status = 'error' LIMIT 1;")"
assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM pending_deploys WHERE app = 'myapp';")"
assert_contains "$(db_query_single "SELECT message FROM events WHERE app = 'myapp' AND action = 'finish' AND status = 'error' LIMIT 1;")" 'deploy failed: failure'

setup_test_env report_deploy_status_failure_no_pending
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/report-deploy-status" otherapp failure
assert_status 0
assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE app = 'otherapp' AND action = 'finish' AND status = 'error';")"
assert_eq '' "$(db_query_single "SELECT COALESCE(source_type, '') FROM events WHERE app = 'otherapp' AND action = 'finish' AND status = 'error' LIMIT 1;")"
assert_eq '' "$(db_query_single "SELECT COALESCE(rev, '') FROM events WHERE app = 'otherapp' AND action = 'finish' AND status = 'error' LIMIT 1;")"
