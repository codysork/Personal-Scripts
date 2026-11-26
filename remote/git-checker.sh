#!/usr/bin/env bash
#
# @file git-checker.sh
# @author Cody Sork <codysork@gmail.com> with help from ChatGPT
# @created 2026-11-03
# @modified 2026-11-25
# @description Checks Git repositories under the configured search directory on
#              a server, using settings from the installed remote config or the
#              repository template.

set -uo pipefail

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

# @description Loads server settings from USER_SCRIPTS_CONFIG, the installed
#   config, or the repository's remote/config template, in that order. An
#   explicitly requested unreadable config is an error; missing files fall
#   through to the next location.
# @return 0; exits 1 when an explicitly requested config cannot be read.
# AI-generated code (unreviewed by a human)
load_remote_config() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/user-scripts"
    local repo_dir candidate
    local path="${USER_SCRIPTS_CONFIG:-}"

    repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

    if [[ -z "$path" ]]; then
        for candidate in \
            "$config_dir/config" \
            "$config_dir/config.conf" \
            "$repo_dir/remote/config"; do
            if [[ -r "$candidate" ]]; then
                path=$candidate
                break
            fi
        done
    fi

    if [[ -n "$path" ]]; then
        if [[ ! -r "$path" ]]; then
            printf 'Error: Config file is not readable: %s\n' "$path" >&2
            exit 1
        fi
        # shellcheck disable=SC1090
        source "$path"
    fi
}

load_remote_config

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

    while IFS= read -r -d '' dir; do
        # Prune ignored directories.
        if is_ignored "$dir"; then
            continue
        fi

        # Skip nested repositories.
        if [[ -d "$dir/.git" || -f "$dir/.git" ]]; then
            printf '%s\0' "$dir"
            continue
        fi

        # Continue searching.
    done < <(
        find "$SEARCH_DIR" \
            -type d \
            \( -name .git -prune \) -o \
            \( -type d -print0 \)
    )
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
