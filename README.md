# dokku-audit

`dokku-audit` is a Dokku community plugin that keeps a queryable history of deploys and operational changes on a Dokku host.

Use it when you want to answer questions like:

- Which app was deployed most recently?
- Was this a real source deploy or only a release/rebuild-style deploy?
- When did an app's config, domains, or ports change?
- What happened on a single app over time?

## Requirements

`dokku-audit` runs on the Dokku host itself.

- Dokku must already be installed.
- `sqlite3` is required.
- `flock` is recommended for migration locking. If it is missing, the plugin falls back to a directory-based lock.

## Install Dependencies

On Ubuntu/Debian-based Dokku hosts:

```bash
sudo apt-get update
sudo apt-get install -y sqlite3 util-linux
```

Notes:

- `sqlite3` is the hard dependency.
- `flock` is typically provided by `util-linux`.
- On many Dokku hosts `util-linux` is already installed, but installing it explicitly is harmless.

Quick verification:

```bash
command -v sqlite3
command -v flock
```

## Install Plugin

Install the plugin on the Dokku host:

```bash
dokku plugin:install https://github.com/pruvon/dokku-audit.git
```

After install, verify that everything is healthy:

```bash
dokku audit:status
dokku audit:doctor
```

The install process creates the plugin data directory and initializes the SQLite database automatically.

## Update Plugin

When you update the plugin, run:

```bash
dokku plugin:update audit
dokku audit:status
```

If you want to run migrations manually:

```bash
dokku audit:migrate
```

## Uninstall Plugin

Remove the plugin from Dokku:

```bash
sudo dokku plugin:uninstall audit
```

Important:

- Uninstall does not delete the audit database automatically.
- Audit data is intentionally preserved.
- Dokku installs this repository under the plugin name `audit`, so plugin lifecycle commands use `audit`.

If you also want to delete stored audit data, remove it manually:

```bash
sudo rm -rf /var/lib/dokku/data/dokku-audit
```

Only do that if you are sure you no longer need the audit history.

## Where Data Lives

Default paths:

- Data directory: `/var/lib/dokku/data/dokku-audit`
- Database: `/var/lib/dokku/data/dokku-audit/audit.db`
- Backups: `/var/lib/dokku/data/dokku-audit/backups`

## What The Plugin Records

- App create and destroy events
- Deploy flow events such as `receive-app`, `deploy-source-set`, `post-extract`, and `post-deploy`
- Config changes with value redaction
- Domain changes
- Port changes
- Maintenance events like migration, backup, vacuum, and prune

Deploy completion is classified as either `source_deploy` or `release_only`.

## Command Guide

- `dokku audit`: Shortcut for `dokku audit:status`.
- `dokku audit:status`: Shows whether the plugin is installed correctly and whether the database is reachable. Good first command after install.
- `dokku audit:doctor`: Runs deeper checks. Use this when `status` looks wrong or when you suspect DB/config problems.
- `dokku audit:migrate`: Applies unapplied schema migrations. Useful after updates or during troubleshooting.
- `dokku audit:last-deploys`: Shows the most recent completed deploy events. Good for answering “what deployed last?”.
- `dokku audit:timeline <app>`: Shows the event history for one app. Best command when debugging one app over time.
- `dokku audit:recent`: Shows recent events across all apps. Useful for host-wide change visibility.
- `dokku audit:show <event-id>`: Shows full details for one event. Use it after `last-deploys`, `timeline`, or `recent` when you need more context.
- `dokku audit:export`: Exports events as JSON or JSONL. Useful for archiving or external processing.
- `dokku audit:backup`: Creates a safe SQLite backup of the audit database. Recommended before major upgrades or cleanup.
- `dokku audit:vacuum`: Runs SQLite maintenance. Useful after heavy pruning or long-term use.
- `dokku audit:prune --older-than DAYS --yes`: Deletes old events intentionally. Use carefully; this is the cleanup command.

## Common Examples

Show recent deploys:

```bash
dokku audit:last-deploys
```

Show recent deploys for one app:

```bash
dokku audit:last-deploys --app myapp
```

Show one app timeline:

```bash
dokku audit:timeline myapp
```

Show recent config-related changes across the host:

```bash
dokku audit:recent --category config
```

Inspect one event in detail:

```bash
dokku audit:show 42
```

Export one app's events as JSON:

```bash
dokku audit:export --app myapp --format json --output /tmp/myapp-audit.json
```

Create a backup:

```bash
dokku audit:backup
```

Prune old maintenance events:

```bash
dokku audit:prune --older-than 180 --category maintenance --yes
```

## Output Formats

Query commands support:

- table output by default
- `--format json`
- `--format jsonl`

Examples:

```bash
dokku audit:last-deploys --format json
dokku audit:recent --format jsonl
dokku audit:timeline myapp --format json
```

## Security Notes

- Config values are never stored from `post-config-update`.
- Only config key names are recorded.
- Audit failures are best-effort by default and should not break successful Dokku app operations.
- The database is intended to remain host-local.

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

## Development

Run the shell test suite:

```bash
./tests/run.sh
```
