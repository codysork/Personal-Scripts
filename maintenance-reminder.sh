
#!/bin/bash
# @file maintenance-reminder.sh
# @author Cody Sork <codysork@gmail.com> with help from ChatGPT
# @created 2026-11-01
# @modified 2026-11-04
# @purpose Sends a reminder via notify-send when the computer is due for maintenance

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

# Number of days until maintenance
DAYS_DUE=6

# Remote server maintenance (optional)
SERVER="sork.local"
SERVER_USER="cody"

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

NOW=$(date +%s)
INTERVAL=$((DAYS_DUE * 24 * 60 * 60))

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/arch-maintenance"
LAST_REMINDER_LOCAL="$STATE_DIR/last-reminder"
PENDING_LOCAL="$STATE_DIR/pending-local"

REMOTE_STATE_DIR=".local/state/arch-maintenance"
REMOTE_LAST=".local/state/arch-maintenance/last-reminder"
REMOTE_PENDING=".local/state/arch-maintenance/pending-remote"

LOCAL_DUE=0
REMOTE_DUE=0

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

info() {
    printf '%s\n' "$1" >&2
}

error() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

# @purpose Checks whether the server is reachable
validate_server() {

    if [[ -z "$SERVER_USER" ]]; then
        error "Server user is not set."
    fi

    if ! ssh \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        "$SERVER_USER@$SERVER" true; then

        return 1
    fi

    info "Connected to server: $SERVER"
    return 0
}

# @purpose Creates the local state directory
confirm_state_dir() {

    if [[ ! -d "$STATE_DIR" ]]; then
        info "Creating state directory: $STATE_DIR"

        mkdir -p "$STATE_DIR" ||
            error "Failed to create state directory: $STATE_DIR"
    fi
}

# @purpose Initializes the local countdown
initialize_local_countdown() {

    if [[ ! -f "$LAST_REMINDER_LOCAL" ]]; then
        info "Initializing local maintenance countdown."

        printf '%s\n' "$NOW" > "$LAST_REMINDER_LOCAL" ||
            error "Failed to initialize local countdown."
    fi
}

# @purpose Initializes the remote countdown
# @purpose Initializes the remote countdown if it doesn't exist
initialize_remote_countdown() {

    ssh "$SERVER_USER@$SERVER" '
        STATE_DIR="$HOME/.local/state/arch-maintenance"
        LAST_REMINDER="$STATE_DIR/last-reminder"

        if [[ ! -s "$LAST_REMINDER" ]]; then
            mkdir -p "$STATE_DIR" || exit 1
            date +%s > "$LAST_REMINDER" || exit 1
            echo "Remote countdown initialized."
        else
            echo "Remote countdown already exists."
        fi
    ' || return 1
}

# @param $1 Current timestamp
# @param $2 Previous maintenance timestamp
# @purpose Checks whether the maintenance interval has elapsed
check_if_time_elapsed() {

    local now=$1
    local last=$2

    [[ "$last" =~ ^[0-9]+$ ]] || return 1

    if (( now < last )); then
        info "Timestamp is in the future. Skipping."
        return 1
    fi

    if (( now - last >= INTERVAL )); then
        return 0
    fi

    return 1
}

# @purpose Checks local maintenance status
check_local_maintenance() {

    local last

    if [[ -f "$PENDING_LOCAL" ]]; then
        info "Local maintenance already pending."
        LOCAL_DUE=1
        return
    fi

    read -r last < "$LAST_REMINDER_LOCAL" ||
        error "Could not read local maintenance timestamp."

    if check_if_time_elapsed "$NOW" "$last"; then
        info "Local maintenance is due."

        touch "$PENDING_LOCAL" ||
            error "Could not mark local maintenance as pending."

        LOCAL_DUE=1
    else
        info "Local maintenance is not due yet."
    fi
}

# @purpose Checks remote maintenance status
check_remote_maintenance() {

    local result

    result=$(ssh "$SERVER_USER@$SERVER" '
        if [[ -f "$HOME/.local/state/arch-maintenance/pending-remote" ]]; then
            printf "PENDING\n"
        else
            cat "$HOME/.local/state/arch-maintenance/last-reminder"
        fi
    ') || {
        info "Could not retrieve remote maintenance status."
        return 1
    }

    if [[ "$result" == "PENDING" ]]; then
        info "Remote maintenance already pending."
        REMOTE_DUE=1
        return
    fi

    if check_if_time_elapsed "$NOW" "$result"; then
        info "Remote maintenance is due."

        ssh "$SERVER_USER@$SERVER" '
            touch "$HOME/.local/state/arch-maintenance/pending-remote"
        ' || {
            info "Could not mark remote maintenance as pending."
            return 1
        }

        REMOTE_DUE=1
    else
        info "Remote maintenance is not due yet."
    fi
}

# @purpose Sends a maintenance reminder
reminders() {

    if (( LOCAL_DUE && REMOTE_DUE )); then
        notify-send \
            -a "maintenance-reminder.sh" \
            -u normal \
            "System Maintenance" \
            "Local and server maintenance are due."

    elif (( LOCAL_DUE )); then
        notify-send \
            -a "maintenance-reminder.sh" \
            -u normal \
            "System Maintenance" \
            "Time to run your local arch-maintenance.sh."

    elif (( REMOTE_DUE )); then
        notify-send \
            -a "maintenance-reminder.sh" \
            -u normal \
            "Server Maintenance" \
            "Time to run maintenance on $SERVER."
    fi
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

# Setup
confirm_state_dir
initialize_local_countdown

# Check local maintenance
check_local_maintenance

# Check remote maintenance (if configured)
if [[ -n "$SERVER" ]]; then

    if validate_server; then

        if initialize_remote_countdown; then
            check_remote_maintenance
        else
            info "Could not initialize remote countdown."
        fi

    else
        info "Server unavailable. Skipping remote maintenance check."
    fi

fi

# Send reminders if maintenance is pending
if (( LOCAL_DUE || REMOTE_DUE )); then
    reminders
else
    info "No maintenance reminders necessary."
fi

