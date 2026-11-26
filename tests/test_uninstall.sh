#!/usr/bin/env bash
# @description Uninstall tests. Every run uses a throwaway repo copy and an rm
#              shim, so the real /usr/local/bin and repository are untouched.

# @description Verifies that --help exits successfully.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_uninstall_help_exits_zero() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh" --help
    assert_eq 0 "$SCRIPT_STATUS" "uninstall help exit status"
}

# @description Verifies that --help prints the documented usage line.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_uninstall_help_prints_usage() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh" --help
    assert_contains "$(stdout_text)" "Usage: ./uninstall.sh"
}

# @description Verifies that an unsupported option is rejected by name.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_uninstall_invalid_option_reports_error() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 0
    run_script_in "$repo" "$repo/uninstall.sh" --bogus
    assert_contains "$(stdout_text)" "Invalid option --bogus"
}

# @description Verifies that non-root users are refused before any removal.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_uninstall_non_root_refusal() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    set_id_shim 1000
    run_script_in "$repo" "$repo/uninstall.sh"
    assert_contains "$(stdout_text)" "This script must be run as root"
}

# @description Verifies that a dry run names the script it would remove.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_uninstall_dry_run_reports_intent() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    printf '#!/bin/sh\n' > "$SCRATCH/bin/backup.sh"
    set_id_shim 0
    allow_uninstall_into_scratch
    run_script_in "$repo" "$repo/uninstall.sh" --dry-run
    assert_contains "$(stdout_text)" "Would uninstall backup.sh"
}

# @description Verifies that a dry run leaves the installed file in place.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_uninstall_dry_run_preserves_file() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    printf '#!/bin/sh\n' > "$SCRATCH/bin/backup.sh"
    set_id_shim 0
    allow_uninstall_into_scratch
    run_script_in "$repo" "$repo/uninstall.sh" --dry-run
    assert_file_present "$SCRATCH/bin/backup.sh"
}

# @description Verifies that a real run removes a known installed script.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_uninstall_removes_installed_script() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    printf '#!/bin/sh\n' > "$SCRATCH/bin/backup.sh"
    set_id_shim 0
    allow_uninstall_into_scratch
    run_script_in "$repo" "$repo/uninstall.sh"
    assert_file_absent "$SCRATCH/bin/backup.sh"
}

# @description Verifies that an unrelated installed file is not removed.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_uninstall_preserves_unrelated_file() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    printf '#!/bin/sh\n' > "$SCRATCH/bin/unrelated.sh"
    set_id_shim 0
    allow_uninstall_into_scratch
    run_script_in "$repo" "$repo/uninstall.sh"
    assert_file_present "$SCRATCH/bin/unrelated.sh"
}

# @description Verifies that scripts inside the repo copy survive uninstall,
#   pinning the fix over the old nested-directory deletion behavior.
# @return Status of the final assertion: 0 on pass, 1 on failure.
# AI-generated code (unreviewed by a human)
test_uninstall_preserves_repository_files() {
    local repo="$SCRATCH/repo-copy"
    make_repo_copy "$repo"
    printf '#!/bin/sh\n' > "$repo/local/dummy.sh"
    set_id_shim 0
    allow_uninstall_into_scratch
    run_script_in "$repo" "$repo/uninstall.sh"
    assert_file_present "$repo/local/dummy.sh"
}
