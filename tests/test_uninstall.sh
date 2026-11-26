#!/usr/bin/env bash
# @description Uninstall tests. Every run uses a throwaway repo copy, never the
#              real tree.

# @description Verifies that --help exits successfully on a throwaway repo
#   copy, so the test never touches the real checkout.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_uninstall_help_exits_zero() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh" --help
    assert_eq 0 "$SCRIPT_STATUS" "uninstall help exit status"
}

# @description Verifies that --help prints the documented usage line.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_uninstall_help_prints_usage() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh" --help
    assert_contains "$(stdout_text)" "Usage: ./uninstall.sh"
}

# @description Verifies that an unknown option is reported by name so the user
#   can spot the typo, rather than being silently ignored.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_uninstall_invalid_option_reports_error() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh" --bogus
    assert_contains "$(stdout_text)" "Invalid option --bogus"
}

# @description Verifies that uninstall.sh refuses to run for a non-root user,
#   simulated with the id stub reporting UID 1000.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_uninstall_non_root_refusal() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 1000
    run_script_in "$repo" "$repo/uninstall.sh"
    assert_contains "$(stdout_text)" "This script must be run as root"
}

# @description Verifies that --dry-run reports each file it would remove using
#   "Would uninstall" wording, without performing the removal.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_uninstall_dry_run_reports_intent() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh" --dry-run
    assert_contains "$(stdout_text)" "Would uninstall dummy.css"
}

# @description Verifies the other half of the dry-run contract: the sentinel
#   file is still present after the run.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_uninstall_dry_run_preserves_file() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh" --dry-run
    assert_file_present "$repo/Style/dummy.css"
}

# @description Verifies that a real run deletes files in nested directories,
#   which is the script's purpose: it walks every subdirectory of the repo.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_uninstall_removes_nested_file() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh"
    assert_file_absent "$repo/Style/dummy.css"
}

# @description Verifies that uninstall.sh exempts itself from deletion so the
#   script can finish its loop and remain available to the user.
# @return Status of the final assertion: 0 on pass, 1 on failure.
test_uninstall_keeps_own_script() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh"
    assert_file_present "$repo/uninstall.sh"
}
