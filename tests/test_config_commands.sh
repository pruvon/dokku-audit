#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env config_commands

run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_cmd "$REPO_ROOT/subcommands/set" audit:set strict_mode true
assert_status 0
assert_eq 'strict_mode=true' "$RUN_OUTPUT"

run_cmd "$REPO_ROOT/subcommands/get" audit:get strict_mode
assert_status 0
assert_eq 'true' "$RUN_OUTPUT"

run_cmd "$REPO_ROOT/subcommands/set" audit:set deploy_metadata_max_bytes 2048
assert_status 0
assert_eq 'deploy_metadata_max_bytes=2048' "$RUN_OUTPUT"

run_cmd "$REPO_ROOT/subcommands/get" audit:get deploy_metadata_max_bytes
assert_status 0
assert_eq '2048' "$RUN_OUTPUT"

run_cmd "$REPO_ROOT/subcommands/get" audit:get nonexistent_key
assert_status 1
assert_contains "$RUN_OUTPUT" 'config key not set: nonexistent_key'

# Verify the value is actually used by the helper
assert_eq 'true' "$(bash -c "source $REPO_ROOT/bootstrap; audit_strict_mode")"
assert_eq '2048' "$(bash -c "source $REPO_ROOT/bootstrap; audit_deploy_metadata_max_bytes")"
