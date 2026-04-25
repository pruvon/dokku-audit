#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env trigger_guard_strict_mode
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

# Test strict mode false (default): trigger failure should return 0
run_cmd env DOKKU_AUDIT_STRICT_MODE=false DOKKU_AUDIT_DB_PATH=/nonexistent "$REPO_ROOT/post-deploy" myapp 5000 172.17.0.8 dokku/myapp:latest
assert_status 0
assert_contains "$RUN_OUTPUT" 'warning: failed to record post-deploy'

# Test strict mode true: trigger failure should return non-zero
run_cmd env DOKKU_AUDIT_STRICT_MODE=true DOKKU_AUDIT_DB_PATH=/nonexistent "$REPO_ROOT/post-deploy" myapp 5000 172.17.0.8 dokku/myapp:latest
assert_status 1
assert_contains "$RUN_OUTPUT" 'warning: failed to record post-deploy'

# Test strict mode with invalid value defaults to false
run_cmd env DOKKU_AUDIT_STRICT_MODE=maybe DOKKU_AUDIT_DB_PATH=/nonexistent "$REPO_ROOT/post-deploy" myapp 5000 172.17.0.8 dokku/myapp:latest
assert_status 0
assert_contains "$RUN_OUTPUT" 'warning: failed to record post-deploy'

# Test that a successful trigger still returns 0 in strict mode
run_cmd env DOKKU_AUDIT_STRICT_MODE=true "$REPO_ROOT/post-deploy" myapp 5000 172.17.0.8 dokku/myapp:latest
assert_status 0
assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE app = 'myapp' AND action = 'finish';")"
