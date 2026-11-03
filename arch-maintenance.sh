#!/usr/bin/env bash
# @file arch-maintenance.sh
# @author Cody Sork <codysork@gmail.com> with help from ChatGPT
# @created 2026-10-30
# @modified 2026-11-01
# @purpose Comprehensive Arch Linux system maintenance and diagnostics
#
# This script performs maintenance checks and reports potential cleanup.
# It DOES NOT update packages, install packages, or delete anything.
#
# Requirements:
#   pacman
#   pacman-contrib (optional, for checkupdates and paccache)
#   systemd
#   util-linux
#   btrfs-progs (optional, for Btrfs checks)
#   inetutils
#   fwupd (optional, for firmware updates)
#
# Run:
#   chmod +x arch-maintenance.sh
#   ./arch-maintenance.sh

set -uo pipefail

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

SCRIPT_NAME="Arch Linux Maintenance"
TMPDIR_SCRIPT=$(mktemp -d)
BACKUP_DIR="$HOME/Nextcloud/Backup/Local"
MAX_BACKUP_AGE_DAYS=30

trap 'rm -rf "$TMPDIR_SCRIPT"' EXIT

#------------------------------------------------------------------------------
# Colors
#------------------------------------------------------------------------------

if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    RESET=''
fi

#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

section() {
    printf '\n%b============================================================%b\n' "$BLUE" "$RESET"
    printf '%b %s%b\n' "$BOLD" "$1" "$RESET"
    printf '%b============================================================%b\n' "$BLUE" "$RESET"
}

info() {
    printf '%b[INFO]%b %s\n' "$BLUE" "$RESET" "$1"
}

success() {
    printf '%b[ OK ]%b %s\n' "$GREEN" "$RESET" "$1"
}

warning() {
    printf '%b[WARN]%b %s\n' "$YELLOW" "$RESET" "$1"
}

error() {
    printf '%b[FAIL]%b %s\n' "$RED" "$RESET" "$1"
}

has_command() {
    command -v "$1" >/dev/null 2>&1
}

#------------------------------------------------------------------------------
# Initial checks
#------------------------------------------------------------------------------

if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root."
    info "Run it as your normal user."
    exit 1
fi

if ! has_command pacman; then
    error "Pacman not found. This script requires Arch Linux."
    exit 1
fi

printf '\n%b%s%b\n' "$BOLD" "$SCRIPT_NAME" "$RESET"
printf 'Date: %s\n' "$(date)"
printf 'Hostname: %s\n' "$(hostname)"
printf 'Kernel: %s\n' "$(uname -r)"

#------------------------------------------------------------------------------
# 1. Package updates
#------------------------------------------------------------------------------

section "PACKAGE UPDATES"

if has_command checkupdates; then

    checkupdates \
        >"$TMPDIR_SCRIPT/updates" \
        2>"$TMPDIR_SCRIPT/updates_error"
    update_status=$?

    update_count=$(awk 'NF { n++ } END { print n+0 }' \
        "$TMPDIR_SCRIPT/updates")

    if [[ $update_status -eq 0 ]]; then

        success "$update_count packages available for updating."

        if [[ $update_count -gt 0 ]]; then
            cat "$TMPDIR_SCRIPT/updates"
        fi

    else
        warning "Could not reliably determine available updates."
        cat "$TMPDIR_SCRIPT/updates_error"
    fi

else
    warning "checkupdates is unavailable."
    info "Install pacman-contrib to enable update checking."
fi

#------------------------------------------------------------------------------
# 2. Orphaned packages
#------------------------------------------------------------------------------

section "ORPHANED PACKAGES"

mapfile -t orphans < <(pacman -Qtdq 2>/dev/null)

if [[ ${#orphans[@]} -eq 0 ]]; then

    success "No orphaned packages found."

else

    warning "${#orphans[@]} orphaned packages found."

    printf '%s\n' "${orphans[@]}"

    info "Review these packages before considering removal."
fi

#------------------------------------------------------------------------------
# 3. Foreign packages
#------------------------------------------------------------------------------

section "FOREIGN PACKAGES"

mapfile -t foreign < <(pacman -Qm 2>/dev/null)

if [[ ${#foreign[@]} -eq 0 ]]; then

    success "No foreign packages found."

else

    info "${#foreign[@]} foreign packages installed."

    printf '%s\n' "${foreign[@]}"

    info "These may include AUR packages or manually installed packages."
fi

#------------------------------------------------------------------------------
# 4. Package cache
#------------------------------------------------------------------------------

section "PACKAGE CACHE"

if has_command paccache; then

    info "Potentially removable cached package versions."
    info "Default policy: retain the three newest versions."

    paccache -d 2>&1

    printf '\n'

    info "Cached packages belonging to uninstalled packages."

    paccache -d -u -k0 2>&1

else

    warning "paccache unavailable."
    info "Install pacman-contrib for package-cache analysis."
fi

#------------------------------------------------------------------------------
# 5. Pacnew and Pacsave files
#------------------------------------------------------------------------------

section "PACNEW / PACSAVE FILES"

mapfile -t config_files < <(
    find /etc -type f \
        \( -name '*.pacnew' -o -name '*.pacsave' \) \
        -print 2>/dev/null
)

if [[ ${#config_files[@]} -eq 0 ]]; then

    success "No pending pacnew or pacsave files found."

else

    warning "${#config_files[@]} configuration files need review."

    printf '%s\n' "${config_files[@]}"

    info "Compare and merge these manually."
    info "Do not blindly replace existing configuration files."
fi

#------------------------------------------------------------------------------
# 6. Pacman database consistency
#------------------------------------------------------------------------------

section "PACMAN DATABASE"

if pacman -Dk >"$TMPDIR_SCRIPT/db_check" 2>&1; then

    success "Package database dependency consistency check passed."

else

    error "Package database consistency problems detected."

    cat "$TMPDIR_SCRIPT/db_check"
fi

#------------------------------------------------------------------------------
# 7. Installed package file integrity
#------------------------------------------------------------------------------

section "PACKAGE FILE INTEGRITY"

info "Checking installed packages for missing files..."

if pacman -Qk >"$TMPDIR_SCRIPT/file_check" 2>&1; then

    if [[ -s "$TMPDIR_SCRIPT/file_check" ]]; then

        warning "Package integrity check reported issues."

        cat "$TMPDIR_SCRIPT/file_check"

    else

        success "No missing package files reported."
    fi

else

    error "Package file integrity check encountered an error."

    cat "$TMPDIR_SCRIPT/file_check"
fi

#------------------------------------------------------------------------------
# 8. Failed system services
#------------------------------------------------------------------------------

section "SYSTEMD SERVICES"

systemctl --failed --no-pager

printf '\n'

info "User-level failed services:"

systemctl --user --failed --no-pager 2>&1 || \
    warning "Unable to inspect user-level services."

#------------------------------------------------------------------------------
# 9. Systemd maintenance timers
#------------------------------------------------------------------------------

section "SYSTEMD TIMERS"

for timer in fstrim.timer paccache.timer; do

    printf '\n%s\n' "$timer"

    printf '  Enabled: '
    systemctl is-enabled "$timer" 2>/dev/null || \
        printf 'not enabled or unavailable\n'

    printf '  Active:  '
    systemctl is-active "$timer" 2>/dev/null || \
        printf 'not active\n'

done

printf '\n'

info "Scheduled systemd timers:"

systemctl list-timers --all --no-pager

#------------------------------------------------------------------------------
# 10. System journal
#------------------------------------------------------------------------------

section "SYSTEM JOURNAL"

if has_command journalctl; then

    info "Journal disk usage:"

    journalctl --disk-usage 2>&1

    printf '\n'

    info "Recent errors from the current boot (last 30):"

    journalctl -b -p err -n 30 --no-pager 2>&1

    printf '\n'

    info "Recent user-session errors:"

    journalctl --user -b -p err -n 20 --no-pager 2>&1

else

    warning "journalctl unavailable."
fi

#------------------------------------------------------------------------------
# 11. Kernel and modules
#------------------------------------------------------------------------------

section "KERNEL"

running_kernel=$(uname -r)

if [[ -d "/usr/lib/modules/$running_kernel" ]]; then

    success "Modules for the running kernel are present."

else

    warning "Modules for the running kernel were not found."
    warning "A reboot or kernel installation may be necessary."
fi

info "Installed kernel module directories:"

find /usr/lib/modules -mindepth 1 -maxdepth 1 \
    -type d -printf '%f\n' 2>/dev/null || true

#------------------------------------------------------------------------------
# 12. Filesystem and disk usage
#------------------------------------------------------------------------------

section "FILESYSTEM USAGE"

info "Filesystem capacity:"

df -hT -x tmpfs -x devtmpfs

printf '\n'

info "Filesystem inode usage:"

df -ih -x tmpfs -x devtmpfs

#------------------------------------------------------------------------------
# 13. Btrfs checks
#------------------------------------------------------------------------------

section "BTRFS"

if has_command btrfs; then

    mapfile -t btrfs_mounts < <(
        findmnt -rn -t btrfs -o TARGET 2>/dev/null
    )

    if [[ ${#btrfs_mounts[@]} -gt 0 ]]; then

        for mount in "${btrfs_mounts[@]}"; do

            printf '\nMount: %s\n' "$mount"

            btrfs scrub status "$mount" 2>&1 || \
                warning "Could not retrieve scrub status."

        done

        info "No scrub was started or modified."

    else

        info "No mounted Btrfs filesystems detected."
    fi

else

    info "Btrfs tools unavailable; skipping."
fi

#------------------------------------------------------------------------------
# 14. Pacman cache directory size
#------------------------------------------------------------------------------

section "SYSTEM CACHE USAGE"

info "Pacman package cache:"

du -sh /var/cache/pacman/pkg 2>/dev/null || true

printf '\n'

info "System cache directories:"

if [[ -d /var/cache ]]; then
    du -xhd1 /var/cache 2>/dev/null | sort -h | tail -n 15
fi

#------------------------------------------------------------------------------
# 15. User cache usage
#------------------------------------------------------------------------------

section "USER CACHE USAGE"

if [[ -d "$HOME/.cache" ]]; then

    info "Total user cache size:"

    du -sh "$HOME/.cache" 2>/dev/null

    printf '\n'

    info "Largest user cache directories:"

    du -xhd1 "$HOME/.cache" 2>/dev/null | sort -h | tail -n 15

else

    success "No user cache directory found."
fi

#------------------------------------------------------------------------------
# 16. Broken symlinks
#------------------------------------------------------------------------------

section "BROKEN SYMLINKS"

info "Searching /etc and your home directory."

find /etc "$HOME" \
    -xtype l \
    -print 2>/dev/null \
    >"$TMPDIR_SCRIPT/broken_links"

if [[ -s "$TMPDIR_SCRIPT/broken_links" ]]; then

    warning "Potentially broken symbolic links found."

    cat "$TMPDIR_SCRIPT/broken_links"

    info "Inspect these before removing anything."

else

    success "No broken symlinks found in searched locations."
fi

#------------------------------------------------------------------------------
# 17. Firmware update capability
#------------------------------------------------------------------------------

section "FIRMWARE"

if has_command fwupdmgr; then

    info "Checking available firmware updates."

    fwupdmgr get-updates 2>&1 || \
        warning "Firmware update check could not complete."

else

    info "fwupd is not installed. Firmware update checking unavailable."
fi

#------------------------------------------------------------------------------
# 18. Backup reminder
#------------------------------------------------------------------------------

section "BACKUP REMINDER"

info "Verify that your important data is backed up."
info "Consider maintaining backups of:"
info "  - /etc"
info "  - Your home directory"
info "  - Pacman package lists"
info "  - Important application configurations"
info "  - Any encryption recovery metadata"


#------------------------------------------------------------------------------
# 19. Backup freshness
#------------------------------------------------------------------------------

section "BACKUP FRESHNESS"

if [[ ! -d "$BACKUP_DIR" ]]; then

    error "Backup directory not found: $BACKUP_DIR"

else

    latest_backup=""
    latest_timestamp=""

    while IFS= read -r -d '' filepath; do

        filename="${filepath##*/}"

        # Require exactly YYYYMMDDHHmmss.tar.gz
        if [[ ! "$filename" =~ ^([0-9]{14})\.tar\.gz$ ]]; then
            continue
        fi

        timestamp="${BASH_REMATCH[1]}"

        # Validate calendar date and time.
        if ! backup_epoch=$(date -d \
            "${timestamp:0:8} ${timestamp:8:2}:${timestamp:10:2}:${timestamp:12:2}" \
            +%s 2>/dev/null); then
            continue
        fi

        # Select newest timestamp.
        if [[ -z "$latest_timestamp" || \
              "$timestamp" > "$latest_timestamp" ]]; then

            latest_timestamp="$timestamp"
            latest_backup="$filename"
        fi

    done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -print0)

    if [[ -z "$latest_backup" ]]; then

        error "No valid backups found."

    else

        current_epoch=$(date +%s)
        age_seconds=$((current_epoch - backup_epoch))

        # Recalculate selected backup epoch.
        age_seconds=$((current_epoch - $(date -d \
            "${latest_timestamp:0:8} ${latest_timestamp:8:2}:${latest_timestamp:10:2}:${latest_timestamp:12:2}" \
            +%s)))

        age_days=$((age_seconds / 86400))

        printf 'Latest backup: %s\n' "$latest_backup"
        printf 'Backup age:    %s days\n' "$age_days"
        printf 'Maximum age:   %s days\n' "$MAX_BACKUP_AGE_DAYS"

        if [[ $age_seconds -lt 0 ]]; then

            warning "Backup timestamp is in the future."

        elif [[ $age_seconds -ge $((MAX_BACKUP_AGE_DAYS * 86400)) ]]; then

            error "Backup is overdue!"

        else

            success "Backup is within the required age limit."

        fi

    fi

fi


#------------------------------------------------------------------------------
# 20. Timeshift freshness
#------------------------------------------------------------------------------

section "TIMESHIFT FRESHNESS"

# Configuration
MIN_SNAPSHOTS=3
MAX_SNAPSHOT_AGE_DAYS=30

if ! has_command timeshift; then

    error "Timeshift is not installed."

elif ! sudo -v; then

    error "Sudo authentication failed. Skipping Timeshift check."

else

    if ! sudo timeshift --list --scripted \
        >"$TMPDIR_SCRIPT/timeshift" 2>"$TMPDIR_SCRIPT/timeshift_error"; then

        error "Could not retrieve Timeshift snapshots."
        cat "$TMPDIR_SCRIPT/timeshift_error"

    else

        # Extract snapshot dates (YYYY-MM-DD HH:MM:SS).
        mapfile -t snapshots < <(
            sed -nE \
                's/^[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}).*/\1/p' \
                "$TMPDIR_SCRIPT/timeshift"
        )

        snapshot_count=${#snapshots[@]}

        printf 'Snapshots found: %s\n' "$snapshot_count"
        printf 'Minimum required: %s\n' "$MIN_SNAPSHOTS"
        printf 'Maximum age: %s days\n\n' "$MAX_SNAPSHOT_AGE_DAYS"

        # Check snapshot count.
        if [[ $snapshot_count -ge $MIN_SNAPSHOTS ]]; then

            success "Snapshot count requirement satisfied."

        else

            error "Insufficient Timeshift snapshots."
        fi

        # Check snapshot freshness.
        current_epoch=$(date +%s)
        newest_epoch=0
        newest_snapshot=""

        for snapshot in "${snapshots[@]}"; do

            if ! snapshot_epoch=$(date -d "$snapshot" +%s 2>/dev/null); then
                continue
            fi

            if [[ $snapshot_epoch -gt $newest_epoch ]]; then

                newest_epoch=$snapshot_epoch
                newest_snapshot=$snapshot

            fi

        done

        if [[ -z "$newest_snapshot" ]]; then

            error "No valid snapshot timestamps found."

        else

            age_seconds=$((current_epoch - newest_epoch))
            age_days=$((age_seconds / 86400))

            printf 'Newest snapshot: %s\n' "$newest_snapshot"
            printf 'Snapshot age: %s days\n' "$age_days"

            if [[ $age_seconds -lt 0 ]]; then

                warning "Newest snapshot has a future timestamp."

            elif [[ $age_seconds -ge $((MAX_SNAPSHOT_AGE_DAYS * 86400)) ]]; then

                error "Latest snapshot is older than 30 days."

            else

                success "Snapshot freshness requirement satisfied."

            fi

        fi

    fi

fi

#------------------------------------------------------------------------------
# 21. Disable Maintenance Reminder
#------------------------------------------------------------------------------

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/arch-maintenance"
PENDING="$STATE_DIR/pending"

rm -f "$PENDING"


#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------

section "MAINTENANCE COMPLETE"

printf '\n'
success "All scheduled maintenance checks have finished."

info "No packages were installed or upgraded."
info "No packages were removed."
info "No caches or logs were cleaned."
info "No configuration files were modified."
info "No filesystem data was deleted."

printf '\n'
printf '%bReview the warnings and cleanup candidates above.%b\n' \
    "$YELLOW" "$RESET"

printf '\n'

