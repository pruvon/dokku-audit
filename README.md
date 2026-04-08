# dokku-audit

Durable operational audit history for Dokku.

`dokku-audit` is a Dokku community plugin that records selected high-value operational events into a local SQLite database and exposes that history through first-class CLI commands.

## What It Captures

- App lifecycle events: `app-create`, `app-destroy`
- Deploy flow stages: `receive-app`, `deploy-source-set`, `post-extract`, `post-deploy`
- Configuration changes with mandatory secret redaction
- Domain changes
- Port changes
- Plugin maintenance operations such as migration, backup, vacuum, and prune

Deploy completion is classified as either `source_deploy` or `release_only`.

## Storage

Default paths:

- Data directory: `/var/lib/dokku/data/dokku-audit`
- Database: `/var/lib/dokku/data/dokku-audit/audit.db`
- Backups: `/var/lib/dokku/data/dokku-audit/backups`
- Migration lock: `/var/lib/dokku/data/dokku-audit/migrate.lock`

The database uses:

- `PRAGMA application_id = 1145132356`
- `PRAGMA user_version` for schema versioning
- `WAL` journal mode when SQLite can enable it
- `busy_timeout = 5000`
- `foreign_keys = ON`

## Commands

```text
dokku audit
dokku audit:help
dokku audit:status
dokku audit:doctor
dokku audit:migrate [--dry-run] [--verbose]
dokku audit:last-deploys [--limit N] [--app APP] [--classification VALUE] [--format table|json|jsonl] [--quiet]
dokku audit:timeline <app> [--limit N] [--since ISO8601] [--until ISO8601] [--category VALUE] [--format table|json|jsonl] [--quiet]
dokku audit:recent [--limit N] [--category VALUE] [--classification VALUE] [--status VALUE] [--since ISO8601] [--format table|json|jsonl] [--quiet]
dokku audit:show <event-id> [--format table|json]
dokku audit:export [--format jsonl|json] [--app APP] [--since ISO8601] [--until ISO8601] [--output PATH]
dokku audit:backup [--output PATH]
dokku audit:vacuum
dokku audit:prune --older-than DAYS [--category VALUE] [--classification VALUE] [--yes]
```

## Install

On a Dokku host:

```bash
dokku plugin:install https://github.com/<your-org>/dokku-audit.git
```

The plugin verifies `sqlite3` during install. It prefers `flock` for migration locking, but falls back to a directory lock if `flock` is unavailable.

## Output Formats

Query commands support table output by default and JSON or JSONL where appropriate.

Examples:

```bash
dokku audit:last-deploys
dokku audit:last-deploys --app myapp --format json
dokku audit:timeline myapp --since 2026-04-08T00:00:00Z
dokku audit:recent --category config --format jsonl
dokku audit:show 42
dokku audit:export --app myapp --format json --output /tmp/myapp-audit.json
```

## Security

- Config values are never stored from `post-config-update`.
- Only config key names are recorded.
- The database is intended to remain host-local.
- Recommended file modes are `0750` for directories and `0640` for database and backup files.

## Backup and Restore

Create a backup:

```bash
dokku audit:backup
```

Restore manually:

1. Stop concurrent writes if possible.
2. Replace the database file with a backup copy.
3. Re-apply expected permissions.
4. Run `dokku audit:doctor`.

## Environment Overrides

These environment variables are supported:

- `DOKKU_AUDIT_DATA_DIR`
- `DOKKU_AUDIT_DB_PATH`
- `DOKKU_AUDIT_BACKUP_DIR`
- `DOKKU_AUDIT_LOCK_FILE`
- `DOKKU_AUDIT_BUSY_TIMEOUT_MS`
- `DOKKU_AUDIT_JOURNAL_MODE`
- `DOKKU_AUDIT_STRICT_MODE`
- `DOKKU_AUDIT_PENDING_STALE_THRESHOLD_SECONDS`

Testing-only deterministic overrides:

- `DOKKU_AUDIT_NOW`
- `DOKKU_AUDIT_CORRELATION_ID`
- `DOKKU_AUDIT_EPOCH_MS`
- `DOKKU_AUDIT_RANDOM_HEX`

## Development

Run the shell test suite:

```bash
./tests/run.sh
```

The suite covers:

- migration and status output
- deploy classification (`source_deploy`, `release_only`)
- config redaction
- CLI golden outputs for status, last-deploys, and timeline
- backup and doctor behaviors

## Repository Layout

```text
.
├── app-create
├── app-destroy
├── commands
├── dependencies
├── deploy-source-set
├── functions
├── install
├── migrations/
├── post-config-update
├── post-deploy
├── post-domains-update
├── post-extract
├── post-proxy-ports-update
├── receive-app
├── report
├── subcommands/
├── tests/
├── uninstall
└── update
```