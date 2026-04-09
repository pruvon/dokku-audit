#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env migrate_status

run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0
assert_eq 'schema version: 4' "$RUN_OUTPUT"
assert_eq '1145132356' "$(db_query_single 'PRAGMA application_id;')"
assert_eq '4' "$(db_query_single 'PRAGMA user_version;')"

run_cmd "$REPO_ROOT/subcommands/status"
assert_status 0
assert_fixture_equals "$RUN_OUTPUT" "$REPO_ROOT/tests/fixtures/status.txt"
