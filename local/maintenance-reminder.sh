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
# Configuration helpers
#------------------------------------------------------------------------------

# @description Extracts config-file options from the script arguments, leaving
#   all other arguments for the normal parser.
# @param $@ Arguments passed to the script.
# @return 0; sets CONFIG_FILE and SCRIPT_ARGS. Exits 2 for a missing value.
parse_config_args() {
    CONFIG_FILE="${USER_SCRIPTS_CONFIG:-}"
    SCRIPT_ARGS=()

    while (($#)); do
        case "$1" in
            --config-file|-c)
                if (($# < 2)) || [[ -z "$2" ]]; then
                    printf 'Error: %s requires a config file.\n' "$1" >&2
                    exit 2
                fi
                CONFIG_FILE=$2
                shift 2
                ;;
            --config-file=*)
                CONFIG_FILE=${1#*=}
                if [[ -z "$CONFIG_FILE" ]]; then
                    printf 'Error: --config-file requires a config file.\n' >&2
                    exit 2
                fi
                shift
                ;;
            *)
                SCRIPT_ARGS+=("$1")
                shift
                ;;
        esac
    done
}

# @description Prints usage and exits when a help option is present.
# @param $@ Arguments remaining after config extraction.
# @return Does not return when help is requested; exits 0.
show_help_if_requested() {
    local arg

    for arg in "$@"; do
        case "$arg" in
            -h|--help)
                printf 'Usage: %s [-c|--config-file FILE] [-h|--help]\n' "$0"
                exit 0
                ;;
        esac
    done
}

# @description Finds the first readable config file in the installed, legacy,
#   and repository locations, in that order.
# @param $1 Repository root, where the config template lives in local/config.
# @return 0; prints the chosen path, or returns 1 and prints nothing if none
#   is readable.
resolve_config_file() {
    local repo_dir=$1
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/user-scripts"
    local candidate

    for candidate in \
        "$config_dir/config" \
        "$config_dir/config.conf" \
        "$repo_dir/local/config"; do
        if [[ -r "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

# @description Loads the chosen config, falling back to the first readable
#   default when no file was requested explicitly.
# @param $1 Directory containing the repository config template.
# @return 0; a requested but unreadable file is reported and exits 1.
load_config() {
    local repo_dir=$1
    local path=$CONFIG_FILE

    if [[ -z "$path" ]]; then
        path=$(resolve_config_file "$repo_dir") || return 0
        [[ -n "$path" ]] || return 0
    fi

    if [[ ! -r "$path" ]]; then
        printf 'Error: Config file is not readable: %s\n' "$path" >&2
        exit 1
    fi

    # shellcheck disable=SC1090
    source "$path"
    export USER_SCRIPTS_CONFIG="$path"
}

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

parse_config_args "$@"
set -- "${SCRIPT_ARGS[@]}"
unset SCRIPT_ARGS

show_help_if_requested "$@"

# Load the master config. Environment variables override config values.
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
load_config "$REPO_DIR"
unset CONFIG_FILE REPO_DIR

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

# @description Reads one target's maintenance state, reporting retrieval
#   problems in the wording used for that target.
# @param $1 Target name: Local or Remote.
# @return 0; prints PENDING, MISSING, a timestamp, or the remote status output.
maintenance_state() {

    local target=$1
    local last

    if [[ "$target" == "Local" ]]; then
        if [[ -f "$PENDING" ]]; then
            printf 'PENDING\n'
        elif read -r last < "$LAST_REMINDER" && [[ -n "$last" ]]; then
            printf '%s\n' "$last"
        else
            warn "Could not read local maintenance timestamp."
            printf 'MISSING\n'
        fi
        return 0
    fi

    if ! last=$(remote_status); then
        warn "Could not retrieve remote maintenance status."
        return 1
    fi

    if [[ "$last" == "MISSING" ]]; then
        warn "Remote maintenance countdown is missing."
    fi

    printf '%s\n' "$last"
}

# @description Marks one target's maintenance as pending.
# @param $1 Target name: Local or Remote.
# @return 0 on success; local failures exit via error, remote failures return 1.
mark_maintenance_pending() {

    if [[ "$1" == "Local" ]]; then
        touch "$PENDING" ||
            error "Could not mark local maintenance as pending."
        return 0
    fi

    if ! mark_remote_pending; then
        warn "Could not mark remote maintenance as pending."
        return 1
    fi
}

# @description Applies the pending and missing state sentinels and updates the
#   target's due flag and status.
# @param $1 Target name: Local or Remote.
# @param $2 Label used in the pending message.
# @param $3 State value read for the target.
# @return 0 when pending was handled, 1 when missing was handled,
#   2 when the state is a timestamp and checking should continue.
handle_state() {

    local target=$1
    local label=$2
    local state=$3
    local -n due="${target^^}_DUE"
    local -n status="${target^^}_STATUS"

    if [[ "$state" == "PENDING" ]]; then
        info "$label is already pending."
        due=1
        status="ok"
        return 0
    fi

    if [[ "$state" == "MISSING" ]]; then
        status="error"
        return 1
    fi

    status="ok"
    return 2
}

# @description Checks one target's maintenance state and updates its due flag
#   and status.
# @param $1 Target name: Local or Remote.
# @return 0; problems are reported and reflected in <TARGET>_STATUS.
check_maintenance() {

    local target=$1
    local label="$target maintenance"
    local -n due="${target^^}_DUE"
    local -n status="${target^^}_STATUS"
    local state
    local result

    if ! state=$(maintenance_state "$target"); then
        status="error"
        return 1
    fi

    handle_state "$target" "$label" "$state"
    result=$?

    if (( result != 2 )); then
        return "$result"
    fi

    check_due "$label" "$state"
    result=$?

    if (( result == 2 )); then
        status="error"
        return 1
    fi

    if (( result == 1 )); then
        info "$label is not due yet."
        return 0
    fi

    info "$label is due."

    if ! mark_maintenance_pending "$target"; then
        status="error"
        return 1
    fi

    due=1
}

# @description Sends the notification for one maintenance target using a single
#   wording pattern that names the target being checked.
# @param $1 Target name used in the title: Local or Remote.
# @param $2 Target address used in the message: localhost or $SERVER.
# @param $3 1 when maintenance is due.
# @param $4 Current status; only "ok" counts as healthy.
# @return 0; the status returned by notify.
notify_status() {

    local target=$1
    local address=$2
    local due=$3
    local status=$4
    local urgency=low
    local suffix=': Unknown'
    local message

    if (( due )); then
        urgency=normal
        suffix=' Due'
        message="Time to run maintenance on $address."
    elif [[ "$status" == "ok" ]]; then
        suffix=': Good to Go!'
        message="No maintenance is currently due on $address."
    else
        message="Could not determine maintenance status for $address."
    fi

    notify "$urgency" "$target Maintenance$suffix" "$message"
}

# @description Sends the local maintenance notification with an urgency that
#   reflects due, healthy, or unknown status.
# @return 0.
notify_local() {

    notify_status Local localhost "$LOCAL_DUE" "$LOCAL_STATUS"
}

# @description Sends the remote maintenance notification with an urgency that
#   reflects due, healthy, or unknown status.
# @return 0.
notify_remote() {

    notify_status Remote "$SERVER" "$REMOTE_DUE" "$REMOTE_STATUS"
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
    check_maintenance Local ||
        warn "Local maintenance status could not be determined."

    if [[ -n "$SERVER" ]]; then

        if validate_server && initialize_remote_countdown; then
            check_maintenance Remote ||
                warn "Remote maintenance status could not be determined."
        else
            REMOTE_STATUS="error"
            info "Server unavailable. Skipping remote maintenance check."
        fi

    fi

    send_notifications
}

main "$@"
