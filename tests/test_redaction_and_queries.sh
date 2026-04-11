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
assert len(payload["events"]) == 6
PY

run_cmd "$REPO_ROOT/subcommands/export" audit:export --format json --app myapp
assert_status 0
assert_contains "$RUN_OUTPUT" '"plugin":"dokku-audit"'
assert_contains "$RUN_OUTPUT" '"events"'

export_path="$TEST_ROOT/export.jsonl"
run_cmd "$REPO_ROOT/subcommands/export" audit:export --output "$export_path"
assert_status 0
assert_eq '' "$RUN_OUTPUT"
[[ -f "$export_path" ]] || fail "export file was not created"
assert_contains "$(<"$export_path")" '"classification":"ports_change"'

run_cmd "$REPO_ROOT/subcommands/recent" --format jsonl --limit 2
assert_status 0
assert_contains "$RUN_OUTPUT" '"id":7'
assert_contains "$RUN_OUTPUT" '"id":6'

run_cmd "$REPO_ROOT/subcommands/recent" audit:recent
assert_status 0
assert_contains "$RUN_OUTPUT" 'config keys set: RAILS_ENV, SECRET_KEY_BASE'
assert_contains "$RUN_OUTPUT" 'domains add: example.com, www.example.com'

run_cmd "$REPO_ROOT/subcommands/show" audit:show 1 --format json
assert_status 0
assert_contains "$RUN_OUTPUT" '"id":1'
assert_contains "$RUN_OUTPUT" '"actor_label":"dokku-system"'

setup_test_env deploy_metadata_redaction
run_at '2026-04-08T22:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0
run_at '2026-04-08T22:00:01Z' "$REPO_ROOT/deploy-source-set" myapp git-push branch=main token=supersecret password=topsecret
assert_status 0
deploy_meta="$(db_query_single "SELECT metadata_json FROM pending_deploys WHERE app = 'myapp' LIMIT 1;")"
assert_contains "$deploy_meta" 'branch=main'
assert_contains "$deploy_meta" 'token=[REDACTED]'
assert_contains "$deploy_meta" 'password=[REDACTED]'
assert_not_contains "$deploy_meta" 'supersecret'
assert_not_contains "$deploy_meta" 'topsecret'

setup_test_env deploy_metadata_truncation
run_at '2026-04-08T22:10:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0
long_metadata="$(printf 'value=%.0s' $(seq 1 400))"
run_cmd env DOKKU_AUDIT_DEPLOY_METADATA_MAX_BYTES=64 DOKKU_AUDIT_NOW='2026-04-08T22:10:01Z' "$REPO_ROOT/deploy-source-set" myapp git-push "$long_metadata"
assert_status 0
deploy_meta="$(db_query_single "SELECT metadata_json FROM pending_deploys WHERE app = 'myapp' LIMIT 1;")"
assert_contains "$deploy_meta" 'deploy_metadata_truncated'

setup_test_env deploy_metadata_truncation_token_boundary
run_at '2026-04-08T22:20:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0
run_cmd env DOKKU_AUDIT_DEPLOY_METADATA_MAX_BYTES=20 DOKKU_AUDIT_NOW='2026-04-08T22:20:01Z' "$REPO_ROOT/deploy-source-set" myapp git-push 'branch=main commit=abcdef'
assert_status 0
deploy_meta="$(db_query_single "SELECT json_extract(metadata_json, '$.deploy_metadata_raw') FROM pending_deploys WHERE app = 'myapp' LIMIT 1;")"
assert_eq 'branch=main' "$deploy_meta"
