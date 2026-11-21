#!/usr/bin/env bash
# @file maintenance-reminder.sh
# @author Cody Sork <codysork@gmail.com> with help from ChatGPT
# @created 2026-11-01
# @modified 2026-11-20
# @purpose Sends a notification when the computer or server is due for
#          maintenance.
#
# A reminder becomes due once the maintenance interval has elapsed since the
# timestamp stored in "last-reminder". When due, a "pending" marker is created
# and the reminder repeats on every run until arch-maintenance.sh finishes and
# resets the state.
#
# Run:
#   ./maintenance-reminder.sh
#
# Configuration can be overridden in the environment, for example:
#   DAYS_DUE=14 SERVER= ./maintenance-reminder.sh

set -uo pipefail

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

# Load the master config. Environment variables override config values.
_user_config="${XDG_CONFIG_HOME:-$HOME/.config}/user-scripts/config.conf"
_repo_config="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/config.conf"
_master_config="${USER_SCRIPTS_CONFIG:-}"
if [[ -z "$_master_config" ]]; then
    if [[ -r "$_user_config" ]]; then
        _master_config="$_user_config"
    elif [[ -r "$_repo_config" ]]; then
        _master_config="$_repo_config"
    fi
fi
if [[ -n "$_master_config" && -r "$_master_config" ]]; then
    # shellcheck disable=SC1090
    source "$_master_config"
fi
unset _user_config _repo_config _master_config

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

NOTIFY_APP="maintenance-reminder.sh"

LAST_REMINDER="$STATE_DIR/last-reminder"
PENDING="$STATE_DIR/pending"

LOCAL_DUE=0
REMOTE_DUE=0
LOCAL_STATUS="ok"
REMOTE_STATUS="disabled"

if [[ ! "$DAYS_DUE" =~ ^[0-9]+$ ]]; then
    printf 'Invalid DAYS_DUE "%s"; using 6.\n' "$DAYS_DUE" >&2
    DAYS_DUE=6
fi

NOW=$(date +%s)
INTERVAL=$((DAYS_DUE * 86400))

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

info() {
    printf '%s\n' "$1" >&2
}

warn() {
    printf 'WARNING: %s\n' "$1" >&2
}

error() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

has_command() {
    command -v "$1" >/dev/null 2>&1
}

# @purpose Displays a desktop notification and logs the same message
# @param $1 Notification urgency (low, normal, critical)
# @param $2 Notification title
# @param $3 Notification body
notify() {

    local urgency=$1
    local title=$2
    local body=$3

    info "$title: $body"

    if ! has_command notify-send; then
        warn "notify-send is not installed; notification not displayed."
        return 0
    fi

    notify-send \
        -a "$NOTIFY_APP" \
        -u "$urgency" \
        "$title" \
        "$body" ||
        warn "notify-send failed; notification not displayed."
}

# @purpose Runs a command on the remote server using non-interactive SSH
remote_ssh() {

    ssh \
        -o BatchMode=yes \
        -o ConnectTimeout="$SSH_TIMEOUT" \
        "$SERVER_USER@$SERVER" "$@"
}

# @purpose Checks whether the server is reachable
validate_server() {

    if ! remote_ssh true; then
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

# @purpose Initializes the local countdown on first run
initialize_local_countdown() {

    if [[ ! -f "$LAST_REMINDER" ]]; then
        info "Initializing local maintenance countdown."

        printf '%s\n' "$NOW" > "$LAST_REMINDER" ||
            error "Failed to initialize local countdown."
    fi
}

# @purpose Initializes the remote countdown on first run
initialize_remote_countdown() {

    local output

    output=$(remote_ssh bash -s -- "$REMOTE_STATE_DIR" <<'REMOTE'
state_dir="$HOME/$1"
last_reminder="$state_dir/last-reminder"

if [[ -s "$last_reminder" ]]; then
    printf 'Remote countdown already exists.\n'
    exit 0
fi

mkdir -p "$state_dir" || exit 1
date +%s > "$last_reminder" || exit 1
printf 'Remote countdown initialized.\n'
REMOTE
    ) || return 1

    [[ -n "$output" ]] && info "$output"

    return 0
}

# @purpose Retrieves the remote maintenance state
# @output PENDING, MISSING, or the last maintenance timestamp
remote_status() {

    remote_ssh bash -s -- "$REMOTE_STATE_DIR" <<'REMOTE'
state_dir="$HOME/$1"
pending="$state_dir/pending"
last_reminder="$state_dir/last-reminder"

if [[ -f "$pending" ]]; then
    printf 'PENDING\n'
elif [[ -r "$last_reminder" ]]; then
    cat "$last_reminder"
else
    printf 'MISSING\n'
fi
REMOTE
}

# @purpose Marks remote maintenance as pending
mark_remote_pending() {

    remote_ssh bash -s -- "$REMOTE_STATE_DIR" <<'REMOTE'
state_dir="$HOME/$1"

mkdir -p "$state_dir" || exit 1
touch "$state_dir/pending" || exit 1
REMOTE
}

# @param $1 Label used in warning messages
# @param $2 Previous maintenance timestamp
# @return 0 if maintenance is due, 1 if not due, 2 if the timestamp is invalid
# @purpose Checks whether the maintenance interval has elapsed
check_due() {

    local label=$1
    local last=$2

    if [[ ! "$last" =~ ^[0-9]+$ ]]; then
        warn "$label: invalid timestamp '${last:-<empty>}'."
        return 2
    fi

    if (( last > NOW )); then
        warn "$label: timestamp is in the future."
        return 2
    fi

    (( NOW - last >= INTERVAL ))
}

# @purpose Checks local maintenance status
check_local_maintenance() {

    local last

    if [[ -f "$PENDING" ]]; then
        info "Local maintenance is already pending."
        LOCAL_DUE=1
        return 0
    fi

    if ! read -r last < "$LAST_REMINDER" || [[ -z "$last" ]]; then
        warn "Could not read local maintenance timestamp."
        LOCAL_STATUS="error"
        return 1
    fi

    check_due "Local maintenance" "$last"

    case $? in
        0)
            info "Local maintenance is due."

            touch "$PENDING" ||
                error "Could not mark local maintenance as pending."

            LOCAL_DUE=1
            ;;
        1)
            info "Local maintenance is not due yet."
            ;;
        *)
            LOCAL_STATUS="error"
            return 1
            ;;
    esac
}

# @purpose Checks remote maintenance status
check_remote_maintenance() {

    local result

    if ! result=$(remote_status); then
        warn "Could not retrieve remote maintenance status."
        REMOTE_STATUS="error"
        return 1
    fi

    case "$result" in
        PENDING)
            info "Remote maintenance is already pending."
            REMOTE_DUE=1
            REMOTE_STATUS="ok"
            return 0
            ;;
        MISSING)
            warn "Remote maintenance countdown is missing."
            REMOTE_STATUS="error"
            return 1
            ;;
    esac

    REMOTE_STATUS="ok"

    check_due "Remote maintenance" "$result"

    case $? in
        0)
            info "Remote maintenance is due."

            if ! mark_remote_pending; then
                warn "Could not mark remote maintenance as pending."
                REMOTE_STATUS="error"
                return 1
            fi

            REMOTE_DUE=1
            ;;
        1)
            info "Remote maintenance is not due yet."
            ;;
        *)
            REMOTE_STATUS="error"
            return 1
            ;;
    esac
}

# @purpose Sends the local maintenance notification
notify_local() {

    if (( LOCAL_DUE )); then
        notify normal \
            "Local Maintenance Due" \
            "Time to run your local arch-maintenance.sh."
    elif [[ "$LOCAL_STATUS" == "ok" ]]; then
        notify low \
            "Local Maintenance: Good to Go!" \
            "No local maintenance is currently due."
    else
        notify low \
            "Local Maintenance: Unknown" \
            "Could not determine local maintenance status."
    fi
}

# @purpose Sends the remote maintenance notification
notify_remote() {

    if (( REMOTE_DUE )); then
        notify normal \
            "Remote Maintenance Due" \
            "Time to run maintenance on $SERVER."
    elif [[ "$REMOTE_STATUS" == "ok" ]]; then
        notify low \
            "Remote Maintenance: Good to Go!" \
            "No remote maintenance is currently due."
    else
        notify low \
            "Remote Maintenance: Unknown" \
            "Could not determine maintenance status for $SERVER."
    fi
}

# @purpose Sends reminders for all configured targets
send_notifications() {

    notify_local

    if [[ -n "$SERVER" ]]; then
        notify_remote
    fi
}

main() {

    if [[ -n "$SERVER" && -z "$SERVER_USER" ]]; then
        warn "SERVER_USER is not set; skipping remote maintenance."
        SERVER=""
    fi

    confirm_state_dir
    initialize_local_countdown
    check_local_maintenance ||
        warn "Local maintenance status could not be determined."

    if [[ -n "$SERVER" ]]; then

        if validate_server && initialize_remote_countdown; then
            check_remote_maintenance ||
                warn "Remote maintenance status could not be determined."
        else
            REMOTE_STATUS="error"
            info "Server unavailable. Skipping remote maintenance check."
        fi

    fi

    send_notifications
}

main "$@"
