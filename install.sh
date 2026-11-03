#!/bin/sh
# @file install.sh
# @author Cody Sork <codysork@gmail.com>
# @created 2026-10-20
# @modified 2026-10-29
# @description Installs all scripts in this repo to the system

#------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------

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

#------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

# Require root
if [ "$(id -u)" != "0" ]; then
    error "This script must be run as root."
    exit 1
fi

# Install scripts
for file in $(ls *.sh); do

    if [ "$file" = "install.sh" ]; then
        info "Skipping $file..."
        continue
    elif [ "$file" = "uninstall.sh" ]; then
        info "Skipping $file..."
        continue
    fi

    info "Installing $file..."
    if ! sudo install -m 755 $file /usr/local/bin; then
        error "Failed to install $file."
    fi

done

success "All scripts have been installed."
