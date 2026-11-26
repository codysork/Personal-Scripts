#!/usr/bin/env bash
# @description Remote deployment tests. SSH, SCP, sudo, id, and install are all
#              shimmed; no test contacts a real host or writes /usr/local/bin.

# @description Verifies that an empty REMOTE_SERVERS list makes the remote phase
#   a no-op even when remote scripts exist.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_install_skips_without_hosts() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    write_remote_config "$repo/config"
    printf '#!/bin/sh\n' > "$repo/remote/tool.sh"
    set_id_shim 0
    allow_install_into_scratch
    allow_remote_install
    run_script_in "$repo" "$repo/install.sh"
    assert_eq "" "$(cat "$SCRATCH/ssh.log" 2>/dev/null)" "ssh log without hosts"
}

# @description Verifies that a host with no remote scripts is never contacted.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_install_skips_without_remote_scripts() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    write_remote_config "$repo/config" "cody@example.test"
    set_id_shim 0
    allow_install_into_scratch
    allow_remote_install
    run_script_in "$repo" "$repo/install.sh"
    assert_eq "" "$(cat "$SCRATCH/ssh.log" 2>/dev/null)" \
        "ssh log without remote scripts"
}

# @description Verifies that one remote script is copied to each configured
#   host exactly once.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_install_copies_to_every_host() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    write_remote_config "$repo/config" "cody@first.test" "cody@second.test"
    printf '#!/bin/sh\n' > "$repo/remote/tool.sh"
    set_id_shim 0
    allow_install_into_scratch
    allow_remote_install
    run_script_in "$repo" "$repo/install.sh"
    assert_eq 2 "$(wc -l < "$SCRATCH/scp.log" 2>/dev/null)" \
        "scp calls for two hosts"
}

# @description Verifies that the remote install command uses the configured
#   destination directory.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_install_uses_configured_directory() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    write_remote_config "$repo/config" "cody@example.test"
    printf '#!/bin/sh\n' > "$repo/remote/tool.sh"
    set_id_shim 0
    allow_install_into_scratch
    allow_remote_install
    run_script_in "$repo" "$repo/install.sh"
    assert_contains "$(cat "$SCRATCH/ssh.log" 2>/dev/null)" \
        "sudo install -m 755 '$SCRATCH/remote-tmp/tool.sh' '$SCRATCH/remote-bin/tool.sh'"
}

# @description Verifies that a rejected remote install is reported by host.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_install_reports_host_failure() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    write_remote_config "$repo/config" "cody@example.test"
    printf '#!/bin/sh\n' > "$repo/remote/tool.sh"
    set_id_shim 0
    allow_install_into_scratch
    fail_remote_install_on "cody@example.test"
    run_script_in "$repo" "$repo/install.sh"
    assert_contains "$(stdout_text)" \
        "Failed to install tool.sh on cody@example.test"
}

# @description Verifies that a remote failure makes the installer exit non-zero.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_install_failure_sets_exit_status() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    write_remote_config "$repo/config" "cody@example.test"
    printf '#!/bin/sh\n' > "$repo/remote/tool.sh"
    set_id_shim 0
    allow_install_into_scratch
    fail_remote_install_on "cody@example.test"
    run_script_in "$repo" "$repo/install.sh"
    assert_eq 1 "$SCRIPT_STATUS" "installer exit status after remote failure"
}

# @description Verifies that one failing host does not prevent later hosts from
#   being attempted.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_install_continues_after_failure() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    write_remote_config "$repo/config" "cody@bad.test" "cody@good.test"
    printf '#!/bin/sh\n' > "$repo/remote/tool.sh"
    set_id_shim 0
    allow_install_into_scratch
    fail_remote_install_on "cody@bad.test"
    run_script_in "$repo" "$repo/install.sh"
    assert_contains "$(cat "$SCRATCH/scp.log" 2>/dev/null)" "cody@good.test"
}

# @description Verifies that the installed config supplies the host list ahead
#   of the repository template.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_install_uses_installed_config() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    mkdir -p "$SCRATCH/xdg/user-scripts"
    write_remote_config "$SCRATCH/xdg/user-scripts/config" "cody@installed.test"
    printf '#!/bin/sh\n' > "$repo/remote/tool.sh"
    set_id_shim 0
    allow_install_into_scratch
    allow_remote_install
    run_script_in "$repo" "$repo/install.sh"
    assert_contains "$(cat "$SCRATCH/scp.log" 2>/dev/null)" \
        "cody@installed.test"
}

# @description Verifies that an explicitly requested but unreadable config is
#   rejected before any installation work.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_remote_install_rejects_unreadable_config() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    printf '#!/bin/sh\n' > "$repo/remote/tool.sh"
    set_id_shim 0
    allow_install_into_scratch
    allow_remote_install
    USER_SCRIPTS_CONFIG="$SCRATCH/missing" \
        run_script_in "$repo" "$repo/install.sh"
    assert_contains "$(stdout_text)" \
        "Config file is not readable: $SCRATCH/missing"
}
