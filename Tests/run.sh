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

# @description Sources every selected suite into the current shell so their
#   test_* definitions become available to the runner. Empty paths are skipped
#   because no suite can be loaded from them.
# @param $1 Optional basename filter forwarded to select_test_files.
# @return 0.
load_test_suites() {
    local file
    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        # Sourcing registers each suite's test_* definitions in this shell.
        # shellcheck disable=SC1090
        source "$file"
    done < <(select_test_files "${1:-}")
}

# @description Lists loaded test_* functions in sorted order so the runner
#   discovers its test set without a separate registry to maintain.
# @return 0; one function name per line on stdout.
list_test_names() {
    declare -F | awk '{print $3}' | grep '^test_' | sort
}

# @description Prints a test's outcome from its exit status and the assertion
#   counter captured before it ran. A nonzero exit is not reported as a failure
#   when an assertion already recorded the problem.
# @param $1 Name of the test.
# @param $2 Exit status returned by the test function.
# @param $3 FAIL_COUNT value before the test ran.
# @return 0; PASS or FAIL text is printed to stdout.
report_test_outcome() {
    local name=$1
    local status=$2
    local before=$3
    if (( status == 0 && FAIL_COUNT == before )); then
        printf 'PASS %s\n' "$name"
    elif (( FAIL_COUNT == before )); then
        printf 'FAIL %s (test returned %d)\n' "$name" "$status"
    fi
}

# @description Runs one test in a fresh scratch tree and reports its outcome.
#   The assertion counter is snapshotted first so a test that returns 0 after a
#   failed assertion is still reported as a failure.
# @param $1 Name of the test function to call.
# @return 0; the outcome is printed by report_test_outcome.
run_single_test() {
    local name=$1
    local before=$FAIL_COUNT
    local status

    CURRENT_TEST=$name
    setup_scratch
    "$name"
    status=$?
    teardown_scratch
    report_test_outcome "$name" "$status" "$before"
}

# @description Loads the selected suites and runs each test_* function. Every
#   test gets a fresh scratch tree so state cannot leak between tests. A test
#   passes only when it exits 0 and leaves FAIL_COUNT unchanged; the final line
#   prints totals and the overall status mirrors FAIL_COUNT for CI use.
# @param $@ Arguments forwarded to select_test_files (optional file filter).
# @return 0 when no assertion failed, 1 otherwise.
main() {
    local name
    local -a names=()

    load_test_suites "${1:-}"

    while read -r name; do
        names+=("$name")
    done < <(list_test_names)

    if (( ${#names[@]} == 0 )); then
        printf 'No tests found.\n' >&2
        return 1
    fi

    for name in "${names[@]}"; do
        run_single_test "$name"
    done

    printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
    (( FAIL_COUNT == 0 ))
}

main "$@"
