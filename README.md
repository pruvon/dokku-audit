# dokku-audit

`dokku-audit` is a Dokku community plugin that keeps a queryable history of deploys and operational changes on a Dokku host.

Use it when you want to answer questions like:

- Which app was deployed most recently?
- Was this a real source deploy or only a release/rebuild-style deploy?
- When did an app's config, domains, or ports change?
- Who invoked `dokku run` or `dokku enter` for an app?
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
- Selected Dokku command invocations recorded through `user-auth`, with actor attribution, target app extraction for supported app-scoped commands, `SSH_USER`/`SSH_NAME` capture, best-effort SSH key fingerprint lookup, noisy read-only polling/report commands skipped, and commands with richer structured follow-on events represented by those follow-on events instead of a duplicate `dokku_command` row
- Deploy flow events such as `receive-app`, `deploy-source-set`, `post-extract`, and `post-deploy`
- Structured `dokku run` and `dokku enter` events, including actor and target container/process context when Dokku exposes it
- Follow-on app events inherit the triggering actor and Dokku command when the preceding command can be matched confidently
- Config changes with value redaction
- Domain changes
- Port changes
- Maintenance events like migration, backup, vacuum, and prune

Deploy completion is classified as either `source_deploy` or `release_only`.

- `source_deploy`: `post-deploy` happened with preceding source intake/build context. In practice this usually covers real source-backed deploy flows such as `git push`, `git:sync`, archive/image source imports, and `dokku ps:rebuild`.
- `release_only`: `post-deploy` happened without preceding source intake/build context. In practice this usually covers restart or release-style flows that reuse the existing built image, such as `dokku ps:restart`, plus config-driven restart/redeploy flows.

## Command Guide

- `dokku audit`: Shortcut for `dokku audit:status`.
- `dokku audit:status`: Shows whether the plugin is installed correctly and whether the database is reachable. Good first command after install.
- `dokku audit:doctor`: Runs deeper checks. Use this when `status` looks wrong or when you suspect DB/config problems.
- `dokku audit:migrate [--dry-run] [--verbose]`: Applies unapplied schema migrations. Use `--dry-run` to preview changes and `--verbose` for more detail.
- `dokku audit:last-deploys [--limit N] [--app APP] [--classification VALUE] [--format table|json|jsonl] [--quiet]`: Shows the most recent completed deploy events. Use `--app APP` to scope to one app, `--classification source_deploy` or `--classification release_only` to focus on one deploy class, and `--format` for machine-readable output.
- `dokku audit:timeline <app> [--limit N] [--since ISO8601] [--until ISO8601] [--category VALUE] [--format table|json|jsonl] [--quiet]`: Shows the event history for one app. Use `--format` to switch output style.
- `dokku audit:recent [--limit N] [--category VALUE] [--classification VALUE] [--status VALUE] [--since ISO8601] [--format table|json|jsonl] [--quiet]`: Shows recent events across all apps. In table output, actor labels are normalized as `ssh-key:<label>`, `ssh-user:<user>`, `sudo-user:<user>`, `unix-user:<user>`, or `dokku-system`. Use `--format` for JSON or JSONL output.
- `dokku audit:show <event-id> [--format table|json]`: Shows full details for one event. Use it after `last-deploys`, `timeline`, or `recent` when you need more context.
- `dokku audit:export [--format jsonl|json] [--app APP] [--since ISO8601] [--until ISO8601] [--output PATH]`: Exports events as JSON or JSONL. Use `--app` to scope to one app, `--since` / `--until` to bound the time range, and `--output` to write to a file.
- `dokku audit:backup [--output PATH]`: Creates a safe SQLite backup of the audit database. Recommended before major upgrades or cleanup.
- `dokku audit:vacuum`: Runs SQLite maintenance. Useful after heavy pruning or long-term use.
- `dokku audit:prune --older-than DAYS [--category VALUE] [--classification VALUE] [--yes]`: Deletes old events intentionally. Use carefully; this is the cleanup command.

## Common Examples

Show recent deploys:

```bash
dokku audit:last-deploys
```

Show recent deploys for one app:

```bash
dokku audit:last-deploys --app myapp
```

Show only source-backed deploys such as `git push` or `dokku ps:rebuild`:

```bash
dokku audit:last-deploys --classification source_deploy
```

Show only restart or release-style deploys such as `dokku ps:restart`:

```bash
dokku audit:last-deploys --classification release_only
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
- General command audit redacts `config:set` values and `dokku run --env` values before storing command metadata.
- Internal follow-on events store the sanitized triggering Dokku command when actor propagation is possible.
- If you see `ssh-key:default`, `default` is the Dokku `SSH_NAME` label attached to the matching key, not a Unix username.
- If a Dokku command is run locally via `sudo`, follow-on events and maintenance events can attribute it as `sudo-user:<user>` from `SUDO_USER`.
- If a command runs locally without SSH and without `sudo`, top-level maintenance commands can fall back to `unix-user:<user>` from the local process environment or process tree.
- When Dokku exposes only the low-signal fallback label `SSH_NAME=default`, a meaningful local Unix user discovered from the process environment or process tree can be preferred for display and actor attribution while the original SSH metadata is still kept in JSON.
- `dokku-system` means Dokku triggered the event internally and no user/key identity was available at that trigger point.
- `user-auth` command audit keeps actor attribution for meaningful commands but skips noisy read-only commands such as `audit:*`, `logs`, `config`, `*:list`, `*:links`, `*:app-links`, `*:report`, `*:info`, `*:show`, `*:exists`, `--version`, and `ps:retire`.
- Audit failures are best-effort by default and should not break successful Dokku app operations.
- The database is intended to remain host-local.
- Direct `docker exec` access bypasses Dokku triggers, so it is not visible to this plugin.

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
