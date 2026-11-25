#!/usr/bin/env bash
# Backup tests: option handling, dry-run behavior, sources, and notifications.

# AI-generated code (unreviewed by a human)
test_backup_help_exits_zero() {
    run_script backup.sh --help
    assert_eq 0 "$SCRIPT_STATUS" "help exit status"
}

# AI-generated code (unreviewed by a human)
test_backup_help_prints_usage() {
    run_script backup.sh --help
    assert_contains "$(stdout_text)" "Usage:"
}

# AI-generated code (unreviewed by a human)
test_backup_invalid_option_exits_one() {
    run_script backup.sh --bogus
    assert_eq 1 "$SCRIPT_STATUS" "invalid option exit status"
}

# AI-generated code (unreviewed by a human)
test_backup_dry_run_announces_archive() {
    write_config "$SCRATCH/cfg-A" A
    run_script backup.sh --dry-run -c "$SCRATCH/cfg-A"
    assert_contains "$(stdout_text)" \
        "Backup would be created: $SCRATCH/out/A-"
}

# AI-generated code (unreviewed by a human)
test_backup_dry_run_creates_no_archive() {
    write_config "$SCRATCH/cfg-A" A
    run_script backup.sh --dry-run -c "$SCRATCH/cfg-A"
    assert_no_files_matching "$SCRATCH/out/*.tar.gz"
}

# AI-generated code (unreviewed by a human)
test_backup_missing_source_aborts() {
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

# AI-generated code (unreviewed by a human)
test_backup_verbose_mode() {
    write_config "$SCRATCH/cfg-A" A
    run_script backup.sh --dry-run -v -c "$SCRATCH/cfg-A"
    assert_contains "$(stdout_text)" "Verbose mode enabled."
}

# AI-generated code (unreviewed by a human)
test_backup_notification_uses_dry_run_text() {
    write_config "$SCRATCH/cfg-A" A
    allow_notification_daemon
    run_script backup.sh --dry-run --notify-send -c "$SCRATCH/cfg-A"
    assert_contains "$(cat "$SCRATCH/notify.log" 2>/dev/null)" \
        "Backup would be created:"
}

# AI-generated code (unreviewed by a human)
test_backup_missing_daemon_aborts() {
    write_config "$SCRATCH/cfg-A" A
    run_script backup.sh --dry-run --notify-send -c "$SCRATCH/cfg-A"
    assert_contains "$(stdout_text)" "No notification daemon is running."
}

# AI-generated code (unreviewed by a human)
test_backup_documented_wait_option_is_rejected() {
    write_config "$SCRATCH/cfg-A" A
    run_script backup.sh --wait-for-dbus --dry-run -c "$SCRATCH/cfg-A"
    assert_contains "$(stdout_text)" "Usage:"
}
