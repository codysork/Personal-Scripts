#!/usr/bin/env bash
# @file maintenance-reminder.sh
# @author Cody Sork <codysork@gmail.com> with help from ChatGPT
# @created 2026-11-01
# @modified 2026-11-25
# @description Sends a notification when the computer or server is due for
#              maintenance.
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

_master_config="${USER_SCRIPTS_CONFIG:-}"
_script_args=()
while (($#)); do
    case "$1" in
        --config-file|-c)
            if (($# < 2)) || [[ -z "$2" ]]; then
                printf 'Error: %s requires a config file.\n' "$1" >&2
                exit 2
            fi
            _master_config=$2
            shift 2
            ;;
        --config-file=*)
            _master_config=${1#*=}
            if [[ -z "$_master_config" ]]; then
                printf 'Error: --config-file requires a config file.\n' >&2
                exit 2
            fi
            shift
            ;;
        *)
            _script_args+=("$1")
            shift
            ;;
    esac
done
set -- "${_script_args[@]}"
unset _script_args

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            printf 'Usage: %s [-c|--config-file FILE] [-h|--help]\n' "$0"
            exit 0
            ;;
    esac
done

# Load the master config. Environment variables override config values.
_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/user-scripts"
_repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$_master_config" ]]; then
    if [[ -r "$_config_dir/config" ]]; then
        _master_config="$_config_dir/config"
    elif [[ -r "$_config_dir/config.conf" ]]; then
        _master_config="$_config_dir/config.conf"
    elif [[ -r "$_repo_dir/config" ]]; then
        _master_config="$_repo_dir/config"
    fi
fi
if [[ -n "$_master_config" ]]; then
    if [[ ! -r "$_master_config" ]]; then
        printf 'Error: Config file is not readable: %s\n' "$_master_config" >&2
        exit 1
    fi
    # shellcheck disable=SC1090
    source "$_master_config"
    export USER_SCRIPTS_CONFIG="$_master_config"
fi
unset _config_dir _repo_dir _master_config

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

# @description Prints an informational line to stderr.
# @param $1 Message to display.
# @return 0.
info() {
    printf '%s\n' "$1" >&2
}

# @description Prints a warning line to stderr.
# @param $1 Message to display.
# @return 0.
warn() {
    printf 'WARNING: %s\n' "$1" >&2
}

# @description Prints an error line to stderr and stops the script.
# @param $1 Message to display.
# @return Does not return; exits 1.
error() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

# @description Reports whether a command is available, so missing notification
#   or SSH tools can be handled without failing.
# @param $1 Command name to look up in PATH.
# @return 0 when found, 1 otherwise.
has_command() {
    command -v "$1" >/dev/null 2>&1
}

# @description Displays a desktop notification and logs the same message
# @param $1 Notification urgency (low, normal, critical)
# @param $2 Notification title
# @param $3 Notification body
# @return 0; a missing or failing notify-send is only warned about.
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

# @description Runs a command on the remote server using non-interactive SSH,
#   so maintenance checks never prompt for a password.
# @param $@ Command and arguments to run on the remote host.
# @return The ssh exit status.
remote_ssh() {

    ssh \
        -o BatchMode=yes \
        -o ConnectTimeout="$SSH_TIMEOUT" \
        "$SERVER_USER@$SERVER" "$@"
}

# @description Checks whether the server accepts a non-interactive SSH
#   connection before any remote countdown work is attempted.
# @return 0 when reachable, 1 otherwise.
validate_server() {

    if ! remote_ssh true; then
        return 1
    fi

    info "Connected to server: $SERVER"
    return 0
}

# @description Creates the local state directory on first run so countdown
#   files can be written.
# @return 0.
confirm_state_dir() {

    if [[ ! -d "$STATE_DIR" ]]; then
        info "Creating state directory: $STATE_DIR"

        mkdir -p "$STATE_DIR" ||
            error "Failed to create state directory: $STATE_DIR"
    fi
}

# @description Initializes the local countdown on first run by recording the
#   current time; later runs compare against it.
# @return 0.
initialize_local_countdown() {

    if [[ ! -f "$LAST_REMINDER" ]]; then
        info "Initializing local maintenance countdown."

        printf '%s\n' "$NOW" > "$LAST_REMINDER" ||
            error "Failed to initialize local countdown."
    fi
}

# @description Initializes the remote countdown on first run, leaving an
#   existing remote timestamp untouched.
# @return 0 when initialized or already present, 1 on SSH failure.
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

# @description Retrieves the remote maintenance state.
# @return 0; prints PENDING, MISSING, or the last maintenance timestamp.
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

# @description Marks remote maintenance as pending so the reminder repeats
#   until arch-maintenance.sh resets the state.
# @return 0.
mark_remote_pending() {

    remote_ssh bash -s -- "$REMOTE_STATE_DIR" <<'REMOTE'
state_dir="$HOME/$1"

mkdir -p "$state_dir" || exit 1
touch "$state_dir/pending" || exit 1
REMOTE
}

# @description Checks whether the maintenance interval has elapsed.
# @param $1 Label used in warning messages.
# @param $2 Previous maintenance timestamp.
# @return 0 if maintenance is due, 1 if not due, 2 if the timestamp is invalid.
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

# @description Checks local maintenance status from the pending marker and
#   stored timestamp, marking maintenance due when the interval has elapsed.
# @return 0; updates LOCAL_DUE and LOCAL_STATUS as side effects.
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

# @description Checks remote maintenance status over SSH and marks it pending
#   when the remote interval has elapsed.
# @return 0; updates REMOTE_DUE and REMOTE_STATUS as side effects.
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

# @description Sends the local maintenance notification with an urgency that
#   reflects due, healthy, or unknown status.
# @return 0.
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

# @description Sends the remote maintenance notification with an urgency that
#   reflects due, healthy, or unknown status.
# @return 0.
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

# @description Sends reminders for all configured targets, including the
#   remote one only when SERVER is set.
# @return 0.
send_notifications() {

    notify_local

    if [[ -n "$SERVER" ]]; then
        notify_remote
    fi
}

# @description Prepares state, checks local and configured remote maintenance,
#   and sends notifications summarizing both.
# @return 0; status problems are warned about rather than propagated.
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
