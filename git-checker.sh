#!/usr/bin/env bash
#
# @file git-checker.sh
# @author Cody Sork <codysork@gmail.com> with help from ChatGPT
# @created 2026-11-03
# @modified 2026-11-03
# @purpose Check whether local Git repositories are up to date with their remotes.

set -uo pipefail

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

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

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            printf 'Usage: %s [-c|--config-file FILE] [-h|--help]\n' "$0"
            exit 0
            ;;
    esac
done

# Load the master config. Environment variables override config values.
_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/user-scripts"
_repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$_master_config" ]]; then
    if [[ -r "$_config_dir/config" ]]; then
        _master_config="$_config_dir/config"
    elif [[ -r "$_config_dir/config.conf" ]]; then
        _master_config="$_config_dir/config.conf"
    elif [[ -r "$_repo_dir/config" ]]; then
        _master_config="$_repo_dir/config"
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

#------------------------------------------------------------------------------
# Colors
#------------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

#------------------------------------------------------------------------------
# Helpers
#------------------------------------------------------------------------------

info() {
    printf "${CYAN}[INFO]${RESET} %s\n" "$1"
}

success() {
    printf "${GREEN}[OK]${RESET} %s\n" "$1"
}

warning() {
    printf "${YELLOW}[WARN]${RESET} %s\n" "$1"
}

error() {
    printf "${RED}[ERROR]${RESET} %s\n" "$1"
}

# Check whether a directory should be ignored.
is_ignored() {
    local dir="$1"
    local ignored

    for ignored in "${IGNORE_DIRS[@]}"; do
        if [[ "$dir" == "$ignored" || "$dir" == "$ignored/"* ]]; then
            return 0
        fi
    done

    return 1
}

#------------------------------------------------------------------------------
# Repository Discovery
#------------------------------------------------------------------------------

find_repositories() {
    local dir
    local ignored
    local -a find_args=( "$SEARCH_DIR" )

    # Prune ignored subtrees in find itself; walking them wastes time and can
    # surface permission errors. is_ignored() stays as a cheap safety net.
    if [[ -v IGNORE_DIRS ]]; then
        find_args+=( \( )
        for ignored in "${IGNORE_DIRS[@]}"; do
            find_args+=( -path "$ignored" -o )
        done
        unset 'find_args[${#find_args[@]}-1]'
        find_args+=( \) -prune -o )
    fi

    find_args+=(
        \( -name .git -prune \) -o
        \( -type d -print0 \)
    )

    while IFS= read -r -d '' dir; do
        if is_ignored "$dir"; then
            continue
        fi

        # Skip nested repositories.
        if [[ -d "$dir/.git" || -f "$dir/.git" ]]; then
            printf '%s\0' "$dir"
        fi
    done < <(find "${find_args[@]}")
}

#------------------------------------------------------------------------------
# Working Tree Status
#------------------------------------------------------------------------------

check_working_tree() {
    local repo="$1"
    local status

    status=$(git -C "$repo" status --porcelain)

    if [[ -z "$status" ]]; then
        success "Working tree clean."
        return 0
    fi

    warning "Uncommitted changes detected:"

    while IFS= read -r line; do
        printf '    %s\n' "$line"
    done <<< "$status"

    return 1
}



#------------------------------------------------------------------------------
# Repository Status
#------------------------------------------------------------------------------

check_repository() {
    local repo="$1"
    local branch upstream
    local ahead behind

    printf '\n'
    printf '%s\n' "Repository: $repo"

    # Verify repository.
    if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
        error "Invalid Git repository."
        return 1
    fi

    # Check working tree.
    local dirty=0
    
    if ! check_working_tree "$repo"; then
        dirty=1
    fi

    # Identify current branch.
    branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD) || {
        warning "Detached HEAD. Cannot determine upstream."
        return 1
    }

    # Identify upstream.
    upstream=$(git -C "$repo" rev-parse \
        --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) || {
        warning "No upstream configured for branch '$branch'."
        return 1
    }

    # Fetch remote changes.
    if ! git -C "$repo" fetch --quiet --prune; then
        error "Failed to fetch remote."
        return 1
    fi

    # Compare local and remote commits.
    read -r ahead behind < <(
        git -C "$repo" rev-list --left-right --count \
            "$branch...$upstream"
    )

    if (( ahead == 0 && behind == 0 )); then
        success "Up to date with $upstream."

    elif (( ahead > 0 && behind == 0 )); then
        warning "Local branch is ahead by $ahead commit(s)."

    elif (( ahead == 0 && behind > 0 )); then
        error "Local branch is behind by $behind commit(s)."

    else
        error "Branches have diverged: $ahead ahead, $behind behind."
    fi

    return "$dirty"
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    local repo
    local total=0
    local clean=0
    local dirty=0
    
    while IFS= read -r -d '' repo; do
        ((total += 1))
    
        if check_repository "$repo"; then
            ((clean += 1))
        else
            ((dirty += 1))
        fi
    
    done < <(find_repositories)
    
    printf '\n'
    printf '%s\n' "----------------------------------------"
    printf '%s\n' "Git Repository Summary"
    printf '%s\n' "----------------------------------------"
    printf 'Repositories found: %d\n' "$total"
    printf "${GREEN}Clean: %d${RESET}\n" "$clean"
    printf "${YELLOW}Needs attention: %d${RESET}\n" "$dirty"
 }

main "$@"
