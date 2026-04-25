# Changelog

## 0.1.0

- Initial Dokku community plugin implementation
- SQLite-backed event store with migrations
- Deploy classification into `source_deploy` and `release_only`
- CLI commands for status, doctor, query, export, backup, vacuum, and prune
- Trigger handlers for deploy, config, domains, ports, and app lifecycle events
- Shell integration test suite with deterministic fixtures

### Added (post-initial release)

- `user-auth` trigger integration for actor attribution and command audit
- `post-app-rename` trigger for app rename events
- `post-certs-update` and `post-certs-remove` triggers for certificate management
- `scheduler-enter`, `scheduler-run`, and `scheduler-post-run` triggers for runtime events
- `audit:search` command for free-text search across events
- `audit:get` and `audit:set` commands for runtime configuration management
- `bootstrap` path resolution infrastructure

### Fixed

- `scheduler-post-run`: Shell variable expansion risk in docker inspect JSON parsing fixed by using `docker inspect --format` direct field extraction
- `functions`: Removed unused `audit_attach_container_id_to_pending_run_event` dead code
- `README.md` and `audit_print_help`: Added missing `csv` format to `audit:export` documentation