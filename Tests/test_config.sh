#!/usr/bin/env bash
# Config-resolution tests: environment, CLI, and installed/legacy/repo fallback.

# Fixtures use self-describing names so a failure shows which config path or
# default header won. Paths are relative to the per-test $SCRATCH directory.
ENV_CONFIG_PATH=env-config
CLI_CONFIG_PATH=cli-config
INSTALLED_CONFIG_PATH=installed-config
LEGACY_CONFIG_PATH=legacy-config
UNREADABLE_CONFIG_PATH=unreadable-config

ENV_CONFIG_HEADER=env-config-header
CLI_CONFIG_HEADER=cli-config-header
ENV_OVERRIDE_HEADER=env-override-header
INSTALLED_CONFIG_HEADER=installed-config-header
LEGACY_CONFIG_HEADER=legacy-config-header
REPO_CONFIG_HEADER=repo-config-header

# @description Verifies that an environment value takes precedence over the
#   config file's default archive header, as the config template promises.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_config_env_overrides_file() {
    write_config "$SCRATCH/$ENV_CONFIG_PATH" "$ENV_CONFIG_HEADER"
    ARCHIVE_HEADER="$ENV_OVERRIDE_HEADER" \
        run_script backup.sh --dry-run -c "$SCRATCH/$ENV_CONFIG_PATH"
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/$ENV_OVERRIDE_HEADER-"
}

# @description Verifies that the -c path wins over USER_SCRIPTS_CONFIG when
#   deciding which config file to load.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_config_cli_beats_env_config_path() {
    write_config "$SCRATCH/$ENV_CONFIG_PATH" "$ENV_CONFIG_HEADER"
    write_config "$SCRATCH/$CLI_CONFIG_PATH" "$CLI_CONFIG_HEADER"
    USER_SCRIPTS_CONFIG="$SCRATCH/$ENV_CONFIG_PATH" \
        run_script backup.sh --dry-run -c "$SCRATCH/$CLI_CONFIG_PATH"
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/$CLI_CONFIG_HEADER-"
}

# @description Verifies the long --config-file form when the path is passed as
#   a separate argument.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_config_long_option_with_separate_value() {
    write_config "$SCRATCH/$CLI_CONFIG_PATH" "$CLI_CONFIG_HEADER"
    run_script backup.sh --dry-run --config-file "$SCRATCH/$CLI_CONFIG_PATH"
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/$CLI_CONFIG_HEADER-"
}

# @description Verifies the --config-file=PATH form so both documented long
#   option spellings stay supported.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_config_long_option_with_equals() {
    write_config "$SCRATCH/$CLI_CONFIG_PATH" "$CLI_CONFIG_HEADER"
    run_script backup.sh --dry-run "--config-file=$SCRATCH/$CLI_CONFIG_PATH"
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/$CLI_CONFIG_HEADER-"
}

# @description Verifies that an installed config in XDG_CONFIG_HOME is chosen
#   over a legacy config.conf in the same directory.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_config_installed_beats_legacy() {
    mkdir -p "$SCRATCH/xdg/user-scripts"
    write_config "$SCRATCH/xdg/user-scripts/config" "$INSTALLED_CONFIG_HEADER"
    write_config "$SCRATCH/xdg/user-scripts/config.conf" "$LEGACY_CONFIG_HEADER"
    run_script backup.sh --dry-run
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/$INSTALLED_CONFIG_HEADER-"
}

# @description Verifies that a legacy config.conf is still loaded when no
#   installed config exists, so older installs keep working after an upgrade.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_config_legacy_fallback() {
    mkdir -p "$SCRATCH/xdg/user-scripts"
    write_config "$SCRATCH/xdg/user-scripts/config.conf" "$LEGACY_CONFIG_HEADER"
    run_script backup.sh --dry-run
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/$LEGACY_CONFIG_HEADER-"
}

# @description Verifies the last-resort fallback to the repository's config
#   when no installed or legacy config is readable. A scratch repo copy holds a
#   controlled config so the test does not depend on personal backup paths.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_config_repo_template_fallback() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    # Replace the copied template so every expected value comes from this test.
    write_config "$repo/config" "$REPO_CONFIG_HEADER"
    run_script_in "$repo" "$repo/backup.sh" --dry-run
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/$REPO_CONFIG_HEADER-"
}

# @description Verifies that naming an unreadable config file makes backup.sh
#   stop with exit status 1 rather than continuing with partial settings.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_config_unreadable_file_exits_one() {
    run_script backup.sh --dry-run -c "$SCRATCH/$UNREADABLE_CONFIG_PATH"
    assert_eq 1 "$SCRIPT_STATUS" "unreadable config exit status"
}

# @description Verifies that the unreadable-config failure names the offending
#   path on stderr, so a user can tell which file to fix.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_config_unreadable_file_reports_error() {
    run_script backup.sh --dry-run -c "$SCRATCH/$UNREADABLE_CONFIG_PATH"
    assert_contains "$(stderr_text)" \
        "Error: Config file is not readable: $SCRATCH/$UNREADABLE_CONFIG_PATH"
}

# @description Verifies that -c without a value is a usage error (status 2),
#   distinct from the status 1 used for an unreadable file.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_config_missing_short_value_exits_two() {
    run_script backup.sh -c
    assert_eq 2 "$SCRIPT_STATUS" "missing -c value exit status"
}

# @description Verifies that an empty --config-file= value is rejected with a
#   specific message instead of silently falling back to another config.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_config_missing_long_value_reports_error() {
    run_script backup.sh --config-file=
    assert_contains "$(stderr_text)" \
        "Error: --config-file requires a config file."
}

# @description Verifies that options following -c still reach the normal
#   parser. backup.sh strips config arguments first and restores the rest of
#   the argument list, so ordering must not drop --dry-run.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_config_options_after_config_file() {
    write_config "$SCRATCH/$CLI_CONFIG_PATH" "$CLI_CONFIG_HEADER"
    run_script backup.sh -c "$SCRATCH/$CLI_CONFIG_PATH" --dry-run
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/$CLI_CONFIG_HEADER-"
}

# @description Verifies that maintenance-reminder.sh shares the same config
#   loader and error contract as backup.sh.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_config_shared_by_reminder() {
    run_script maintenance-reminder.sh -c "$SCRATCH/$UNREADABLE_CONFIG_PATH"
    assert_contains "$(stderr_text)" \
        "Error: Config file is not readable:"
}

# @description Verifies that git-checker.sh shares the same config loader and
#   error contract as backup.sh.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_config_shared_by_git_checker() {
    run_script git-checker.sh -c "$SCRATCH/$UNREADABLE_CONFIG_PATH"
    assert_contains "$(stderr_text)" \
        "Error: Config file is not readable:"
}

# @description Verifies that arch-maintenance.sh shares the same config loader
#   and error contract as backup.sh.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_config_shared_by_arch_maintenance() {
    run_script arch-maintenance.sh -c "$SCRATCH/$UNREADABLE_CONFIG_PATH"
    assert_contains "$(stderr_text)" \
        "Error: Config file is not readable:"
}
