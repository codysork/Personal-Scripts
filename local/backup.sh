#!/usr/bin/bash
#
# @file backup.sh
# @author Cody Sork <codysork@gmail.com> with help from AI agents
# @created 2026-10-31
# @modified 2026-11-25
# @description Back up specified directories into a compressed archive. Includes
#              an option for auto notification when the backup is complete.
#              Also backs up pacman package list and installed AUR packages.

set -euo pipefail

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

# Extract config-file options before loading configuration and leave all other
# arguments for the normal option parser below.
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

# Load the master config. Environment variables override config values.
_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/user-scripts"
_repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "$_master_config" ]]; then
    if [[ -r "$_config_dir/config" ]]; then
        _master_config="$_config_dir/config"
    elif [[ -r "$_config_dir/config.conf" ]]; then
        _master_config="$_config_dir/config.conf"
    elif [[ -r "$_repo_dir/local/config" ]]; then
        _master_config="$_repo_dir/local/config"
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

TIMESTAMP=$(date '+%Y%m%d%H%M%S')
ARCHIVE="$BACKUP_DIR/$ARCHIVE_HEADER-$TIMESTAMP.tar.gz"

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# @description Prints an informational line to stdout.
# @param $1 Message to display.
# @return 0.
info() {
    echo "[INFO] $1"
}

# @description Prints a log line to stdout.
# @param $1 Message to display.
# @return 0.
log() {
    echo "[LOG] $1"
}

# @description Prints a success line to stdout.
# @param $1 Message to display.
# @return 0.
success() {
    echo "[ OK ] $1"
}

# @description Prints a warning line to stdout.
# @param $1 Message to display.
# @return 0.
warning() {
    echo "[WARN] $1"
}

# @description Prints an error line to stdout.
# @param $1 Message to display.
# @return 0.
error() {
    echo "[ERROR] $1"
}

# @description Prints a failure line to stdout.
# @param $1 Message to display.
# @return 0.
fail () {
    echo "[FAIL] $1"
}

# @description Prints the one-line option summary used by help and errors.
# @return 0; text is written to stdout.
usage() {
     echo "Usage: $0 [-h|--help] [-c|--config-file FILE] [-v|--verbose] [--dry-run] [--wait-for-dbus] [--notify-send]"
}

# @description Prints usage followed by the detailed option list.
# @return 0; text is written to stdout.
help() {
    usage
    echo
    echo "Options:"
    echo "  -h, --help        Display this help message"
    echo "  -c, --config-file FILE"
    echo "                    Load settings from FILE"
    echo "  -v, --verbose     Enable verbose mode"
    echo "  --dry-run         Dry run mode"
    echo "  --wait-for-dbus   Wait for DBUS_SESSION environment variable to be set (ensures notifications are sent)"
    echo "  --notify-send     Send notification after backup is complete"
}

# @description Checks the known notification daemons with pgrep so --notify-
#   send can stop early when no daemon is running.
# @return 0 when a daemon is running, 1 otherwise.
ensure_notification_daemon() {
    local -a daemons=(
        dunst
        mako
        xfce4-notifyd
        notification-daemon
    )

    local daemon

    for daemon in "${daemons[@]}"; do
        if pgrep -x "$daemon" >/dev/null 2>&1; then
            info "Notification daemon $daemon is running."
            return 0
        fi
    done

    error "No notification daemon is running."
    return 1
}

#------------------------------------------------------------------------------
# Command Line Options                   
#------------------------------------------------------------------------------

DRY_RUN=0
NOTIFY_SEND=0
VERBOSE=0

for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=1
            info "Dry run mode enabled."
            ;;
        --notify-send)
            NOTIFY_SEND=1
            info "Notifications will be sent."
            ;;
        -h|--help)
            help
            exit 0
            ;;
        -v|--verbose)
            info "Verbose mode enabled."
            VERBOSE=1
            ;;
        --wait-for-notification-daemon)
            while ! ensure_notification_daemon; do
                sleep 60
            done
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

#------------------------------------------------------------------------------
# Backup
#------------------------------------------------------------------------------

# Create backup directory if necessary.
if [[ ! -d "$BACKUP_DIR" ]]; then
    info "Backup directory does not exist. Creating backup directory $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
fi

# Build exlusion list for tar
TAR_EXCLUDES=()
for exclude in "${EXCLUDES[@]}"; do
    TAR_EXCLUDES+=("--exclude=$exclude")
done

# Verbose mode
TAR_VERBOSE=()
if [[ $VERBOSE -eq 1 ]]; then
    TAR_VERBOSE=(--verbose)
fi

# Ensure source directories exist
for dir in "${BACKUP_SOURCES[@]}"; do
    if [[ ! -d "$dir" ]]; then
        error "Source directory not found: $dir" >&2
        exit 1
    fi
done

# Calculate total source size, excluding excluded directories.
DU_EXCLUDES=()
if [[ $DRY_RUN -eq 0 ]]; then
    for exclude in "${EXCLUDES[@]}"; do
        DU_EXCLUDES+=(--exclude="${exclude#"$HOME"/}")
    done
    TOTAL_SIZE=$(du -sb "${DU_EXCLUDES[@]}" -- "${BACKUP_SOURCES[@]}" |
        awk '{s+=$1} END {print s}')
fi

# Create compressed archive, showing progress.
if [[ $DRY_RUN -eq 0 ]]; then
    echo "[INFO] Creating backup archive $ARCHIVE..."
    TEMP_ARCHIVE="$ARCHIVE.tmp"
    if ! tar -P -c "${TAR_VERBOSE[@]}" -f - "${TAR_EXCLUDES[@]}" -- \
        "${BACKUP_SOURCES[@]}" | pv -s "$TOTAL_SIZE" | gzip -c > "$TEMP_ARCHIVE"; then
        fail "Backup failed. Removing incomplete archive." >&2
        rm -f "$ARCHIVE"
        exit 1
    fi
fi

# Verify archive integrity
if [[ $DRY_RUN -eq 0 ]]; then
    echo "[INFO] Verifying archive..."
    if ! tar -Ptzf "$TEMP_ARCHIVE" > /dev/null; then
        fail "Tar archive verification failed!" >&2
        rm -f "TEMP_ARCHIVE"
        exit 1
    else
        mv "$TEMP_ARCHIVE" "$ARCHIVE"
    fi
fi

# Complete
if [[ $DRY_RUN -eq 0 ]]; then
    success "Backup created: $ARCHIVE at $BACKUP_DIR"
else
    success "Backup would be created: $ARCHIVE"
fi

# Send notification
if [[ $NOTIFY_SEND -eq 1 ]]; then

    if ! ensure_notification_daemon; then
        exit 1
    fi

    if [[ $DRY_RUN -eq 0 ]]; then
        notify-send "backup.sh" "Backup created:\n\n$ARCHIVE"
    else
        notify-send "backup.sh" "Backup would be created:\n\n$ARCHIVE"
    fi

fi
