#!/usr/bin/env bash
# maintenance-reminder.sh tests. Notifications are shimmed and remote checks
# are disabled unless a scenario explicitly sets SERVER.

# AI-generated code (unreviewed by a human)
test_reminder_first_run_reports_ok() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" "Local Maintenance: Good to Go!"
}

# AI-generated code (unreviewed by a human)
test_reminder_first_run_writes_timestamp() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_file_present "$SCRATCH/state/last-reminder"
}

# AI-generated code (unreviewed by a human)
test_reminder_due_after_interval() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    printf '%s\n' "$(( $(date +%s) - 6 * 86400 ))" \
        > "$SCRATCH/state/last-reminder"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" "Local Maintenance Due"
}

# AI-generated code (unreviewed by a human)
test_reminder_pending_repeats() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    printf '%s\n' "$(( $(date +%s) - 6 * 86400 ))" \
        > "$SCRATCH/state/last-reminder"
    touch "$SCRATCH/state/pending"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" "Local maintenance is already pending."
}

# AI-generated code (unreviewed by a human)
test_reminder_not_due_after_reset() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    printf '%s\n' "$(date +%s)" > "$SCRATCH/state/last-reminder"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" "Local maintenance is not due yet."
}

# AI-generated code (unreviewed by a human)
test_reminder_invalid_days_due_falls_back() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    DAYS_DUE=abc \
        run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" 'Invalid DAYS_DUE "abc"; using 6.'
}

# AI-generated code (unreviewed by a human)
test_reminder_zero_day_is_due_immediately() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    printf '%s\n' "$(date +%s)" > "$SCRATCH/state/last-reminder"
    DAYS_DUE=0 \
        run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" "Local Maintenance Due"
}

# AI-generated code (unreviewed by a human)
test_reminder_invalid_timestamp_is_unknown() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    printf 'garbage\n' > "$SCRATCH/state/last-reminder"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" \
        "Local maintenance: invalid timestamp 'garbage'."
}

# AI-generated code (unreviewed by a human)
test_reminder_future_timestamp_is_unknown() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    printf '%s\n' "$(( $(date +%s) + 99999 ))" \
        > "$SCRATCH/state/last-reminder"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" \
        "Local maintenance: timestamp is in the future."
}

# AI-generated code (unreviewed by a human)
test_reminder_empty_server_skips_ssh() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_eq "" "$(cat "$SCRATCH/ssh.log" 2>/dev/null)" \
        "ssh log with SERVER empty"
}

# AI-generated code (unreviewed by a human)
test_reminder_missing_server_user_warns() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    SERVER=example.test SERVER_USER= \
        run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" \
        "SERVER_USER is not set; skipping remote maintenance."
}
