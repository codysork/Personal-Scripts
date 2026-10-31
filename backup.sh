#!/usr/bin/env bash
#
# backup.sh
# @author Cody Sork <codysork@gmail.com> with help from ChatGPT
# @created 2026-10-31
# @modified 2026-10-31
# @purpose Back up specified directories into a compressed archive.

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
)

#------------------------------------------------------------------------------
# Command Line Options                   
#------------------------------------------------------------------------------

VERBOSE=0

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            echo "Usage: $0 [-h|--help] [-v|--verbose]"
            exit 0
            ;;
        -v|--verbose)
            echo "[INFO] Verbose mode enabled."
            VERBOSE=1
            ;;
    esac
done

#------------------------------------------------------------------------------
# Backup
#------------------------------------------------------------------------------

TIMESTAMP=$(date '+%Y%m%d%H%M%S')
ARCHIVE="$BACKUP_DIR/$TIMESTAMP.tar.gz"

# Create backup directory if necessary.
if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "Backup directory does not exist. Creating backup directory $BACKUP_DIR..."
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
        echo "[ERROR] Source directory not found: $dir" >&2
        exit 1
    fi
done

# Calculate total source size, excluding excluded directories.
DU_EXCLUDES=()
for exclude in "${EXCLUDES[@]}"; do
    DU_EXCLUDES+=(--exclude="${exclude#"$HOME"/}")
done
TOTAL_SIZE=$(du -sb "${DU_EXCLUDES[@]}" -- "${BACKUP_SOURCES[@]}" |
    awk '{s+=$1} END {print s}')

# Create compressed archive, showing progress.
echo "[INFO] Creating backup archive $ARCHIVE..."
TEMP_ARCHIVE="$ARCHIVE.tmp"
if ! tar -P -c "${TAR_VERBOSE[@]}" -f - "${TAR_EXCLUDES[@]}" -- \
    "${BACKUP_SOURCES[@]}" | pv -s "$TOTAL_SIZE" | gzip -c > "$TEMP_ARCHIVE"; then
    echo "[ERROR] Backup failed. Removing incomplete archive." >&2
    rm -f "$ARCHIVE"
    exit 1
fi

# Verify archive integrity
echo "[INFO] Verifying archive..."
if ! tar -Ptzf "$TEMP_ARCHIVE" > /dev/null; then
    echo "[ERROR] Tar archive verification failed!" >&2
    rm -f "TEMP_ARCHIVE"
    exit 1
else
    mv "$TEMP_ARCHIVE" "$ARCHIVE"
fi

# Complete
echo "[INFO] Backup created: $ARCHIVE at $BACKUP_DIR"

