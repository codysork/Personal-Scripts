#!/usr/bin/bash
#
# @file backup.sh
# @author Cody Sork <codysork@gmail.com> with help from ChatGPT
# @created 2026-10-31
# @modified 2026-11-02
# @purpose Back up specified directories into a compressed archive. Includes
#          an option for auto

set -euo pipefail

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------
BACKUP_DIR="$HOME/Nextcloud/Backup/Local"

BACKUP_SOURCES=(
    "$HOME/.config"
    "$HOME/.local/share"
    "$HOME/.minetest"
    "$HOME/Code"
    "$HOME/Documents"
    "$HOME/Pictures"
    "$HOME/Scripts"
    "$HOME/Suckless"
)

EXCLUDES=(
    "$HOME/.config/BraveSoftware/Brave-Browser"
    "$HOME/.config/vesktop/sessionData"
    "$HOME/.config/vesktop/sessionData/cache/Cache_Data"
)

TIMESTAMP=$(date '+%Y%m%d%H%M%S')
ARCHIVE_HEADER="sorkhackmac16-backup"
ARCHIVE="$BACKUP_DIR/$ARCHIVE_HEADER-$TIMESTAMP.tar.gz"

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

info() {
    echo "[INFO] $1"
}

log() {
    echo "[LOG] $1"
}

success() {
    echo "[ OK ] $1"
}

warning() {
    echo "[WARN] $1"
}

error() {
    echo "[ERROR] $1"
}

fail () {
    echo "[FAIL] $1"
}

usage() {
     echo "Usage: $0 [-h|--help] [-v|--verbose] [--dry-run] [--wait-for-dbus] [--notify-send]"
}

help() {
    usage
    echo
    echo "Options:"
    echo "  -h, --help        Display this help message"
    echo "  -v, --verbose     Enable verbose mode"
    echo "  --dry-run         Dry run mode"
    echo "  --wait-for-dbus   Wait for DBUS_SESSION environment variable to be set (ensures notifications are sent)"
    echo "  --notify-send     Send notification after backup is complete"
}

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
