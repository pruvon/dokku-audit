#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env scheduler_post_run_basic
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_at '2026-04-08T20:01:00Z' "$REPO_ROOT/scheduler-run" docker myapp echo hello
assert_status 0

assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE app = 'myapp' AND category = 'command' AND action = 'run';")"

run_at '2026-04-08T20:01:05Z' "$REPO_ROOT/scheduler-post-run" docker myapp abcdef123456
assert_status 0

assert_eq 'abcdef123456' "$(db_query_single "SELECT json_extract(meta_json, '$.container_id') FROM events WHERE app = 'myapp' AND category = 'command' AND action = 'run' LIMIT 1;")"
assert_eq 'container_created' "$(db_query_single "SELECT json_extract(meta_json, '$.success_hint') FROM events WHERE app = 'myapp' AND category = 'command' AND action = 'run' LIMIT 1;")"

# If docker is unavailable, exit_code should not be present
if ! command -v docker >/dev/null 2>&1; then
  assert_eq '' "$(db_query_single "SELECT COALESCE(json_extract(meta_json, '$.exit_code'), '') FROM events WHERE app = 'myapp' AND category = 'command' AND action = 'run' LIMIT 1;")"
fi

# Verify pending_runtime_events is cleaned up
assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM pending_runtime_events WHERE app = 'myapp';")"
