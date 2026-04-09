#!/usr/bin/env bash
set -eo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers/testlib.sh"

ORIGINAL_PATH="$PATH"

install_fake_sshcommand() {
  local bin_dir="$TEST_ROOT/bin"

  mkdir -p "$bin_dir"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'set -eo pipefail'
    printf '%s\n' '[[ "${1:-}" == "list" ]] || exit 1'
    printf '%s\n' 'case "${3:-}" in'
    printf '%s\n' '  alice)'
    printf '%s\n' '    printf "SHA256:alice-key NAME=\"alice\" SSHCOMMAND_ALLOWED_KEYS=\"no-port-forwarding\"\\n"'
    printf '%s\n' '    ;;'
    printf '%s\n' '  default)'
    printf '%s\n' '    printf "SHA256:default-key NAME=\"default\" SSHCOMMAND_ALLOWED_KEYS=\"no-port-forwarding\"\\n"'
    printf '%s\n' '    ;;'
    printf '%s\n' 'esac'
  } > "$bin_dir/sshcommand"
  chmod +x "$bin_dir/sshcommand"
  PATH="$bin_dir:$ORIGINAL_PATH"
  export PATH
}

setup_test_env actor_propagation_source_deploy
install_fake_sshcommand
run_at '2026-04-08T21:00:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_cmd env DOKKU_AUDIT_NOW='2026-04-08T21:00:01Z' SSH_USER=dokku SSH_NAME=alice PATH="$PATH" "$REPO_ROOT/user-auth" dokku alice git:sync myapp
assert_status 0
run_at '2026-04-08T21:00:02Z' "$REPO_ROOT/receive-app" myapp abcdef1234567890
assert_status 0
run_at '2026-04-08T21:00:03Z' "$REPO_ROOT/deploy-source-set" myapp git-push branch=main
assert_status 0
run_at '2026-04-08T21:00:04Z' "$REPO_ROOT/post-extract" myapp /tmp/work abcdef1234567890
assert_status 0
run_at '2026-04-08T21:00:05Z' "$REPO_ROOT/post-deploy" myapp 5000 172.17.0.8 dokku/myapp:latest
assert_status 0

assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM events WHERE classification = 'dokku_command';")"
assert_eq '4' "$(db_query_single "SELECT COUNT(1) FROM events WHERE category = 'deploy' AND actor_name = 'alice';")"
assert_eq 'alice' "$(db_query_single "SELECT actor_name FROM events WHERE classification = 'source_received' LIMIT 1;")"
assert_eq 'alice' "$(db_query_single "SELECT actor_name FROM events WHERE classification = 'source_deploy' LIMIT 1;")"
assert_eq 'dokku' "$(db_query_single "SELECT json_extract(meta_json, '$.ssh_user') FROM events WHERE classification = 'source_deploy' LIMIT 1;")"
assert_eq 'alice' "$(db_query_single "SELECT json_extract(meta_json, '$.ssh_name') FROM events WHERE classification = 'source_deploy' LIMIT 1;")"
assert_eq 'SHA256:alice-key' "$(db_query_single "SELECT json_extract(meta_json, '$.ssh_key_fingerprint') FROM events WHERE classification = 'source_deploy' LIMIT 1;")"
assert_eq 'git:sync' "$(db_query_single "SELECT json_extract(meta_json, '$.triggered_by_subcommand') FROM events WHERE classification = 'source_deploy' LIMIT 1;")"
assert_eq 'dokku git:sync myapp' "$(db_query_single "SELECT json_extract(meta_json, '$.triggered_by_command') FROM events WHERE classification = 'source_deploy' LIMIT 1;")"

setup_test_env actor_propagation_config_and_release
install_fake_sshcommand
run_at '2026-04-08T21:10:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_cmd env DOKKU_AUDIT_NOW='2026-04-08T21:10:01Z' SSH_USER=dokku SSH_NAME=default PATH="$PATH" "$REPO_ROOT/user-auth" dokku default config:set myapp SECRET_KEY_BASE=supersecret
assert_status 0
run_at '2026-04-08T21:10:02Z' "$REPO_ROOT/post-config-update" myapp set SECRET_KEY_BASE=supersecret
assert_status 0
run_at '2026-04-08T21:10:03Z' "$REPO_ROOT/post-deploy" myapp 5000 172.17.0.9 dokku/myapp:latest
assert_status 0

assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM events WHERE classification = 'dokku_command';")"
assert_eq 'default' "$(db_query_single "SELECT actor_name FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'dokku' "$(db_query_single "SELECT json_extract(meta_json, '$.ssh_user') FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'default' "$(db_query_single "SELECT json_extract(meta_json, '$.ssh_name') FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'SHA256:default-key' "$(db_query_single "SELECT json_extract(meta_json, '$.ssh_key_fingerprint') FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'config:set' "$(db_query_single "SELECT json_extract(meta_json, '$.triggered_by_subcommand') FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'dokku config:set myapp SECRET_KEY_BASE=[REDACTED]' "$(db_query_single "SELECT json_extract(meta_json, '$.triggered_by_command') FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'default' "$(db_query_single "SELECT actor_name FROM events WHERE classification = 'release_only' LIMIT 1;")"
assert_eq 'config:set' "$(db_query_single "SELECT json_extract(meta_json, '$.triggered_by_subcommand') FROM events WHERE classification = 'release_only' LIMIT 1;")"

setup_test_env actor_propagation_app_lifecycle
install_fake_sshcommand
run_at '2026-04-08T21:20:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_cmd env DOKKU_AUDIT_NOW='2026-04-08T21:20:01Z' SSH_USER=dokku SSH_NAME=alice PATH="$PATH" "$REPO_ROOT/user-auth" dokku alice apps:create myapp
assert_status 0
run_at '2026-04-08T21:20:02Z' "$REPO_ROOT/app-create" myapp
assert_status 0
run_cmd env DOKKU_AUDIT_NOW='2026-04-08T21:20:03Z' SSH_USER=dokku SSH_NAME=alice PATH="$PATH" "$REPO_ROOT/user-auth" dokku alice apps:destroy myapp
assert_status 0
run_at '2026-04-08T21:20:04Z' "$REPO_ROOT/app-destroy" myapp
assert_status 0

assert_eq '0' "$(db_query_single "SELECT COUNT(1) FROM events WHERE classification = 'dokku_command';")"
assert_eq 'alice' "$(db_query_single "SELECT actor_name FROM events WHERE classification = 'app_create' LIMIT 1;")"
assert_eq 'apps:create' "$(db_query_single "SELECT json_extract(meta_json, '$.triggered_by_subcommand') FROM events WHERE classification = 'app_create' LIMIT 1;")"
assert_eq 'alice' "$(db_query_single "SELECT actor_name FROM events WHERE classification = 'app_destroy' LIMIT 1;")"
assert_eq 'apps:destroy' "$(db_query_single "SELECT json_extract(meta_json, '$.triggered_by_subcommand') FROM events WHERE classification = 'app_destroy' LIMIT 1;")"

setup_test_env actor_propagation_local_sudo_fallback
run_at '2026-04-08T21:30:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_cmd env DOKKU_AUDIT_NOW='2026-04-08T21:30:01Z' DOKKU_AUDIT_SUDO_USER=pruvon DOKKU_AUDIT_LOCAL_USER=root DOKKU_AUDIT_EFFECTIVE_USER=root "$REPO_ROOT/post-config-update" myapp set FOO=bar
assert_status 0

assert_eq 'pruvon' "$(db_query_single "SELECT actor_name FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'SUDO_USER' "$(db_query_single "SELECT json_extract(meta_json, '$.actor_source') FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'pruvon' "$(db_query_single "SELECT json_extract(meta_json, '$.sudo_user') FROM events WHERE classification = 'config_change' LIMIT 1;")"

setup_test_env actor_propagation_local_user_over_default_ssh_label
install_fake_sshcommand
run_at '2026-04-08T21:35:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_cmd env DOKKU_AUDIT_NOW='2026-04-08T21:35:01Z' DOKKU_AUDIT_LOCAL_USER=pruvon DOKKU_AUDIT_EFFECTIVE_USER=pruvon SSH_USER=dokku SSH_NAME=default PATH="$PATH" "$REPO_ROOT/user-auth" dokku default config:set myapp FOO=bar
assert_status 0
run_at '2026-04-08T21:35:02Z' "$REPO_ROOT/post-config-update" myapp set FOO=bar
assert_status 0

assert_eq 'pruvon' "$(db_query_single "SELECT actor_name FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'LOCAL_USER' "$(db_query_single "SELECT json_extract(meta_json, '$.actor_source') FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'pruvon' "$(db_query_single "SELECT json_extract(meta_json, '$.local_user') FROM events WHERE classification = 'config_change' LIMIT 1;")"
assert_eq 'default' "$(db_query_single "SELECT json_extract(meta_json, '$.ssh_name') FROM events WHERE classification = 'config_change' LIMIT 1;")"

run_cmd "$REPO_ROOT/subcommands/recent" --limit 1
assert_status 0
assert_contains "$RUN_OUTPUT" 'unix-user:pruvon'

setup_test_env actor_propagation_local_sudo_run
run_at '2026-04-08T21:40:00Z' "$REPO_ROOT/subcommands/migrate"
assert_status 0

run_cmd env DOKKU_AUDIT_NOW='2026-04-08T21:40:01Z' DOKKU_AUDIT_SUDO_USER=pruvon DOKKU_AUDIT_LOCAL_USER=root DOKKU_AUDIT_EFFECTIVE_USER=root "$REPO_ROOT/scheduler-run" docker-local myapp ls -lah
assert_status 0

assert_eq 'pruvon' "$(db_query_single "SELECT actor_name FROM events WHERE classification = 'dokku_run' LIMIT 1;")"
assert_eq 'SUDO_USER' "$(db_query_single "SELECT json_extract(meta_json, '$.actor_source') FROM events WHERE classification = 'dokku_run' LIMIT 1;")"
assert_eq 'pruvon' "$(db_query_single "SELECT json_extract(meta_json, '$.sudo_user') FROM events WHERE classification = 'dokku_run' LIMIT 1;")"
