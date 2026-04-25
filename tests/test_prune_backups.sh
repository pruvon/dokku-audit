#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env prune_backups
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

mkdir -p "$DOKKU_AUDIT_DATA_DIR/backups"
touch "$DOKKU_AUDIT_DATA_DIR/backups/audit-20260401-120000.db"
touch "$DOKKU_AUDIT_DATA_DIR/backups/audit-20260407-120000.db"
touch "$DOKKU_AUDIT_DATA_DIR/backups/audit-20260408-120000.db"

run_at '2026-04-08T20:01:00Z' "$REPO_ROOT/subcommands/prune-backups" --older-than 7 --yes
assert_status 0

assert_eq '1' "$(db_query_single "SELECT COUNT(1) FROM events WHERE category = 'maintenance' AND action = 'prune-backups';")"
assert_eq '1' "$(db_query_single "SELECT json_extract(meta_json, '$.deleted_count') FROM events WHERE category = 'maintenance' AND action = 'prune-backups' LIMIT 1;")"

[[ -f "$DOKKU_AUDIT_DATA_DIR/backups/audit-20260401-120000.db" ]] && fail "old backup should be deleted"
[[ -f "$DOKKU_AUDIT_DATA_DIR/backups/audit-20260407-120000.db" ]] || fail "recent backup should exist"
[[ -f "$DOKKU_AUDIT_DATA_DIR/backups/audit-20260408-120000.db" ]] || fail "today backup should exist"

setup_test_env prune_backups_empty
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_at '2026-04-08T20:01:00Z' "$REPO_ROOT/subcommands/prune-backups" --older-than 30 --yes
assert_status 0
assert_eq '0' "$(db_query_single "SELECT json_extract(meta_json, '$.deleted_count') FROM events WHERE category = 'maintenance' AND action = 'prune-backups' LIMIT 1;")"
