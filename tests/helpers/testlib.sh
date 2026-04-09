#!/usr/bin/env bash
set -eo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_TMP_BASE="$REPO_ROOT/tests/.tmp"
TEST_CORRELATION_ID="aud_1712606520000_deadbeef"

setup_test_env() {
  local name="$1"

  TEST_ROOT="$TEST_TMP_BASE/$name"
  rm -rf "$TEST_ROOT"
  mkdir -p "$TEST_ROOT/data"

  export PLUGIN_AVAILABLE_PATH="$REPO_ROOT"
  export DOKKU_AUDIT_DATA_DIR="$TEST_ROOT/data"
  unset DOKKU_AUDIT_NOW
  unset DOKKU_AUDIT_CORRELATION_ID
  unset DOKKU_AUDIT_EPOCH_MS
  unset DOKKU_AUDIT_RANDOM_HEX
  unset DOKKU_AUDIT_RUNTIME_USER
  unset DOKKU_AUDIT_RUNTIME_GROUP
}

setup_test_env_with_runtime_user() {
  local name="$1"
  local runtime_user="$2"
  local runtime_group="${3:-$runtime_user}"

  setup_test_env "$name"
  export DOKKU_AUDIT_RUNTIME_USER="$runtime_user"
  export DOKKU_AUDIT_RUNTIME_GROUP="$runtime_group"
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

run_cmd() {
  set +e
  RUN_OUTPUT="$("$@" 2>&1)"
  RUN_STATUS=$?
  set -e
}

run_at() {
  local timestamp="$1"
  shift

  set +e
  RUN_OUTPUT="$(DOKKU_AUDIT_NOW="$timestamp" "$@" 2>&1)"
  RUN_STATUS=$?
  set -e
}

run_at_with_corr() {
  local timestamp="$1"
  local correlation_id="$2"
  shift 2

  set +e
  RUN_OUTPUT="$(DOKKU_AUDIT_NOW="$timestamp" DOKKU_AUDIT_CORRELATION_ID="$correlation_id" "$@" 2>&1)"
  RUN_STATUS=$?
  set -e
}

assert_status() {
  local expected="$1"
  if [[ "$RUN_STATUS" != "$expected" ]]; then
    printf 'Unexpected status. expected=%s actual=%s\n' "$expected" "$RUN_STATUS" >&2
    printf '%s\n' "$RUN_OUTPUT" >&2
    fail "command exit status mismatch"
  fi
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  if [[ "$expected" != "$actual" ]]; then
    printf 'Expected: %s\nActual:   %s\n' "$expected" "$actual" >&2
    fail "values are not equal"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'Missing substring: %s\n' "$needle" >&2
    printf '%s\n' "$haystack" >&2
    fail "expected substring not found"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    printf 'Unexpected substring: %s\n' "$needle" >&2
    printf '%s\n' "$haystack" >&2
    fail "unexpected substring found"
  fi
}

db_path() {
  printf '%s\n' "$DOKKU_AUDIT_DATA_DIR/audit.db"
}

db_query_single() {
  sqlite3 "$(db_path)" "$1"
}

db_query_raw() {
  sqlite3 "$(db_path)" "$1"
}

render_fixture() {
  sed \
    -e "s|__DB_PATH__|$(db_path)|g" \
    -e "s|__CORRELATION_ID__|$TEST_CORRELATION_ID|g" \
    "$1"
}

assert_fixture_equals() {
  local actual="$1"
  local fixture_path="$2"
  local expected

  expected="$(render_fixture "$fixture_path")"
  if [[ "$actual" != "$expected" ]]; then
    diff -u <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") || true
    fail "fixture mismatch: $(basename "$fixture_path")"
  fi
}

seed_source_deploy_flow() {
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
}

seed_extended_app_flow() {
  seed_source_deploy_flow
  run_at '2026-04-08T20:05:00Z' "$REPO_ROOT/post-config-update" myapp set RAILS_ENV=production SECRET_KEY_BASE=supersecret
  assert_status 0
  run_at '2026-04-08T20:06:00Z' "$REPO_ROOT/post-domains-update" myapp add example.com www.example.com
  assert_status 0
  run_at '2026-04-08T20:07:00Z' "$REPO_ROOT/post-proxy-ports-update" myapp add http:80:5000
  assert_status 0
}
