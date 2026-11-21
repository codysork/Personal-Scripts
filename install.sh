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

# Resolve the script directory and the user who invoked sudo, so the config
# lands in that user's XDG config directory rather than root's.
scriptdir="$(cd "$(dirname "$0")" && pwd)"

target_user="${SUDO_USER:-}"
if [ -n "$target_user" ] && [ "$target_user" != "root" ]; then
    target_home="$(getent passwd "$target_user" | cut -d: -f6)"
    target_uid="$(id -u "$target_user")"
    target_gid="$(id -g "$target_user")"
else
    target_home="$HOME"
    target_uid="$(id -u)"
    target_gid="$(id -g)"
fi

[ -n "$target_home" ] || target_home="$HOME"
[ -n "$target_uid" ] || target_uid=0
[ -n "$target_gid" ] || target_gid=0

# Install scripts
for file in "$scriptdir"/*.sh; do

    name="$(basename "$file")"

    if [ "$name" = "install.sh" ]; then
        info "Skipping $name..."
        continue
    elif [ "$name" = "uninstall.sh" ]; then
        info "Skipping $name..."
        continue
    fi

    info "Installing $name..."
    if ! sudo install -m 755 "$file" /usr/local/bin; then
        error "Failed to install $name."
    fi

done

# Deploy the master config template. Never overwrite an existing user-edited
# config; offer the new template as config.conf.new instead.
config_source="$scriptdir/config.conf"
config_target="${XDG_CONFIG_HOME:-$target_home/.config}/user-scripts/config.conf"

if [ -f "$config_source" ]; then
    mkdir -p "$(dirname "$config_target")"

    if [ -e "$config_target" ]; then
        if install -m 644 -o "$target_uid" -g "$target_gid" \
            "$config_source" "$config_target.new"; then
            warning "Config already exists; wrote updated template to $config_target.new"
        else
            error "Failed to write updated config template."
        fi
    elif install -m 644 -o "$target_uid" -g "$target_gid" \
        "$config_source" "$config_target"; then
        success "Installed config template to $config_target"
    else
        error "Failed to install config template."
    fi
fi

success "All scripts have been installed."
