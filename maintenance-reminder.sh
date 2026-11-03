#!/bin/bash
# @file maintenance-reminder.sh
# @author Cody Sork <codysork@gmail.com> with help from ChatGPT
# @created 2026-11-01
# @modified 2026-11-01
# @purpose Sends a reminder via notify-send when the computer is due for maintenance

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/arch-maintenance"
LAST_REMINDER="$STATE_DIR/last-reminder"
PENDING="$STATE_DIR/pending"

INTERVAL=$((6 * 24 * 60 * 60))
NOW=$(date +%s)

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

info() {
    printf '%s\n' "$1" >&2
}

error() {
    printf '%s\n' "$1" >&2
    exit 1
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

# Create state directory if it does not exist
if [[ ! -d "$STATE_DIR" ]]; then
    info "Creating state directory: $STATE_DIR"
    if ! mkdir -p "$STATE_DIR"; then
        error "Failed to create state directory: $STATE_DIR"
    else 
        info "State directory created: $STATE_DIR"
    fi
else
    info "State directory exists: $STATE_DIR"
fi

# Initialize countdown on first login.
if [[ ! -f "$LAST_REMINDER" ]]; then
    info "Initializing countdown."
    printf '%s\n' "$NOW" > "$LAST_REMINDER" || exit 0
    exit 0
fi

# Read last maintenance timestamp.
read -r LAST < "$LAST_REMINDER"

# Validate timestamp.
[[ "$LAST" =~ ^[0-9]+$ ]] || exit 0

# Check whether six days have elapsed.
if (( NOW < LAST || NOW - LAST < INTERVAL )); then
    info "Maintenance not due yet."
    notify-send \
        -a "maintenance-reminder.sh" \
        -u low \
        "Good to Go!" \
        "Last system maintenance run: $(date -d "@$LAST")"
    exit 0
else
    info "Maintenance due."
fi

# Mark maintenance as pending.
info "Marking maintenance as pending."
touch "$PENDING" || exit 0

# Remind on every login until maintenance is completed.
info "Sending notification."
notify-send \
    -a "maintenance-reminder.sh" \
    -u normal \
    "System Maintenance" \
    "Time to run your arch-maintenance.sh."
