#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env dokku_version_metadata
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

# When DOKKU_AUDIT_DOKKU_VERSION is set, events should include it in meta_json
run_cmd env DOKKU_AUDIT_DOKKU_VERSION='0.35.0' "$REPO_ROOT/app-create" myapp
assert_status 0
assert_eq '0.35.0' "$(db_query_single "SELECT json_extract(meta_json, '$.dokku_version') FROM events WHERE app = 'myapp' LIMIT 1;")"

# When not set and dokku is unavailable, meta_json should not contain dokku_version
setup_test_env dokku_version_missing
run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0
run_at '2026-04-08T20:01:00Z' env PATH="/usr/bin:/bin" "$REPO_ROOT/app-create" otherapp
assert_status 0
assert_eq '' "$(db_query_single "SELECT COALESCE(json_extract(meta_json, '$.dokku_version'), '') FROM events WHERE app = 'otherapp' LIMIT 1;")"
