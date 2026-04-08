# AGENTS.md

## Repository Purpose

This repository contains `dokku-audit`, a Dokku community plugin that records selected operational events into a local SQLite database and exposes query and maintenance commands through the `dokku audit:*` CLI surface.

## Working Rules

- Keep shell scripts compatible with macOS Bash 3.2 and common Dokku host Bash environments.
- Use the existing shell header in executable scripts:

```bash
#!/usr/bin/env bash
set -eo pipefail
[[ $DOKKU_TRACE ]] && set -x
```

- Prefer updating shared logic in `functions` instead of duplicating SQL or formatting code in triggers and subcommands.
- Preserve the current best-effort failure posture for Dokku triggers: audit write failures should warn and not break app operations unless strict mode is explicitly enabled.
- Never store raw config values. Only config key names may be persisted.
- Keep timestamps in UTC ISO-8601 with a `Z` suffix.
- Keep deploy completion classification semantics stable: `source_deploy` and `release_only` must not be repurposed.

## Project Structure

- `functions`: shared shell helpers, DB access, migrations, output formatting
- top-level trigger files: Dokku hook handlers such as `receive-app`, `post-deploy`, `post-config-update`
- `subcommands/`: `dokku audit:*` command handlers
- `migrations/`: forward-only SQLite migrations
- `tests/`: shell-based deterministic test suite and golden fixtures

## Commands To Run

- Run all tests:

```bash
./tests/run.sh
```

- Syntax-check shell scripts:

```bash
bash -n functions commands dependencies install update uninstall report app-create app-destroy receive-app deploy-source-set post-extract post-deploy post-config-update post-domains-update post-proxy-ports-update subcommands/* tests/run.sh tests/test_*.sh tests/helpers/testlib.sh
```

## Testing Notes

- Tests use deterministic environment overrides such as `DOKKU_AUDIT_NOW` and `DOKKU_AUDIT_CORRELATION_ID`.
- Golden fixtures live under `tests/fixtures/`.
- If output formatting changes intentionally, update the relevant fixtures and rerun `./tests/run.sh`.

## Review Focus

When reviewing changes here, prioritize:

- SQLite transaction safety and lock cleanup
- Bash 3.2 compatibility
- Secret redaction guarantees
- Query output stability for table, JSON, and JSONL formats
- Migration forward-compatibility and `application_id` validation
