#!/usr/bin/env bash
# Shared helpers for the dependency-free test harness.
# Each test runs in a disposable scratch tree with local shims so no test
# touches the real $HOME, /usr/local/bin, a notification daemon, or SSH.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

SCRATCH=""
STUB_BIN=""
STDOUT_FILE=""
STDERR_FILE=""
SCRIPT_STATUS=0

PASS_COUNT=0
FAIL_COUNT=0
CURRENT_TEST=""

# AI-generated code (unreviewed by a human)
clear_inherited_config() {
    unset ARCHIVE_HEADER BACKUP_DIR BACKUP_SOURCES EXCLUDES \
        DAYS_DUE SERVER SERVER_USER SSH_TIMEOUT REMOTE_STATE_DIR \
        STATE_DIR SEARCH_DIR IGNORE_DIRS MAX_BACKUP_AGE_DAYS \
        MIN_SNAPSHOTS MAX_SNAPSHOT_AGE_DAYS GIT_CHECKER \
        USER_SCRIPTS_CONFIG
}

# AI-generated code (unreviewed by a human)
create_default_shims() {
    cat > "$STUB_BIN/notify-send" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$SCRATCH/notify.log"
EOF
    cat > "$STUB_BIN/ssh" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$SCRATCH/ssh.log"
exit 1
EOF
    cat > "$STUB_BIN/pgrep" <<'EOF'
#!/bin/sh
exit 1
EOF
    cat > "$STUB_BIN/sudo" <<'EOF'
#!/bin/sh
exec "$@"
EOF
    chmod +x "$STUB_BIN/notify-send" "$STUB_BIN/ssh" \
        "$STUB_BIN/pgrep" "$STUB_BIN/sudo"
}

# AI-generated code (unreviewed by a human)
setup_scratch() {
    clear_inherited_config
    SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/scripts-tests.XXXXXX")
    STUB_BIN="$SCRATCH/stub"
    mkdir -p "$STUB_BIN" "$SCRATCH/bin" "$SCRATCH/home" \
        "$SCRATCH/out" "$SCRATCH/state" "$SCRATCH/src" "$SCRATCH/xdg"
    create_default_shims
}

# AI-generated code (unreviewed by a human)
teardown_scratch() {
    if [[ -n "$SCRATCH" && -d "$SCRATCH" ]]; then
        rm -rf "$SCRATCH"
    fi
    SCRATCH=""
    STUB_BIN=""
}

# AI-generated code (unreviewed by a human)
run_script_in() {
    local dir=$1
    local script=$2
    shift 2
    STDOUT_FILE="$SCRATCH/stdout"
    STDERR_FILE="$SCRATCH/stderr"
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

# AI-generated code (unreviewed by a human)
run_script() {
    run_script_in "$REPO_ROOT" "$@"
}

# AI-generated code (unreviewed by a human)
stdout_text() {
    cat "$STDOUT_FILE"
}

# AI-generated code (unreviewed by a human)
stderr_text() {
    cat "$STDERR_FILE"
}

# AI-generated code (unreviewed by a human)
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

# AI-generated code (unreviewed by a human)
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

# AI-generated code (unreviewed by a human)
allow_notification_daemon() {
    cat > "$STUB_BIN/pgrep" <<'EOF'
#!/bin/sh
exit 0
EOF
    chmod +x "$STUB_BIN/pgrep"
}

# AI-generated code (unreviewed by a human)
set_id_shim() {
    local uid=$1
    cat > "$STUB_BIN/id" <<EOF
#!/bin/sh
echo "$uid"
EOF
    chmod +x "$STUB_BIN/id"
}

# AI-generated code (unreviewed by a human)
allow_install_into_scratch() {
    cat > "$STUB_BIN/install" <<EOF
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
    chmod +x "$STUB_BIN/install"
}

# AI-generated code (unreviewed by a human)
make_repo_copy() {
    local target=$1
    mkdir -p "$target/Style"
    cp "$REPO_ROOT"/*.sh "$REPO_ROOT/config" "$target/"
    printf 'sentinel\n' > "$target/Style/dummy.css"
}

# AI-generated code (unreviewed by a human)
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

# AI-generated code (unreviewed by a human)
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

# AI-generated code (unreviewed by a human)
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

# AI-generated code (unreviewed by a human)
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

# AI-generated code (unreviewed by a human)
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
