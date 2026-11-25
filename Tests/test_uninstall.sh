#!/usr/bin/env bash
# Uninstall tests. Every run uses a throwaway repo copy, never the real tree.

# AI-generated code (unreviewed by a human)
test_uninstall_help_exits_zero() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh" --help
    assert_eq 0 "$SCRIPT_STATUS" "uninstall help exit status"
}

# AI-generated code (unreviewed by a human)
test_uninstall_help_prints_usage() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh" --help
    assert_contains "$(stdout_text)" "Usage: ./uninstall.sh"
}

# AI-generated code (unreviewed by a human)
test_uninstall_invalid_option_reports_error() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh" --bogus
    assert_contains "$(stdout_text)" "Invalid option --bogus"
}

# AI-generated code (unreviewed by a human)
test_uninstall_non_root_refusal() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 1000
    run_script_in "$repo" "$repo/uninstall.sh"
    assert_contains "$(stdout_text)" "This script must be run as root"
}

# AI-generated code (unreviewed by a human)
test_uninstall_dry_run_reports_intent() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh" --dry-run
    assert_contains "$(stdout_text)" "Would uninstall dummy.css"
}

# AI-generated code (unreviewed by a human)
test_uninstall_dry_run_preserves_file() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh" --dry-run
    assert_file_present "$repo/Style/dummy.css"
}

# AI-generated code (unreviewed by a human)
test_uninstall_removes_nested_file() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh"
    assert_file_absent "$repo/Style/dummy.css"
}

# AI-generated code (unreviewed by a human)
test_uninstall_keeps_own_script() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh"
    assert_file_present "$repo/uninstall.sh"
}
