#!/usr/bin/env bash
# @file uninstall.sh
# @author Cody Sork <codysork@gmail.com>
# @created 2026-10-20
# @modified 2026-11-25
# @description Removes locally installed scripts by name. Unlike the old
#              directory walk, this never deletes files from the repository.

DRY_RUN=0

#------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------

# @description Parses dry-run, help, and invalid options.
# @param $@ Arguments passed to the script.
# @return 0; exits 0 for help and 1 for an invalid option.
# AI-generated code (unreviewed by a human)
parse_options() {
    local option

    for option in "$@"; do
        case "$option" in
            --dry-run)
                DRY_RUN=1
                ;;
            -h|--help)
                echo "Usage: ./uninstall.sh"
                exit 0
                ;;
            *)
                echo "Invalid option $option"
                exit 1
                ;;
        esac
    done
}

# @description Refuses to continue unless the uninstaller runs with root
#   privileges.
# @return 0 when running as root; exits 1 otherwise.
# AI-generated code (unreviewed by a human)
require_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root"
        exit 1
    fi
}

# @description Removes one installed script, or reports what would be removed
#   during a dry run.
# @param $1 Basename of the installed script.
# @return 0; a missing installed file is not an error.
# AI-generated code (unreviewed by a human)
uninstall_one() {
    local name=$1
    local target="/usr/local/bin/$name"

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would uninstall $name"
        return 0
    fi

    rm -f "$target" || return 1
    echo "Uninstalled $name"
}

# @description Removes every script from local/ that was installed on this
#   machine. The config and the repository files are left untouched.
# @return 0 when all removals succeed; 1 if any rm command fails.
# AI-generated code (unreviewed by a human)
uninstall_local_scripts() {
    local file name status=0

    for file in "$scriptdir"/local/*.sh; do
        [ -f "$file" ] || continue
        name=$(basename "$file")
        uninstall_one "$name" || status=1
    done

    return "$status"
}

#------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

parse_options "$@"
require_root

scriptdir="$(cd "$(dirname "$0")" && pwd)"
uninstall_local_scripts
