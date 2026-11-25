#!/usr/bin/env bash
# Install tests. The install and id shims keep every write inside the scratch
# tree; -o/-g ownership flags are dropped because the harness runs unprivileged.

# @description Verifies that install.sh refuses to run for a non-root user,
#   using the id stub to simulate UID 1000.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_install_non_root_refusal() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 1000
    run_script_in "$repo" "$repo/install.sh"
    assert_contains "$(stdout_text)" "This script must be run as root."
}

# @description Verifies that install deploys the four runnable scripts while
#   skipping install.sh and uninstall.sh. The install shim redirects the target
#   directory into the scratch tree so the real /usr/local/bin is untouched.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_install_places_only_runnable_scripts() {
    local repo="$SCRATCH/repo-copy"
    local installed
    make_repo_copy "$repo"
    set_id_shim 0
    allow_install_into_scratch
    run_script_in "$repo" "$repo/install.sh"
    installed=$(cd "$SCRATCH/bin" && printf '%s\n' *.sh | tr '\n' ' ')
    assert_eq \
        "arch-maintenance.sh backup.sh git-checker.sh maintenance-reminder.sh " \
        "$installed" "installed script names"
}

# @description Verifies that a fresh install places the config template in the
#   user's XDG config directory without needing an existing config.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
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
# AI-generated code (unreviewed by a human)
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
# AI-generated code (unreviewed by a human)
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
# AI-generated code (unreviewed by a human)
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
