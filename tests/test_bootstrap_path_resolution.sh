#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env bootstrap_path_resolution

set +e
RUN_OUTPUT="$(PLUGIN_AVAILABLE_PATH="$TEST_ROOT/plugins/available" DOKKU_AUDIT_NOW='2026-04-08T20:00:00Z' "$REPO_ROOT/install" 2>&1)"
RUN_STATUS=$?
set -e

assert_status 0
assert_contains "$RUN_OUTPUT" 'dokku-audit: initialized '
assert_eq '1145132356' "$(db_query_single 'PRAGMA application_id;')"
assert_eq '5' "$(db_query_single 'PRAGMA user_version;')"

set +e
RUN_OUTPUT="$(PLUGIN_AVAILABLE_PATH="$TEST_ROOT/plugins/available" "$REPO_ROOT/subcommands/status" 2>&1)"
RUN_STATUS=$?
set -e

assert_status 0
assert_contains "$RUN_OUTPUT" 'schema version: 5'
