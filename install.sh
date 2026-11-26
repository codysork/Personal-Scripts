#!/usr/bin/env bash
# @file install.sh
# @author Cody Sork <codysork@gmail.com>
# @created 2026-10-20
# @modified 2026-11-25
# @description Installs local/ scripts on this machine and remote/ scripts on
#              every host listed in the shared config.

# Configuration defaults are set before the template is sourced so a config
# that omits the deployment keys still leaves remote installation disabled.
REMOTE_SERVERS=()
REMOTE_INSTALL_DIR="${REMOTE_INSTALL_DIR:-/usr/local/bin}"
SSH_TIMEOUT="${SSH_TIMEOUT:-5}"
REMOTE_FAILURE_COUNT=0

#------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------

# @description Prints a colored informational line to stdout.
# @param $1 Message to display.
# @return 0.
# AI-generated code (unreviewed by a human)
info() {
    printf '%b[INFO]%b %s\n' "$BLUE" "$RESET" "$1"
}

# @description Prints a colored success line to stdout.
# @param $1 Message to display.
# @return 0.
# AI-generated code (unreviewed by a human)
success() {
    printf '%b[ OK ]%b %s\n' "$GREEN" "$RESET" "$1"
}

# @description Prints a colored warning line to stdout.
# @param $1 Message to display.
# @return 0.
# AI-generated code (unreviewed by a human)
warning() {
    printf '%b[WARN]%b %s\n' "$YELLOW" "$RESET" "$1"
}

# @description Prints a colored failure line to stdout.
# @param $1 Message to display.
# @return 0.
# AI-generated code (unreviewed by a human)
error() {
    printf '%b[FAIL]%b %s\n' "$RED" "$RESET" "$1"
}

# @description Refuses to continue unless the installer runs with root
#   privileges.
# @return 0 when running as root; exits 1 otherwise.
# AI-generated code (unreviewed by a human)
require_root() {
    if [ "$(id -u)" != "0" ]; then
        error "This script must be run as root."
        exit 1
    fi
}

# @description Resolves the home directory and numeric identity of the user who
#   invoked sudo, falling back to the current user when they are unavailable.
# @return 0; sets target_home, target_uid, and target_gid.
# AI-generated code (unreviewed by a human)
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

# @description Reports whether a script is an installer, which must never be
#   copied into /usr/local/bin.
# @param $1 Basename of the script being considered.
# @return 0 for install.sh or uninstall.sh; 1 otherwise.
# AI-generated code (unreviewed by a human)
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
# AI-generated code (unreviewed by a human)
install_script() {
    info "Installing $1..."
    if ! sudo install -m 755 "$2" /usr/local/bin; then
        error "Failed to install $1."
    fi
}

# @description Moves a legacy config.conf into place when no current config
#   exists, remembering the outcome for the later template message.
# @return 0; sets LEGACY_CONFIG_MIGRATED to 1 only after a successful move.
# AI-generated code (unreviewed by a human)
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
# AI-generated code (unreviewed by a human)
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
# AI-generated code (unreviewed by a human)
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
# AI-generated code (unreviewed by a human)
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

# @description Finds the config that supplies the remote deployment settings,
#   checking the explicit request first and then the installed, legacy, and
#   repository locations.
# @return 0; prints the chosen config path, or returns 1 if none is readable.
# AI-generated code (unreviewed by a human)
resolve_master_config() {
    local candidate

    if [ -n "${USER_SCRIPTS_CONFIG:-}" ]; then
        printf '%s\n' "$USER_SCRIPTS_CONFIG"
        return 0
    fi

    for candidate in \
        "$config_dir/config" \
        "$config_dir/config.conf" \
        "$scriptdir/config"; do
        if [ -r "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

# @description Loads the config used for remote deployment. The repo template is
#   the fallback, so remote installation stays disabled on a fresh checkout.
# @return 0; an explicitly requested but unreadable config exits 1.
# AI-generated code (unreviewed by a human)
load_deploy_config() {
    local path

    path=$(resolve_master_config) || return 0
    if [ ! -r "$path" ]; then
        error "Config file is not readable: $path"
        exit 1
    fi

    # shellcheck disable=SC1090
    . "$path"
}

# @description Runs a command on a remote host with non-interactive SSH so a
#   missing key cannot hang the installer.
# @param $1 Host string from REMOTE_SERVERS.
# @param $@ Command and arguments to run on that host.
# @return The remote command's exit status.
# AI-generated code (unreviewed by a human)
remote_ssh() {
    local host=$1
    shift
    ssh -o BatchMode=yes -o "ConnectTimeout=$SSH_TIMEOUT" "$host" "$@"
}

# @description Copies one file to a remote host over SCP with the same timeout
#   policy as remote_ssh.
# @param $1 Local file to copy.
# @param $2 Host string from REMOTE_SERVERS.
# @param $3 Destination path on that host.
# @return The scp exit status.
# AI-generated code (unreviewed by a human)
remote_scp() {
    local source=$1
    local host=$2
    local destination=$3
    scp -o BatchMode=yes -o "ConnectTimeout=$SSH_TIMEOUT" \
        "$source" "$host:$destination"
}

# @description Deploys one script to one host through a temporary directory,
#   always removing that directory even when the install step fails.
# @param $1 Host string from REMOTE_SERVERS.
# @param $2 Full path of the script to deploy.
# @return 0 on success; 1 when any remote step fails.
# AI-generated code (unreviewed by a human)
install_one_remote_script() {
    local host=$1
    local script=$2
    local name temp_dir

    name=$(basename "$script")
    temp_dir=$(remote_ssh "$host" 'mktemp -d') || return 1
    [ -n "$temp_dir" ] || return 1

    if ! remote_scp "$script" "$host" "$temp_dir/$name"; then
        remote_ssh "$host" "rm -rf '$temp_dir'" >/dev/null 2>&1 || true
        return 1
    fi

    if ! remote_ssh "$host" \
        "sudo install -m 755 '$temp_dir/$name' '$REMOTE_INSTALL_DIR/$name'"; then
        remote_ssh "$host" "rm -rf '$temp_dir'" >/dev/null 2>&1 || true
        return 1
    fi

    remote_ssh "$host" "rm -rf '$temp_dir'" >/dev/null 2>&1 || true
}

# @description Deploys every remote/ script to every configured host, reporting
#   each failure and continuing so one bad host cannot hide the others.
# @return 0 when all deployments succeed; increments REMOTE_FAILURE_COUNT
#   otherwise. An empty host list or script set is a no-op.
# AI-generated code (unreviewed by a human)
install_remote_scripts() {
    local host script

    REMOTE_FAILURE_COUNT=0
    for script in "$scriptdir"/remote/*.sh; do
        [ -f "$script" ] || continue
        for host in "${REMOTE_SERVERS[@]}"; do
            if install_one_remote_script "$host" "$script"; then
                success "Installed $(basename "$script") on $host"
            else
                error "Failed to install $(basename "$script") on $host"
                REMOTE_FAILURE_COUNT=$((REMOTE_FAILURE_COUNT + 1))
            fi
        done
    done
}

# @description Installs every script from local/ into /usr/local/bin, skipping
#   installers that may be placed there by mistake.
# @return 0; individual failures are reported but do not propagate.
# AI-generated code (unreviewed by a human)
install_local_scripts() {
    local file name

    for file in "$scriptdir"/local/*.sh; do
        [ -f "$file" ] || continue
        name=$(basename "$file")
        if is_installer_script "$name"; then
            info "Skipping $name..."
            continue
        fi
        install_script "$name" "$file"
    done
}

#------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

require_root

scriptdir="$(cd "$(dirname "$0")" && pwd)"
resolve_target_identity

config_source="$scriptdir/config"
config_dir="${XDG_CONFIG_HOME:-$target_home/.config}/user-scripts"
config_target="$config_dir/config"
legacy_config="$config_dir/config.conf"

install_local_scripts
load_deploy_config
install_remote_scripts
deploy_config

if [ "$REMOTE_FAILURE_COUNT" -gt 0 ]; then
    error "$REMOTE_FAILURE_COUNT remote installation(s) failed."
    exit 1
fi

success "All scripts have been installed."
