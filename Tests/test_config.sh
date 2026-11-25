#!/usr/bin/env bash
# Config-resolution tests: environment, CLI, and installed/legacy/repo fallback.

# @description Verifies that an environment value takes precedence over the
#   config file's default archive header, as the config template promises.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_config_env_overrides_file() {
    write_config "$SCRATCH/env-config" default-header
    ARCHIVE_HEADER=expected-env-header \
        run_script backup.sh --dry-run -c "$SCRATCH/env-config"
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/expected-env-header-"
}

# @description Verifies that the -c path wins over USER_SCRIPTS_CONFIG when
#   deciding which config file to load.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_config_cli_beats_env_config_path() {
    write_config "$SCRATCH/env-config" default-header
    write_config "$SCRATCH/cli-config" expected-cli-header
    USER_SCRIPTS_CONFIG="$SCRATCH/env-config" \
        run_script backup.sh --dry-run -c "$SCRATCH/cli-config"
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/expected-cli-header-"
}

# @description Verifies the long --config-file form when the path is passed as
#   a separate argument.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_config_long_option_with_separate_value() {
    write_config "$SCRATCH/cli-config" expected-cli-header
    run_script backup.sh --dry-run --config-file "$SCRATCH/cli-config"
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/expected-cli-header-"
}

# @description Verifies the --config-file=PATH form so both documented long
#   option spellings stay supported.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_config_long_option_with_equals() {
    write_config "$SCRATCH/cli-config" expected-cli-header
    run_script backup.sh --dry-run "--config-file=$SCRATCH/cli-config"
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/expected-cli-header-"
}

# @description Verifies that an installed config in XDG_CONFIG_HOME is chosen
#   over a legacy config.conf in the same directory.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_config_installed_beats_legacy() {
    mkdir -p "$SCRATCH/xdg/user-scripts"
    write_config "$SCRATCH/xdg/user-scripts/config" expected-installed-header
    write_config "$SCRATCH/xdg/user-scripts/config.conf" legacy-header
    run_script backup.sh --dry-run
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/expected-installed-header-"
}

# @description Verifies that a legacy config.conf is still loaded when no
#   installed config exists, so older installs keep working after an upgrade.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_config_legacy_fallback() {
    mkdir -p "$SCRATCH/xdg/user-scripts"
    write_config "$SCRATCH/xdg/user-scripts/config.conf" expected-legacy-header
    run_script backup.sh --dry-run
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/expected-legacy-header-"
}

# @description Verifies the last-resort fallback to the repository's config
#   template when no installed or legacy config is readable. A scratch repo copy
#   holds a controlled config so the asserted header is not a personal value.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_config_repo_template_fallback() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    # Replace the copied template so every expected value comes from this test.
    write_config "$repo/config" expected-template-header
    run_script_in "$repo" "$repo/backup.sh" --dry-run
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/expected-template-header-"
}

# @description Verifies that naming an unreadable config file makes backup.sh
#   stop with exit status 1 rather than continuing with partial settings.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_config_unreadable_file_exits_one() {
    run_script backup.sh --dry-run -c "$SCRATCH/missing-config"
    assert_eq 1 "$SCRIPT_STATUS" "unreadable config exit status"
}

# @description Verifies that the unreadable-config failure names the offending
#   path on stderr, so a user can tell which file to fix.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_config_unreadable_file_reports_error() {
    run_script backup.sh --dry-run -c "$SCRATCH/unexpected-missing-config"
    assert_contains "$(stderr_text)" \
        "Error: Config file is not readable: $SCRATCH/unexpected-missing-config"
}

# @description Verifies that -c without a value is a usage error (status 2),
#   distinct from the status 1 used for an unreadable file.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_config_missing_short_value_exits_two() {
    run_script backup.sh -c
    assert_eq 2 "$SCRIPT_STATUS" "missing -c value exit status"
}

# @description Verifies that an empty --config-file= value is rejected with a
#   specific message instead of silently falling back to another config.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_config_missing_long_value_reports_error() {
    run_script backup.sh --config-file=
    assert_contains "$(stderr_text)" \
        "Error: --config-file requires a config file."
}

# @description Verifies that options following -c still reach the normal
#   parser. backup.sh strips config arguments first and restores the rest of
#   the argument list, so ordering must not drop --dry-run.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_config_options_after_config_file() {
    write_config "$SCRATCH/cli-config" expected-cli-header
    run_script backup.sh -c "$SCRATCH/cli-config" --dry-run
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/expected-cli-header-"
}

# @description Verifies that maintenance-reminder.sh shares the same config
#   loader and error contract as backup.sh.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_config_shared_by_reminder() {
    run_script maintenance-reminder.sh -c "$SCRATCH/missing-config"
    assert_contains "$(stderr_text)" \
        "Error: Config file is not readable:"
}

# @description Verifies that git-checker.sh shares the same config loader and
#   error contract as backup.sh.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_config_shared_by_git_checker() {
    run_script git-checker.sh -c "$SCRATCH/missing-config"
    assert_contains "$(stderr_text)" \
        "Error: Config file is not readable:"
}

# @description Verifies that arch-maintenance.sh shares the same config loader
#   and error contract as backup.sh.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_config_shared_by_arch_maintenance() {
    run_script arch-maintenance.sh -c "$SCRATCH/missing-config"
    assert_contains "$(stderr_text)" \
        "Error: Config file is not readable:"
}
