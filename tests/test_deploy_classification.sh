#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

setup_test_env deploy_classification
seed_source_deploy_flow

assert_eq 'source_deploy' "$(db_query_single "SELECT classification FROM events WHERE app = 'myapp' AND action = 'finish' LIMIT 1;")"
assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM pending_deploys WHERE app = 'myapp';")"

run_at '2026-04-08T20:05:00Z' "$REPO_ROOT/post-deploy" rebuildapp 5000 172.17.0.9 dokku/rebuildapp:latest
assert_status 0

assert_eq 'release_only' "$(db_query_single "SELECT classification FROM events WHERE app = 'rebuildapp' AND action = 'finish' LIMIT 1;")"
assert_eq '' "$(db_query_single "SELECT COALESCE(source_type, '') FROM events WHERE app = 'rebuildapp' AND action = 'finish' LIMIT 1;")"