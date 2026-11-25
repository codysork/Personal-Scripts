#!/usr/bin/env bash
# Dependency-free test runner. Discovers test_* functions in Tests/test_*.sh.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test-lib.sh
source "$TESTS_DIR/test-lib.sh"

# AI-generated code (unreviewed by a human)
select_test_files() {
    local filter=${1:-}
    local file
    local -a files=()
    for file in "$TESTS_DIR"/test_*.sh; do
        [[ -f "$file" ]] || continue
        if [[ -z "$filter" || "$(basename "$file")" == "$filter" ]]; then
            files+=("$file")
        fi
    done
    printf '%s\n' "${files[@]}"
}

# AI-generated code (unreviewed by a human)
main() {
    local file name status before
    local -a names=()

    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        # shellcheck disable=SC1090
        source "$file"
    done < <(select_test_files "${1:-}")

    while read -r name; do
        names+=("$name")
    done < <(declare -F | awk '{print $3}' | grep '^test_' | sort)

    if (( ${#names[@]} == 0 )); then
        printf 'No tests found.\n' >&2
        return 1
    fi

    for name in "${names[@]}"; do
        CURRENT_TEST=$name
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
