#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env install_permissions_uninstall

run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/install"
assert_status 0

run_cmd "$REPO_ROOT/uninstall" audit
assert_status 0
assert_contains "$RUN_OUTPUT" 'preserved database at '

run_cmd "$REPO_ROOT/uninstall" dokku-audit
assert_status 0
assert_contains "$RUN_OUTPUT" 'preserved database at '

run_cmd "$REPO_ROOT/uninstall" wrong-name
assert_status 1
assert_contains "$RUN_OUTPUT" "unexpected plugin name 'wrong-name'"

setup_test_env_with_runtime_user install_runtime_permissions root wheel

run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/install"
assert_status 0

assert_eq '770' "$(stat -f '%Lp' "$DOKKU_AUDIT_DATA_DIR")"
assert_eq '770' "$(stat -f '%Lp' "$DOKKU_AUDIT_DATA_DIR/backups")"
assert_eq '660' "$(stat -f '%Lp' "$(db_path)")"
