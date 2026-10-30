#!/bin/sh
# @file system-maintenance-check.sh
# @author Cody Sork <codysork@gmail.com>
# @created 2026-10-19
# @modified 2026-10-29
# @description Check if all necessary system maintenance scripts exist

#------------------------------------------------------------------------------#
#                                 Startup                                      #
#------------------------------------------------------------------------------#

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This script must be run as root."
    exit 1
fi

#------------------------------------------------------------------------------#
#                              Configuration                                   #
#------------------------------------------------------------------------------#

# Load config file
if [ -f config ]; then
    CONFIG_FILE="$PWD/config"
else
    CONFIG_FILE="$HOME/.my-scripts/config"
fi

# Check if config file exists
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
else
    echo "[ERROR] Config file not found."
    exit 1
fi

# Check that LOG_FILE_DIR variable is set
if [ -z "$LOG_FILE_DIR" ]; then
    echo "[ERROR] LOG_FILE_DIR variable is not set."
    exit 1
fi

# Check if LOG_FILE_DIR exists, otherwise create it
if [ ! -d "$LOG_FILE_DIR" ]; then
    echo "[INFO] Creating log file directory: $LOG_FILE_DIR"
    if ! mkdir -p "$LOG_FILE_DIR"; then
        echo "[ERROR] Failed to create log file directory: $LOG_FILE_DIR"
        exit 1
    fi
fi

#------------------------------------------------------------------------------#
#                            Maintenance Routine                               #
#------------------------------------------------------------------------------#

# Outline your complete Arch Linux system maintenance routine here.
# Here is a default routine example from the Arch Wiki:
ROUTINE="
$CHECK_FAILED_SERVICES
$CHECK_JOURNALCTL_LOGS
$CHECK_LOG_FILE_ERRORS
$BACKUP_CONFIGS
$BACKUP_PKGLIST
$BACKUP_PACMAN_DATABASE
$BACKUP_USER_DATA
$LIST_UNUSED_LARGE_FILES
$LIST_UNUSED_PKGS
$LIST_OLD_CONFIG_FILES
$LIST_BROKEN_SYMLINKS
$CLEAN_PKG_CACHE
"

#------------------------------------------------------------------------------#
#                              Global Variables                                #
#------------------------------------------------------------------------------#

VERBOSE=0

#------------------------------------------------------------------------------#
#                                  Functions                                   #
#------------------------------------------------------------------------------#

notify_send_as_user() {
    DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
    notify-send "$@"
}

#------------------------------------------------------------------------------$
#                                   Main                                       #
#------------------------------------------------------------------------------$


