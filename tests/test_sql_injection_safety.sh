#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env sql_injection_safety
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

# Single quote in app name (classic SQL injection pattern)
run_at '2026-04-08T20:01:00Z' "$REPO_ROOT/app-create" "app'or'1'='1"
assert_status 0
assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE app = 'app''or''1''=''1';")"

# Semicolon and comment in app name
run_at '2026-04-08T20:02:00Z' "$REPO_ROOT/app-create" "app; DROP TABLE events; --"
assert_status 0
assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE app = 'app; DROP TABLE events; --';")"

# Verify events table still exists and has expected rows (migrate + 2 app-create)
assert_eq '3' "$(db_query_single "SELECT COUNT(1) FROM events;")"

# Union-based injection attempt in app name via config
run_at '2026-04-08T20:03:00Z' "$REPO_ROOT/post-config-update" "myapp' UNION SELECT * FROM meta --" set "KEY=VALUE"
assert_status 0

# The app name with quote should be safely escaped and stored exactly as provided
assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE app = 'myapp'' UNION SELECT * FROM meta --';")"

# Verify meta table is intact
assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM meta WHERE key = 'plugin_version';")"
