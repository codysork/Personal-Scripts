#!/usr/bin/env bash
# Dependency-free test runner. Discovers test_* functions in Tests/test_*.sh.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TESTS_DIR/test-lib.sh"

# @description Reports whether a discovered test file belongs in the selection:
#   it must be a regular file and, when a filter is supplied, match that
#   basename. Keeping the rule separate lets discovery stay a simple loop.
# @param $1 Candidate test file path.
# @param $2 Optional basename filter; empty selects every file.
# @return 0 when the file should be selected, 1 otherwise.
is_selected_test_file() {
    local file=$1
    local filter=$2
    [[ -f "$file" ]] || return 1
    [[ -z "$filter" || "$(basename "$file")" == "$filter" ]]
}

# @description Builds the list of test files to source. Without a filter every
#   Tests/test_*.sh file is selected; with a basename filter (run.sh test_x.sh)
#   only that suite is selected.
# @param $1 Optional basename filter, e.g. test_config.sh.
# @return 0; selected file paths are printed one per line to stdout.
select_test_files() {
    local filter=${1:-}
    local file
    local -a files=()
    for file in "$TESTS_DIR"/test_*.sh; do
        if is_selected_test_file "$file" "$filter"; then
            files+=("$file")
        fi
    done
    printf '%s\n' "${files[@]}"
}

# @description Loads the selected suites and runs each test_* function. Every
#   test gets a fresh scratch tree so state cannot leak between tests. A test
#   passes only when it exits 0 and leaves FAIL_COUNT unchanged; the final line
#   prints totals and the overall status mirrors FAIL_COUNT for CI use.
# @param $@ Arguments forwarded to select_test_files (optional file filter).
# @return 0 when no assertion failed, 1 otherwise.
# AI-generated code (unreviewed by a human)
main() {
    local file name status before
    local -a names=()

    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        # Sourcing registers each suite's test_* definitions in this shell.
        # shellcheck disable=SC1090
        source "$file"
    done < <(select_test_files "${1:-}")

    # declare -F lists loaded functions; keeping only test_ names gives the
    # runner its test set without a separate registry to maintain.
    while read -r name; do
        names+=("$name")
    done < <(declare -F | awk '{print $3}' | grep '^test_' | sort)

    if (( ${#names[@]} == 0 )); then
        printf 'No tests found.\n' >&2
        return 1
    fi

    for name in "${names[@]}"; do
        CURRENT_TEST=$name
        # Snapshot the counter so an assertion failure is reported even if the
        # test function itself returns 0.
        before=$FAIL_COUNT
        setup_scratch
        "$name"
        status=$?
        teardown_scratch
        if (( status == 0 && FAIL_COUNT == before )); then
            printf 'PASS %s\n' "$name"
        elif (( FAIL_COUNT == before )); then
            printf 'FAIL %s (test returned %d)\n' "$name" "$status"
        fi
    done

    printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
    (( FAIL_COUNT == 0 ))
}

main "$@"
