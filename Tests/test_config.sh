#!/usr/bin/env bash
# Config-resolution tests: environment, CLI, and installed/legacy/repo fallback.

# AI-generated code (unreviewed by a human)
test_config_env_overrides_file() {
    write_config "$SCRATCH/cfg-A" A
    ARCHIVE_HEADER=envhdr \
        run_script backup.sh --dry-run -c "$SCRATCH/cfg-A"
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/envhdr-"
}

# AI-generated code (unreviewed by a human)
test_config_cli_beats_env_config_path() {
    write_config "$SCRATCH/cfg-A" A
    write_config "$SCRATCH/cfg-B" B
    USER_SCRIPTS_CONFIG="$SCRATCH/cfg-A" \
        run_script backup.sh --dry-run -c "$SCRATCH/cfg-B"
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/B-"
}

# AI-generated code (unreviewed by a human)
test_config_long_option_with_separate_value() {
    write_config "$SCRATCH/cfg-B" B
    run_script backup.sh --dry-run --config-file "$SCRATCH/cfg-B"
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/B-"
}

# AI-generated code (unreviewed by a human)
test_config_long_option_with_equals() {
    write_config "$SCRATCH/cfg-B" B
    run_script backup.sh --dry-run "--config-file=$SCRATCH/cfg-B"
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/B-"
}

# AI-generated code (unreviewed by a human)
test_config_installed_beats_legacy() {
    mkdir -p "$SCRATCH/xdg/user-scripts"
    write_config "$SCRATCH/xdg/user-scripts/config" installed
    write_config "$SCRATCH/xdg/user-scripts/config.conf" legacy
    run_script backup.sh --dry-run
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/installed-"
}

# AI-generated code (unreviewed by a human)
test_config_legacy_fallback() {
    mkdir -p "$SCRATCH/xdg/user-scripts"
    write_config "$SCRATCH/xdg/user-scripts/config.conf" legacy
    run_script backup.sh --dry-run
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/legacy-"
}

# AI-generated code (unreviewed by a human)
test_config_repo_template_fallback() {
    local dir
    for dir in .config .local/share .minetest Code Documents \
        Pictures Scripts Suckless; do
        mkdir -p "$SCRATCH/home/$dir"
    done
    run_script backup.sh --dry-run
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/home/Nextcloud/Backup/Local/sorkhackmac16-backup-"
}

# AI-generated code (unreviewed by a human)
test_config_unreadable_file_exits_one() {
    run_script backup.sh --dry-run -c "$SCRATCH/missing"
    assert_eq 1 "$SCRIPT_STATUS" "unreadable config exit status"
}

# AI-generated code (unreviewed by a human)
test_config_unreadable_file_reports_error() {
    run_script backup.sh --dry-run -c "$SCRATCH/missing"
    assert_contains "$(stderr_text)" \
        "Error: Config file is not readable: $SCRATCH/missing"
}

# AI-generated code (unreviewed by a human)
test_config_missing_short_value_exits_two() {
    run_script backup.sh -c
    assert_eq 2 "$SCRIPT_STATUS" "missing -c value exit status"
}

# AI-generated code (unreviewed by a human)
test_config_missing_long_value_reports_error() {
    run_script backup.sh --config-file=
    assert_contains "$(stderr_text)" \
        "Error: --config-file requires a config file."
}

# AI-generated code (unreviewed by a human)
test_config_options_after_config_file() {
    write_config "$SCRATCH/cfg-B" B
    run_script backup.sh -c "$SCRATCH/cfg-B" --dry-run
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/B-"
}

# AI-generated code (unreviewed by a human)
test_config_shared_by_reminder() {
    run_script maintenance-reminder.sh -c "$SCRATCH/missing"
    assert_contains "$(stderr_text)" \
        "Error: Config file is not readable:"
}

# AI-generated code (unreviewed by a human)
test_config_shared_by_git_checker() {
    run_script git-checker.sh -c "$SCRATCH/missing"
    assert_contains "$(stderr_text)" \
        "Error: Config file is not readable:"
}

# AI-generated code (unreviewed by a human)
test_config_shared_by_arch_maintenance() {
    run_script arch-maintenance.sh -c "$SCRATCH/missing"
    assert_contains "$(stderr_text)" \
        "Error: Config file is not readable:"
}
