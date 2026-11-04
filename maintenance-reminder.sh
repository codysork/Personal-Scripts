#!/bin/bash
# @file maintenance-reminder.sh
# @author Cody Sork <codysork@gmail.com> with help from ChatGPT
# @created 2026-11-01
# @modified 2026-11-01
# @purpose Sends a reminder via notify-send when the computer is due for maintenance

#------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

# Number of days until maintenance
DAYS_DUE=6
# Reminders for server maintenance (optional)
SERVER="sork.local" # 10.0.0.162 (configured in /etc/hosts)
SERVER_USER="cody"

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

NOW=$(date +%s)
INTERVAL=$(($DAYS_DUE * 24 * 60 * 60))
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/arch-maintenance"
LAST_REMINDER_LOCAL="$STATE_DIR/last-reminder"
LAST_REMINDER_REMOTE="$STATE_DIR/last-reminder-remote"
PENDING_LOCAL="$STATE_DIR/pending-local"
PENDING_REMOTE="$STATE_DIR/pending-remote"

LOCAL_DUE=0
REMOTE_DUE=0

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

# @purpose Checks if the server is reachable
validate_server() {
    ssh "$SERVER_USER@$SERVER" exit

    if [[ -z "$SERVER_USER" ]]; then
        error "Server user is not set."
    fi

    if [[ $? -ne 0 ]]; then
        error "Failed to connect to server: $SERVER"
    fi

    info "Connected to server: $SERVER"
}

# @purpose Create the state directory if it doesn't exist
confirm_state_dir() {
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
}

# @purpose Initializes the countdown file locally on the first login, and on
#          the remote server too if the server is set and reachable
initialize_countdown() {

    if [[ ! -f "$LAST_REMINDER_LOCAL" ]]; then
        printf '%s\n' "$NOW" > "$LAST_REMINDER_LOCAL" || exit 0
    fi

    if [[ -n "$SERVER" && -n "$SERVER_USER" ]]; then
        info "Initializing countdown."
        if ! validate_server; then
            error "Failed to connect to server: $SERVER"
        fi
        ssh "$SERVER_USER@$SERVER" touch "$LAST_REMINDER_REMOTE"
    fi

}

# @param $1 The timmestamp for right now
# @param $2 The timestamp of the last reminder
# @purpose Checks if the specified number of days have elapsed
check_if_time_elapsed() {
    local now=$1
    local last=$2
    if (( now < last || now - last < INTERVAL )); then
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
}

validate_maintenance_timestamps() {

    if [[ -f "$LAST_REMINDER_LOCAL" ]]; then
        read -r LAST < "$LAST_REMINDER_LOCAL"
        [[ "$LAST" =~ ^[0-9]+$ ]] || exit 0
        check_if_time_elapsed "$NOW" "$LAST"
    fi

    if [[ -f "$LAST_REMINDER_REMOTE" ]]; then
        read -r LAST < "$LAST_REMINDER_REMOTE"
        [[ "$LAST" =~ ^[0-9]+$ ]] || exit 0
        check_if_time_elapsed "$NOW" "$LAST"
    fi

}

mark_maintenance_pending() {

    if [[ -f "$PENDING_LOCAL" ]]; then
        info "Maintenance already pending."
    else
        info "Marking maintenance as pending."
        touch "$PENDING_LOCAL" || exit 0
    fi

    if [[ -f "$PENDING_REMOTE" ]]; then
        info "Maintenance already pending."
    else
        info "Marking maintenance as pending."
        touch "$PENDING_REMOTE" || exit 0
    fi
}

reminders() {
    notify-send \
        -a "maintenance-reminder.sh" \
        -u normal \
        "System Maintenance" \
        "Time to run your arch-maintenance.sh."   
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

# Setup and initialization
confirm_state_dir
initialize_countdown

# Check if maintenance is due, and mark it as pending if it is
validate_maintenance_timestamps
make_maintenance_pending

# Remind on every login until maintenance is completed.
reminders
