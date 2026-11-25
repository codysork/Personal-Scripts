#!/usr/bin/env bash
# Backup tests: option handling, dry-run behavior, sources, and notifications.

# @description Verifies that --help is a successful exit, not an error path.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_backup_help_exits_zero() {
    run_script backup.sh --help
    assert_eq 0 "$SCRIPT_STATUS" "help exit status"
}

# @description Verifies that --help prints the usage line so users can discover
#   the available options.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_backup_help_prints_usage() {
    run_script backup.sh --help
    assert_contains "$(stdout_text)" "Usage:"
}

# @description Verifies that an unknown option is rejected with status 1 rather
#   than being ignored.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_backup_invalid_option_exits_one() {
    run_script backup.sh --bogus
    assert_eq 1 "$SCRIPT_STATUS" "invalid option exit status"
}

# @description Verifies that a dry run announces the archive it would create,
#   using "would be created" wording to distinguish it from a real backup.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_backup_dry_run_announces_archive() {
    write_config "$SCRATCH/cfg-A" A
    run_script backup.sh --dry-run -c "$SCRATCH/cfg-A"
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/A-"
}

# @description Verifies that a dry run has no filesystem side effects: unlike
#   the announcement test, this one checks that no .tar.gz was produced.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_backup_dry_run_creates_no_archive() {
    write_config "$SCRATCH/cfg-A" A
    run_script backup.sh --dry-run -c "$SCRATCH/cfg-A"
    assert_no_files_matching "$SCRATCH/out/*.tar.gz"
}

# @description Verifies that backup.sh aborts when a configured source
#   directory is missing, avoiding a silently incomplete archive.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_backup_missing_source_aborts() {
    # write_config always points at an existing source, so build this config
    # inline with a path that deliberately does not exist.
    cat > "$SCRATCH/cfg-nope" <<EOF
BACKUP_DIR="$SCRATCH/out"
BACKUP_SOURCES=("$SCRATCH/nope")
EXCLUDES=()
ARCHIVE_HEADER=A
EOF
    run_script backup.sh --dry-run -c "$SCRATCH/cfg-nope"
    assert_contains "$(stderr_text)" \
        "Source directory not found: $SCRATCH/nope"
}

# @description Verifies that -v is accepted and announces verbose mode, which
#   also enables tar's --verbose output on a real run.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_backup_verbose_mode() {
    write_config "$SCRATCH/cfg-A" A
    run_script backup.sh --dry-run -v -c "$SCRATCH/cfg-A"
    assert_contains "$(stdout_text)" "Verbose mode enabled."
}

# @description Verifies that a notification sent during a dry run uses the
#   "would be created" wording, matching what the console reports.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_backup_notification_uses_dry_run_text() {
    write_config "$SCRATCH/cfg-A" A
    allow_notification_daemon
    run_script backup.sh --dry-run --notify-send -c "$SCRATCH/cfg-A"
    assert_contains "$(cat "$SCRATCH/notify.log" 2>/dev/null)" \
        "Backup would be created:"
}

# @description Verifies that --notify-send aborts when no notification daemon
#   is running (the default pgrep stub fails), instead of losing the alert.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_backup_missing_daemon_aborts() {
    write_config "$SCRATCH/cfg-A" A
    run_script backup.sh --dry-run --notify-send -c "$SCRATCH/cfg-A"
    assert_contains "$(stdout_text)" "No notification daemon is running."
}

# @description Pins the known mismatch between help text and parser: --wait-
#   for-dbus is documented but only --wait-for-notification-daemon is accepted.
#   The test guards against silently changing that public behavior.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_backup_documented_wait_option_is_rejected() {
    write_config "$SCRATCH/cfg-A" A
    run_script backup.sh --wait-for-dbus --dry-run -c "$SCRATCH/cfg-A"
    assert_contains "$(stdout_text)" "Usage:"
}
