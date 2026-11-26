#!/usr/bin/env bash
# @description Install tests. The install and id shims keep every write inside
#              the scratch tree; -o/-g ownership flags are dropped because the
#              harness runs unprivileged.

# @description Verifies that install.sh refuses to run for a non-root user,
#   using the id stub to simulate UID 1000.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_install_non_root_refusal() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 1000
    run_script_in "$repo" "$repo/install.sh"
    assert_contains "$(stdout_text)" "This script must be run as root."
}

# @description Lists the scripts install.sh should deploy from a repo copy.
#   Only install.sh and uninstall.sh are excluded; every other script in the
#   copy is expected to be placed in /usr/local/bin by a successful install.
# @param $1 Path to the repo copy to inspect.
# @return 0; script names are printed one per line.
expected_installed_scripts() {
    local repo=$1
    local script
    (
        cd "$repo" || exit 99
        for script in local/*.sh; do
            [ -f "$script" ] || continue
            case "${script#local/}" in
                install.sh|uninstall.sh) continue ;;
            esac
            printf '%s\n' "${script#local/}"
        done
    ) | sort
}

# @description Lists the scripts install.sh actually placed in the shimmed
#   target directory for the current test.
# @return 0; script names are printed one per line.
installed_scripts() {
    (cd "$SCRATCH/bin" && printf '%s\n' *.sh) | sort
}

# @description Verifies that install deploys every runnable script in a
#   synthetic repo while skipping install.sh and uninstall.sh. The fixture owns
#   its scripts and config, so the result does not depend on the real repo.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_install_places_only_runnable_scripts() {
    local repo="$SCRATCH/repo-copy"
    mkdir -p "$repo/local"
    # Only install.sh is the code under test; the rest are inert fixtures.
    cp "$REPO_ROOT/install.sh" "$repo/install.sh"
    printf '#!/bin/sh\n' > "$repo/uninstall.sh"
    printf '#!/bin/sh\n' > "$repo/local/first-tool.sh"
    printf '#!/bin/sh\n' > "$repo/local/second-tool.sh"
    set_id_shim 0
    allow_install_into_scratch
    run_script_in "$repo" "$repo/install.sh"
    assert_eq \
        "$(expected_installed_scripts "$repo")" \
        "$(installed_scripts)" "installed script names"
}

# @description Verifies that a fresh install places the config template in the
#   user's XDG config directory without needing an existing config.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_install_deploys_config_template() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    allow_install_into_scratch
    run_script_in "$repo" "$repo/install.sh"
    assert_file_present "$SCRATCH/xdg/user-scripts/config"
}

# @description Verifies that an existing user-edited config is not overwritten;
#   install.sh should offer the template as config.new instead.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_install_preserves_existing_config() {
    local repo="$SCRATCH/repo-copy"
    local config_dir="$SCRATCH/xdg/user-scripts"
    make_repo_copy "$repo"
    mkdir -p "$config_dir"
    printf 'KEEPME\n' > "$config_dir/config"
    set_id_shim 0
    allow_install_into_scratch
    run_script_in "$repo" "$repo/install.sh"
    assert_contains "$(cat "$config_dir/config")" "KEEPME"
}

# @description Verifies that a legacy config.conf is moved aside during
#   install, preventing the old file from shadowing the new config.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_install_migrates_legacy_config() {
    local repo="$SCRATCH/repo-copy"
    local config_dir="$SCRATCH/xdg/user-scripts"
    make_repo_copy "$repo"
    mkdir -p "$config_dir"
    printf 'KEEPLEGACY\n' > "$config_dir/config.conf"
    set_id_shim 0
    allow_install_into_scratch
    run_script_in "$repo" "$repo/install.sh"
    assert_file_absent "$config_dir/config.conf"
}

# @description Verifies that migration preserves the legacy file's contents in
#   the new config location rather than replacing them with template defaults.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_install_keeps_migrated_values() {
    local repo="$SCRATCH/repo-copy"
    local config_dir="$SCRATCH/xdg/user-scripts"
    make_repo_copy "$repo"
    mkdir -p "$config_dir"
    printf 'KEEPLEGACY\n' > "$config_dir/config.conf"
    set_id_shim 0
    allow_install_into_scratch
    run_script_in "$repo" "$repo/install.sh"
    assert_contains "$(cat "$config_dir/config")" "KEEPLEGACY"
}
