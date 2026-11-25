#!/bin/sh
# @file install.sh
# @author Cody Sork <codysork@gmail.com>
# @created 2026-10-20
# @modified 2026-11-25
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

# @description Refuses to continue unless the installer runs with root
#   privileges.
# @return 0 when running as root; exits 1 otherwise.
require_root() {
    if [ "$(id -u)" != "0" ]; then
        error "This script must be run as root."
        exit 1
    fi
}

# @description Resolves the home directory and numeric identity of the user who
#   invoked sudo, falling back to the current user when they are unavailable.
# @return 0; sets target_home, target_uid, and target_gid.
resolve_target_identity() {
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
}

# @description Reports whether a script is one of the two installers, which
#   must never be copied into /usr/local/bin.
# @param $1 Basename of the script being considered.
# @return 0 for install.sh or uninstall.sh; 1 otherwise.
is_installer_script() {
    case "$1" in
        install.sh|uninstall.sh) return 0 ;;
        *) return 1 ;;
    esac
}

# @description Copies one script into /usr/local/bin and reports the outcome
#   without stopping the remaining installations.
# @param $1 Basename of the script, used in log messages.
# @param $2 Full path of the script to copy.
# @return 0; a failed install is reported but does not propagate.
install_script() {
    info "Installing $1..."
    if ! sudo install -m 755 "$2" /usr/local/bin; then
        error "Failed to install $1."
    fi
}

# @description Moves a legacy config.conf into place when no current config
#   exists, remembering the outcome for the later template message.
# @return 0; sets LEGACY_CONFIG_MIGRATED to 1 only after a successful move.
migrate_legacy_config() {
    LEGACY_CONFIG_MIGRATED=0
    if [ ! -e "$config_target" ] && [ -f "$legacy_config" ]; then
        if mv "$legacy_config" "$config_target"; then
            success "Migrated legacy config to $config_target"
            LEGACY_CONFIG_MIGRATED=1
        else
            warning "Could not migrate legacy config at $legacy_config"
        fi
    fi
}

# @description Offers the template as config.new beside an existing config,
#   choosing the message that reflects a just-completed migration.
# @return 0; a failed write is reported but does not propagate.
deploy_updated_template() {
    if install -m 644 -o "$target_uid" -g "$target_gid" \
        "$config_source" "$config_target.new"; then
        if [ "$LEGACY_CONFIG_MIGRATED" -eq 1 ]; then
            warning "Updated template written to $config_target.new"
        else
            warning "Config already exists; wrote updated template to $config_target.new"
        fi
    else
        error "Failed to write updated config template."
    fi
}

# @description Installs the template as the active config on a fresh setup.
# @return 0; a failed write is reported but does not propagate.
deploy_fresh_template() {
    if install -m 644 -o "$target_uid" -g "$target_gid" \
        "$config_source" "$config_target"; then
        success "Installed config template to $config_target"
    else
        error "Failed to install config template."
    fi
}

# @description Deploys the shared template into the invoking user's XDG config
#   directory, migrating a legacy config first when one is present.
# @return 0; a missing template is a no-op, as before.
deploy_config() {
    [ -f "$config_source" ] || return 0

    mkdir -p "$config_dir"
    migrate_legacy_config

    if [ -e "$config_target" ]; then
        deploy_updated_template
    else
        deploy_fresh_template
    fi
}

#------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

require_root

# Resolve the script directory and the user who invoked sudo, so the config
# lands in that user's XDG config directory rather than root's.
scriptdir="$(cd "$(dirname "$0")" && pwd)"
resolve_target_identity

# Install scripts
for file in "$scriptdir"/*.sh; do
    name="$(basename "$file")"

    if is_installer_script "$name"; then
        info "Skipping $name..."
        continue
    fi

    install_script "$name" "$file"
done

# Deploy the master config template. Never overwrite an existing user-edited
# config; offer the new template as config.new instead. Migrate a legacy
# config.conf so its custom values are not silently ignored.
config_source="$scriptdir/config"
config_dir="${XDG_CONFIG_HOME:-$target_home/.config}/user-scripts"
config_target="$config_dir/config"
legacy_config="$config_dir/config.conf"

deploy_config

success "All scripts have been installed."
