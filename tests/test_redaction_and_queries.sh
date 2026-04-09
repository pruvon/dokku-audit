#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env redaction_queries
seed_extended_app_flow

config_meta="$(db_query_single "SELECT meta_json FROM events WHERE category = 'config' LIMIT 1;")"
assert_contains "$config_meta" 'SECRET_KEY_BASE'
assert_not_contains "$config_meta" 'supersecret'

run_cmd "$REPO_ROOT/subcommands/last-deploys"
assert_status 0
assert_fixture_equals "$RUN_OUTPUT" "$REPO_ROOT/tests/fixtures/last-deploys.txt"

run_cmd "$REPO_ROOT/subcommands/last-deploys" audit:last-deploys
assert_status 0
assert_fixture_equals "$RUN_OUTPUT" "$REPO_ROOT/tests/fixtures/last-deploys.txt"

run_cmd "$REPO_ROOT/subcommands/last-deploys" audit:last-deploys --app myapp
assert_status 0
assert_fixture_equals "$RUN_OUTPUT" "$REPO_ROOT/tests/fixtures/last-deploys.txt"

run_cmd "$REPO_ROOT/subcommands/timeline" myapp
assert_status 0
assert_fixture_equals "$RUN_OUTPUT" "$REPO_ROOT/tests/fixtures/timeline.txt"

run_cmd "$REPO_ROOT/subcommands/timeline" audit:timeline
assert_status 1
assert_contains "$RUN_OUTPUT" 'usage: dokku audit:timeline <app> [options]'

run_cmd "$REPO_ROOT/subcommands/timeline" audit:timeline myapp
assert_status 0
assert_fixture_equals "$RUN_OUTPUT" "$REPO_ROOT/tests/fixtures/timeline.txt"

run_cmd "$REPO_ROOT/subcommands/export" --format json --app myapp
assert_status 0
assert_contains "$RUN_OUTPUT" '"plugin":"dokku-audit"'
assert_contains "$RUN_OUTPUT" '"events"'
python3 - <<'PY' "$RUN_OUTPUT"
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["plugin"] == "dokku-audit"
assert len(payload["events"]) == 7
PY

run_cmd "$REPO_ROOT/subcommands/export" audit:export --format json --app myapp
assert_status 0
assert_contains "$RUN_OUTPUT" '"plugin":"dokku-audit"'
assert_contains "$RUN_OUTPUT" '"events"'

run_cmd "$REPO_ROOT/subcommands/recent" --format jsonl --limit 2
assert_status 0
assert_contains "$RUN_OUTPUT" '"id":8'
assert_contains "$RUN_OUTPUT" '"id":7'

run_cmd "$REPO_ROOT/subcommands/recent" audit:recent
assert_status 0
assert_contains "$RUN_OUTPUT" 'config keys set: RAILS_ENV, SECRET_KEY_BASE'
assert_contains "$RUN_OUTPUT" 'domains add: example.com, www.example.com'

run_cmd "$REPO_ROOT/subcommands/show" audit:show 1 --format json
assert_status 0
assert_contains "$RUN_OUTPUT" '"id":1'
assert_contains "$RUN_OUTPUT" '"actor_label":"dokku-system"'
