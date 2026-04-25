#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env search_and_metadata

run_at '2026-04-08T20:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_at '2026-04-08T20:01:00Z' "$REPO_ROOT/app-create" myapp
assert_status 0

run_at_with_corr '2026-04-08T20:02:00Z' "$TEST_CORRELATION_ID" "$REPO_ROOT/receive-app" myapp abcdef1234567890
assert_status 0

run_at_with_corr '2026-04-08T20:03:00Z' "$TEST_CORRELATION_ID" "$REPO_ROOT/deploy-source-set" myapp git-push branch=main
assert_status 0

run_at '2026-04-08T20:04:00Z' "$REPO_ROOT/post-deploy" myapp 5000 172.17.0.8 dokku/myapp:latest
assert_status 0

assert_eq '5000' "$(db_query_single "SELECT json_extract(meta_json, '$.internal_port') FROM events WHERE category = 'deploy' AND action = 'finish' LIMIT 1;")"
assert_eq '172.17.0.8' "$(db_query_single "SELECT json_extract(meta_json, '$.internal_ip_address') FROM events WHERE category = 'deploy' AND action = 'finish' LIMIT 1;")"

run_cmd "$REPO_ROOT/subcommands/search" audit:search --query "source deploy"
assert_status 0
assert_contains "$RUN_OUTPUT" 'myapp'

run_cmd "$REPO_ROOT/subcommands/search" audit:search --query "nonexistent" --quiet
assert_status 0
assert_eq '' "$RUN_OUTPUT"

run_cmd "$REPO_ROOT/subcommands/search" audit:search --query "172.17.0.8"
assert_status 0
assert_contains "$RUN_OUTPUT" 'myapp'

run_cmd "$REPO_ROOT/subcommands/search" audit:search --query "main" --app myapp
assert_status 0
assert_contains "$RUN_OUTPUT" 'myapp'

# secret redaction expanded keywords
assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM events WHERE meta_json LIKE '%supersecret%';")"
run_at '2026-04-08T20:05:00Z' "$REPO_ROOT/post-config-update" myapp set APIKEY=supersecret BEARER_TOKEN=supersecret SESSION_PASSPHRASE=supersecret
assert_status 0
assert_contains "$(db_query_single "SELECT meta_json FROM events WHERE category = 'config' AND action = 'set' LIMIT 1;")" 'APIKEY'
assert_contains "$(db_query_single "SELECT meta_json FROM events WHERE category = 'config' AND action = 'set' LIMIT 1;")" 'BEARER_TOKEN'
assert_contains "$(db_query_single "SELECT meta_json FROM events WHERE category = 'config' AND action = 'set' LIMIT 1;")" 'SESSION_PASSPHRASE'
assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM events WHERE meta_json LIKE '%supersecret%';")"
