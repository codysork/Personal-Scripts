#!/usr/bin/env bash
# @description Shared helpers for the dependency-free test harness. Each test
#              runs in a disposable scratch tree with local shims so no test
#              touches the real $HOME, /usr/local/bin, a notification daemon,
#              or SSH.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

# Scratch tree, shim directory, and captured output paths. Recreated by
# setup_scratch before each test.
SCRATCH=""
STUB_BIN=""
STDOUT_FILE=""
STDERR_FILE=""
SCRIPT_STATUS=0

# Harness bookkeeping: assertion totals and the currently executing test.
PASS_COUNT=0
FAIL_COUNT=0
CURRENT_TEST=""

# @description Removes config variables from the harness environment so a
#   developer's own settings cannot change test outcomes. The scripts under
#   test substitute defaults when these variables are unset.
# @return 0.
clear_inherited_config() {
    unset ARCHIVE_HEADER BACKUP_DIR BACKUP_SOURCES EXCLUDES \
        DAYS_DUE SERVER SERVER_USER SSH_TIMEOUT REMOTE_STATE_DIR \
        STATE_DIR SEARCH_DIR IGNORE_DIRS MAX_BACKUP_AGE_DAYS \
        MIN_SNAPSHOTS MAX_SNAPSHOT_AGE_DAYS GIT_CHECKER \
        USER_SCRIPTS_CONFIG
}

# @description Creates an executable stub named from stdin under $STUB_BIN.
#   Stubs are prepended to PATH so tests replace external tools (notify-send,
#   ssh, sudo, install, id) without touching the real system.
# @param $1 Basename of the stub to create.
# @return 0 when the stub was written and made executable.
write_shim() {
    local name=$1
    local path="$STUB_BIN/$name"
    cat > "$path"
    chmod +x "$path"
}

# @description Installs the baseline stubs used by every test. Notifications
#   and SSH calls are logged into the scratch tree instead of reaching a real
#   daemon or host; SSH always fails so remote checks are off by default, and
#   sudo simply runs its arguments. Individual scenarios override a stub.
# @return 0.
create_default_shims() {
    # Record notification attempts for assertions instead of displaying them.
    write_shim notify-send <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$SCRATCH/notify.log"
EOF
    # Log remote calls and fail them, keeping tests offline and deterministic.
    write_shim ssh <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$SCRATCH/ssh.log"
exit 1
EOF
    # No notification daemon is running until a test overrides this stub.
    write_shim pgrep <<'EOF'
#!/bin/sh
exit 1
EOF
    # Pass through unchanged; the install shim handles path redirection.
    write_shim sudo <<'EOF'
#!/bin/sh
exec "$@"
EOF
}

# @description Prepares a fresh isolated environment before each test: clears
#   inherited config, creates a temporary directory with the subdirectories the
#   scripts expect (config, state, source, output), and installs default stubs.
# @return 0.
setup_scratch() {
    clear_inherited_config
    SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/scripts-tests.XXXXXX")
    STUB_BIN="$SCRATCH/stub"
    mkdir -p "$STUB_BIN" "$SCRATCH/bin" "$SCRATCH/home" \
        "$SCRATCH/out" "$SCRATCH/state" "$SCRATCH/src" "$SCRATCH/xdg"
    create_default_shims
}

# @description Deletes the scratch tree after a test and clears the related
#   globals so leftover files or paths cannot affect later tests.
# @return 0.
teardown_scratch() {
    if [[ -n "$SCRATCH" && -d "$SCRATCH" ]]; then
        rm -rf "$SCRATCH"
    fi
    SCRATCH=""
    STUB_BIN=""
}

# @description Runs a script from a chosen working directory with a sandboxed
#   HOME, XDG config/state, and PATH that prefers the local stubs. Output is
#   captured to files so tests can assert on stdout and stderr separately.
# @param $1 Directory to run from (repo root or a scratch copy).
# @param $2 Path of the script to execute.
# @param $@ Any remaining arguments are passed to the script.
# @return The script's exit status, also stored in SCRIPT_STATUS.
run_script_in() {
    local dir=$1
    local script=$2
    shift 2
    STDOUT_FILE="$SCRATCH/stdout"
    STDERR_FILE="$SCRATCH/stderr"
    # The subshell keeps directory and environment overrides local to the
    # script under test rather than changing the harness itself.
    (
        cd "$dir" || exit 99
        HOME="$SCRATCH/home" \
        XDG_CONFIG_HOME="$SCRATCH/xdg" \
        XDG_STATE_HOME="$SCRATCH/state" \
        USER_SCRIPTS_CONFIG="${USER_SCRIPTS_CONFIG:-}" \
        PATH="$STUB_BIN:$PATH" \
            bash "$script" "$@"
    ) >"$STDOUT_FILE" 2>"$STDERR_FILE"
    SCRIPT_STATUS=$?
    return "$SCRIPT_STATUS"
}

# @description Convenience wrapper that runs a script from the repository root,
#   the normal working directory for tests that do not need a copied tree.
# @param $@ Script path followed by its arguments (see run_script_in).
# @return The script's exit status.
run_script() {
    run_script_in "$REPO_ROOT" "$@"
}

# @description Prints the stdout captured by the most recent script run.
# @return 0.
stdout_text() {
    cat "$STDOUT_FILE"
}

# @description Prints the stderr captured by the most recent script run.
# @return 0.
stderr_text() {
    cat "$STDERR_FILE"
}

# @description Writes a backup config that points into the scratch tree. The
#   archive header is written with ${ARCHIVE_HEADER:-$header} so a test can
#   override it through the environment and verify precedence rules.
# @param $1 Path of the config file to create.
# @param $2 Default archive header when ARCHIVE_HEADER is unset.
# @return 0.
write_config() {
    local path=$1
    local header=$2
    cat > "$path" <<EOF
BACKUP_DIR="$SCRATCH/out"
BACKUP_SOURCES=("$SCRATCH/src")
EXCLUDES=()
ARCHIVE_HEADER="\${ARCHIVE_HEADER:-$header}"
EOF
}

# @description Writes a maintenance-reminder config pointed at scratch state.
#   Values that scripts allow to be overridden expand from the environment so
#   tests can exercise DAYS_DUE, SERVER, SERVER_USER, and SSH_TIMEOUT changes.
# @param $1 Path of the config file to create.
# @return 0.
write_reminder_config() {
    local path=$1
    cat > "$path" <<EOF
STATE_DIR="$SCRATCH/state"
DAYS_DUE="\${DAYS_DUE:-6}"
SERVER="\${SERVER-}"
SERVER_USER="\${SERVER_USER-cody}"
SSH_TIMEOUT="\${SSH_TIMEOUT:-5}"
REMOTE_STATE_DIR=".local/state/arch-maintenance"
EOF
}

# @description Replaces the pgrep stub with one that succeeds, simulating a
#   running notification daemon for tests that pass --notify-send.
# @return 0.
allow_notification_daemon() {
    write_shim pgrep <<'EOF'
#!/bin/sh
exit 0
EOF
}

# @description Installs an id stub that reports a chosen UID, letting tests
#   exercise root-only guards without actually changing users.
# @param $1 UID value the stub should print.
# @return 0.
set_id_shim() {
    local uid=$1
    write_shim id <<EOF
#!/bin/sh
echo "$uid"
EOF
}

# @description Replaces the install stub so writes to /usr/local/bin land in
#   $SCRATCH/bin and -o/-g ownership flags are dropped, since the harness runs
#   unprivileged. Used by the install tests to keep the real system untouched.
# @return 0.
allow_install_into_scratch() {
    write_shim install <<EOF
#!/usr/bin/env bash
args=()
while ((\$#)); do
    arg=\$1
    shift
    case "\$arg" in
        -o|-g) shift ;;
        /usr/local/bin) args+=("$SCRATCH/bin") ;;
        *) args+=("\$arg") ;;
    esac
done
exec /usr/bin/install "\${args[@]}"
EOF
}

# @description Copies the scripts and config into a throwaway repo under the
#   scratch tree and adds a Style/dummy.css sentinel. Install and uninstall
#   tests run against this copy so the real checkout is never modified.
# @param $1 Destination directory for the copy.
# @return 0.
make_repo_copy() {
    local target=$1
    mkdir -p "$target/Style"
    cp "$REPO_ROOT"/*.sh "$REPO_ROOT/config" "$target/"
    printf 'sentinel\n' > "$target/Style/dummy.css"
}

# @description Compares two values and records exactly one pass or failure,
#   printing a quoted expected/actual diagnostic on mismatch.
# @param $1 Expected value.
# @param $2 Actual value.
# @param $3 Optional message describing the assertion ("values differ" by default).
# @return 0 on match, 1 on mismatch.
assert_eq() {
    local expected=$1
    local actual=$2
    local message=${3:-"values differ"}
    if [[ "$expected" == "$actual" ]]; then
        ((PASS_COUNT += 1))
        return 0
    fi
    ((FAIL_COUNT += 1))
    printf 'FAIL %s: %s\n  expected: %q\n  actual:   %q\n' \
        "$CURRENT_TEST" "$message" "$expected" "$actual"
    return 1
}

# @description Checks that a string contains a substring and records one pass
#   or failure, showing the full text when the substring is missing.
# @param $1 Haystack (text to search).
# @param $2 Needle (substring expected to be present).
# @param $3 Optional message ("missing expected text" by default).
# @return 0 when found, 1 otherwise.
assert_contains() {
    local haystack=$1
    local needle=$2
    local message=${3:-"missing expected text"}
    if [[ "$haystack" == *"$needle"* ]]; then
        ((PASS_COUNT += 1))
        return 0
    fi
    ((FAIL_COUNT += 1))
    printf 'FAIL %s: %s\n  expected to contain: %q\n  actual:\n%s\n' \
        "$CURRENT_TEST" "$message" "$needle" "$haystack"
    return 1
}

# @description Records a pass when a path exists and a failure with the missing
#   path printed when it does not.
# @param $1 Path expected to exist.
# @return 0 when present, 1 otherwise.
assert_file_present() {
    local path=$1
    if [[ -e "$path" ]]; then
        ((PASS_COUNT += 1))
        return 0
    fi
    ((FAIL_COUNT += 1))
    printf 'FAIL %s: expected path to exist: %s\n' "$CURRENT_TEST" "$path"
    return 1
}

# @description Records a pass when a path is absent and a failure with the
#   unexpected path printed when it exists.
# @param $1 Path expected to be absent.
# @return 0 when absent, 1 otherwise.
assert_file_absent() {
    local path=$1
    if [[ ! -e "$path" ]]; then
        ((PASS_COUNT += 1))
        return 0
    fi
    ((FAIL_COUNT += 1))
    printf 'FAIL %s: expected path to be absent: %s\n' "$CURRENT_TEST" "$path"
    return 1
}

# @description Records a pass when a glob matches nothing. Used to prove that a
#   dry run created no archive files.
# @param $1 Glob pattern that must have no matches.
# @return 0 when there are no matches, 1 when any match exists.
assert_no_files_matching() {
    local pattern=$1
    local matches
    matches=$(compgen -G "$pattern" || true)
    if [[ -z "$matches" ]]; then
        ((PASS_COUNT += 1))
        return 0
    fi
    ((FAIL_COUNT += 1))
    printf 'FAIL %s: unexpected matches for %s: %s\n' \
        "$CURRENT_TEST" "$pattern" "$matches"
    return 1
}
