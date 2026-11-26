#!/usr/bin/env bash
# @description Tests that the remote/ scripts source server config instead of
#              relying on the values that used to be hardcoded in each script.

# @description Verifies that a direct run falls back to remote/config and uses
#   its archive header and backup directory.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_config_repo_template_is_loaded() {
    local repo="$SCRATCH/repo-copy"
    local dir
    make_repo_copy "$repo"
    for dir in .config .local/share Hosting Scripts; do
        mkdir -p "$SCRATCH/home/$dir"
    done
    run_script_in "$repo" "$repo/remote/server-backup.sh" --dry-run
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/home/Sync/Nextcloud/Backup/Remote/sorkhackmac12-remote-backup-"
}

# @description Verifies that USER_SCRIPTS_CONFIG overrides the repository
#   template for a remote script.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_config_explicit_file_overrides_template() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    write_config "$SCRATCH/cfg" cfghdr
    USER_SCRIPTS_CONFIG="$SCRATCH/cfg" \
        run_script_in "$repo" "$repo/remote/server-backup.sh" --dry-run
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/cfghdr-"
}

# @description Verifies that the installed config is preferred over the
#   repository template on a deployed host.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_config_installed_beats_template() {
    local repo="$SCRATCH/repo-copy"
    local dir
    make_repo_copy "$repo"
    mkdir -p "$SCRATCH/xdg/user-scripts"
    write_config "$SCRATCH/xdg/user-scripts/config" installedhdr
    for dir in .config .local/share Hosting Scripts; do
        mkdir -p "$SCRATCH/home/$dir"
    done
    run_script_in "$repo" "$repo/remote/server-backup.sh" --dry-run
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/installedhdr-"
}

# @description Verifies that an explicitly requested unreadable config makes
#   server-backup.sh fail instead of silently using hardcoded values.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_config_server_backup_unreadable() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    USER_SCRIPTS_CONFIG="$SCRATCH/missing" \
        run_script_in "$repo" "$repo/remote/server-backup.sh" --dry-run
    assert_eq 1 "$SCRIPT_STATUS" "server-backup config error exit status"
}

# @description Verifies that the config error names the unreadable file.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_config_arch_maintenance_reports_error() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    USER_SCRIPTS_CONFIG="$SCRATCH/missing" \
        run_script_in "$repo" "$repo/remote/arch-server-maintenance.sh"
    assert_contains "$(stderr_text)" \
        "Error: Config file is not readable: $SCRATCH/missing"
}

# @description Verifies that the server maintenance script also stops on an
#   unreadable explicitly requested config.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_config_arch_maintenance_unreadable() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    USER_SCRIPTS_CONFIG="$SCRATCH/missing" \
        run_script_in "$repo" "$repo/remote/arch-server-maintenance.sh"
    assert_eq 1 "$SCRIPT_STATUS" "server maintenance config error exit status"
}

# @description Verifies that the remote Git checker loads its config before
#   scanning, rather than using a hardcoded search directory.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_config_git_checker_uses_config() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    cat > "$SCRATCH/gcfg" <<EOF
SEARCH_DIR="$SCRATCH/src"
IGNORE_DIRS=()
EOF
    USER_SCRIPTS_CONFIG="$SCRATCH/gcfg" \
        run_script_in "$repo" "$repo/remote/git-checker.sh"
    assert_contains "$(stdout_text)" "Repositories found: 0"
}

# @description Verifies that the remote Git checker rejects an unreadable
#   explicitly requested config.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_config_git_checker_unreadable() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    USER_SCRIPTS_CONFIG="$SCRATCH/missing" \
        run_script_in "$repo" "$repo/remote/git-checker.sh"
    assert_eq 1 "$SCRIPT_STATUS" "remote git-checker config error exit status"
}
