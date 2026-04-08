#!/usr/bin/env bash
set -eo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
count=0
failed=0

for test_file in "$TEST_DIR"/test_*.sh; do
  count=$((count + 1))
  printf '==> %s\n' "$(basename "$test_file")"
  if "$test_file"; then
    printf 'ok - %s\n' "$(basename "$test_file")"
  else
    printf 'not ok - %s\n' "$(basename "$test_file")"
    failed=$((failed + 1))
  fi
done

printf '\n%d test file(s) run\n' "$count"
if [[ "$failed" -gt 0 ]]; then
  printf '%d test file(s) failed\n' "$failed"
  exit 1
fi

printf 'all tests passed\n'