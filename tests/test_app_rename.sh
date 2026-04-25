#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env app_rename

run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_at '2026-04-08T20:01:00Z' "$REPO_ROOT/app-create" oldapp
assert_status 0

run_at '2026-04-08T20:02:00Z' "$REPO_ROOT/post-app-rename" oldapp newapp
assert_status 0

assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE category = 'app' AND action = 'rename';")"
assert_eq 'newapp' "$(db_query_single "SELECT app FROM events WHERE category = 'app' AND action = 'rename' LIMIT 1;")"
assert_eq 'app renamed from oldapp to newapp' "$(db_query_single "SELECT message FROM events WHERE category = 'app' AND action = 'rename' LIMIT 1;")"
assert_eq 'oldapp' "$(db_query_single "SELECT json_extract(meta_json, '$.old_app') FROM events WHERE category = 'app' AND action = 'rename' LIMIT 1;")"
assert_eq 'newapp' "$(db_query_single "SELECT json_extract(meta_json, '$.new_app') FROM events WHERE category = 'app' AND action = 'rename' LIMIT 1;")"
