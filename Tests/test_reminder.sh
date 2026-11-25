#!/usr/bin/env bash
# maintenance-reminder.sh tests. Notifications are shimmed and remote checks
# are disabled unless a scenario explicitly sets SERVER.

# @description Verifies that the first run, which initializes the countdown,
#   reports a healthy local status instead of claiming maintenance is due.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_reminder_first_run_reports_ok() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" "Local Maintenance: Good to Go!"
}

# @description Verifies that the first run creates the last-reminder state
#   file; later runs read it to decide whether the interval has elapsed.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_reminder_first_run_writes_timestamp() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_file_present "$SCRATCH/state/last-reminder"
}

# @description Verifies that a timestamp older than DAYS_DUE days produces a
#   due notification.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_reminder_due_after_interval() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    # Backdate the timestamp past the six-day interval so maintenance is due.
    printf '%s\n' "$(( $(date +%s) - 6 * 86400 ))" \
        > "$SCRATCH/state/last-reminder"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" "Local Maintenance Due"
}

# @description Verifies that the pending marker makes the reminder repeat on
#   every run until arch-maintenance.sh resets the state.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_reminder_pending_repeats() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    printf '%s\n' "$(( $(date +%s) - 6 * 86400 ))" \
        > "$SCRATCH/state/last-reminder"
    # The pending flag takes priority over the timestamp calculation.
    touch "$SCRATCH/state/pending"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" "Local maintenance is already pending."
}

# @description Verifies that a freshly reset countdown reports "not due yet"
#   instead of notifying on every run.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_reminder_not_due_after_reset() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    # A current timestamp means the interval has not elapsed.
    printf '%s\n' "$(date +%s)" > "$SCRATCH/state/last-reminder"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" "Local maintenance is not due yet."
}

# @description Verifies that a non-numeric DAYS_DUE is reported and replaced
#   with the six-day default rather than breaking the interval math.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_reminder_invalid_days_due_falls_back() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    DAYS_DUE=abc \
        run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" 'Invalid DAYS_DUE "abc"; using 6.'
}

# @description Verifies that DAYS_DUE=0 shrinks the interval to zero, making
#   even a just-written timestamp due immediately.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_reminder_zero_day_is_due_immediately() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    printf '%s\n' "$(date +%s)" > "$SCRATCH/state/last-reminder"
    DAYS_DUE=0 \
        run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" "Local Maintenance Due"
}

# @description Verifies that a non-numeric stored timestamp is treated as an
#   unknown status rather than as overdue maintenance.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_reminder_invalid_timestamp_is_unknown() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    # Corrupt the state file; numeric comparisons would otherwise misread it.
    printf 'garbage\n' > "$SCRATCH/state/last-reminder"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" \
        "Local maintenance: invalid timestamp 'garbage'."
}

# @description Verifies that a timestamp in the future is treated as unknown
#   rather than silently triggering a due notification.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_reminder_future_timestamp_is_unknown() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    # Simulate clock skew by placing the timestamp ahead of the current time.
    printf '%s\n' "$(( $(date +%s) + 99999 ))" \
        > "$SCRATCH/state/last-reminder"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" \
        "Local maintenance: timestamp is in the future."
}

# @description Verifies that an empty SERVER disables remote checks entirely,
#   proven by the SSH stub log staying empty.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_reminder_empty_server_skips_ssh() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    # No remote check means no ssh invocation to record in the stub log.
    assert_eq "" "$(cat "$SCRATCH/ssh.log" 2>/dev/null)" \
        "ssh log with SERVER empty"
}

# @description Verifies that a server configured without SERVER_USER skips
#   remote maintenance with a warning instead of attempting an SSH connection.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_reminder_missing_server_user_warns() {
    write_reminder_config "$SCRATCH/reminder.cfg"
    SERVER=example.test SERVER_USER= \
        run_script maintenance-reminder.sh -c "$SCRATCH/reminder.cfg"
    assert_contains "$(stderr_text)" \
        "SERVER_USER is not set; skipping remote maintenance."
}
