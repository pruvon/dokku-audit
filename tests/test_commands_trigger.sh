#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env commands_trigger

run_cmd "$REPO_ROOT/commands" help
assert_status 0
assert_contains "$RUN_OUTPUT" 'dokku audit:status'

run_cmd "$REPO_ROOT/commands" audit:help
assert_status 0
assert_contains "$RUN_OUTPUT" 'dokku audit:doctor'

run_cmd env DOKKU_NOT_IMPLEMENTED_EXIT=10 "$REPO_ROOT/commands" config yoklama
assert_status 10
assert_eq '' "$RUN_OUTPUT"
