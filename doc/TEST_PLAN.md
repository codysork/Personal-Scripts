# Test Plan — personal shell-script suite

## 1. Scope and conventions

This plan covers the six root scripts (`install.sh`, `uninstall.sh`, `backup.sh`,
`arch-maintenance.sh`, `maintenance-reminder.sh`, `git-checker.sh`) and the shared
`config` template. `Convenience/`, `Maintenance/`, and `System/` are empty;
`Style/` holds only CSS/pywal assets, so there is nothing to test there.

This repository intentionally has **no automated test suite**. Verification is by
**manual smoke checks** in a pseudo-terminal (`script -q /dev/null -c '...'`,
tmux, or an interactive terminal), because `arch-maintenance.sh` branches on
`[[ -t 1 ]]` for colored output. Every scenario makes **one observable
assertion**. Run nothing against the real `$HOME`, real `/usr/local/bin`, or a
real notification daemon / SSH server.

`README.md` is the behavioral contract. Notation used below:

- `$S` — a disposable scratch root under `/tmp/opencode/`.
- `$STUB` — a scratch directory of tiny local shims placed first on `PATH`.
- `cfg-A`, `cfg-B` — scratch config files with distinct `ARCHIVE_HEADER` values.

## 2. Safety rules and scratch harness

Safe to run in isolation: `--help`, config-error exits, `backup.sh --dry-run`
with a scratch config, `git-checker.sh` with a scratch `SEARCH_DIR` and local
path-based remotes, `maintenance-reminder.sh` with `SERVER=""` plus a scratch
`STATE_DIR` and a `notify-send` shim, and `uninstall.sh --dry-run` **only from a
copy of the repo**.

Never run without isolation: `install.sh` (writes `/usr/local/bin`, needs root),
`uninstall.sh` without `--dry-run` (deletes nested files of the current working
directory), real `backup.sh` archives (tar/gzip/pv I/O), any `--notify-send`
path (desktop popups), `maintenance-reminder.sh` with `SERVER` set (real SSH),
`arch-maintenance.sh` (system commands, `sudo`, state writes), and
`git-checker.sh` with the default config (scans `$HOME`, fetches real remotes).

```bash
S=/tmp/opencode/scripts-tests
STUB=$S/stub
mkdir -p "$STUB" "$S/bin" "$S/xdg" "$S/home" "$S/src" "$S/out" "$S/state"
# pv shim: pass data through without the real pv binary
printf '#!/bin/sh\nexec cat\n' > "$STUB/pv"
chmod +x "$STUB/pv"
# Copy the repo so install/uninstall work on a throwaway tree.
cp -a /home/cody/Scripts "$S/repo-copy"
```

### Config files used by the scenarios

Both scratch configs must set `BACKUP_DIR="$S/out"`,
`BACKUP_SOURCES=("$S/src")`, and `EXCLUDES=()`; only `ARCHIVE_HEADER` differs
(`A` in `cfg-A`, `B` in `cfg-B`). Dry runs assert on the stdout line
`Backup would be created: $S/out/<header>-<timestamp>.tar.gz`.

## 3. P0 — config resolution, install, uninstall, backup, reminder

### 3.1 Config resolution (shared logic)

1. **Environment beats config.** With `cfg-A`, run `ARCHIVE_HEADER=envhdr
   backup.sh --dry-run -c $S/cfg-A`. Expect header `envhdr`, never `A`.
2. **`-c` beats `USER_SCRIPTS_CONFIG`.** Run `USER_SCRIPTS_CONFIG=$S/cfg-A
   backup.sh --dry-run -c $S/cfg-B`. Expect header `B`.
3. **Long forms parse.** Run `--config-file $S/cfg-B` and
   `--config-file=$S/cfg-B` as two separate runs. Expect header `B` each time.
4. **Installed config beats legacy.** With `XDG_CONFIG_HOME=$S/xdg`, create both
   `$S/xdg/user-scripts/config` (header `installed`) and `config.conf` (header
   `legacy`). Expect header `installed`.
5. **Legacy fallback.** With only `config.conf` present (header `legacy`),
   expect header `legacy`.
6. **Repo template fallback.** With `XDG_CONFIG_HOME=$S/empty-xdg`, a fresh
   `HOME=$S/home` with the eight template source directories created, and
   `BACKUP_DIR=$S/out` exported, run the script from the repo. Expect header
   `sorkhackmac16-backup` and no `Source directory not found`.
7. **Unreadable config.** `backup.sh --dry-run -c $S/missing`. Expect
   `Error: Config file is not readable: ...` and exit 1.
8. **Missing `-c` value.** Run `backup.sh -c` and `backup.sh --config-file=`
   separately. Expect `Error: -c requires a config file.` /
   `Error: --config-file requires a config file.` and exit 2.
9. **Options after `-c` still parse.** `backup.sh -c $S/cfg-B --dry-run`.
   Expect the dry-run success line, not a usage error.
10. **Same contract in the other three scripts.** Run
    `arch-maintenance.sh -c $S/missing` and
    `maintenance-reminder.sh -c $S/missing` (and `git-checker.sh`). Expect each
    to exit 1 with the same "not readable" message before doing work.

### 3.2 install.sh — all runs from `$S/repo-copy`

Shim `id` (reports uid 0 plus a synthetic uid/gid), `sudo` (`exec "$@"`),
`install` (logs arguments and rewrites `/usr/local/bin` → `$S/bin`), and `getent`
(synthetic passwd line pointing at `$S/home`). Put `$STUB` first on `PATH` and
set `XDG_CONFIG_HOME=$S/xdg`.

1. **Fresh placement.** Expect `$S/bin` to contain exactly
    `arch-maintenance.sh`, `backup.sh`, `git-checker.sh`, and
    `maintenance-reminder.sh` — not `install.sh` or `uninstall.sh`.
2. **Fresh config deployment.** Expect `$S/xdg/user-scripts/config` to exist
    with mode 644, stdout `Installed config template`, and no `config.new`.
3. **Existing config preserved.** Pre-seed `config` with `KEEPME` and reinstall.
    Expect `KEEPME` intact, `config.new` created, stdout
    `Config already exists; wrote updated template`.
4. **Legacy migration.** Pre-seed only `config.conf` with `KEEPLEGACY`. Expect
    `config.conf` gone, `config` holding `KEEPLEGACY`, stdout
    `Migrated legacy config`, plus `config.new`.
5. **XDG_CONFIG_HOME under sudo.** Expect the config to land under
    `$S/xdg/user-scripts`, not `$S/home/.config/user-scripts`.
6. **Non-root refusal.** Without the `id` shim, expect
    `[FAIL] This script must be run as root.`, exit 1, and `$S/bin` untouched.

### 3.3 uninstall.sh — never run from `/home/cody/Scripts`

1. **Dry run is harmless.** Seed `$S/repo-copy/Style/dummy.css`; run
    `uninstall.sh --dry-run` from that directory with a root `id` shim. Expect
    `Would uninstall dummy.css` and the file still present.
2. **Help and invalid option.** Run `--help` and `--bogus` separately. Expect
    `Usage: ./uninstall.sh` with exit 0, then `Invalid option --bogus` with exit 1.
3. **Non-root refusal.** Without the shim, expect `This script must be run as
    root` and exit 1.
4. **Deletion scope.** Seed a nested `Style/dummy.css` and a sentinel
    `$S/bin/backup.sh`; run without `--dry-run`. Expect the nested file removed,
    `uninstall.sh` preserved, and the sentinel **still present** — this pins the
    known behavior that installed scripts are not removed.

### 3.4 backup.sh

1. **Dry run creates no archive.** Expect the `Backup would be created:` line
    and no `*.tar.gz` in `$S/out` (the directory itself may be created).
2. **Missing source aborts.** Config lists `$S/nope`. Expect
    `[ERROR] Source directory not found: $S/nope` and exit 1.
3. **Real archive is valid.** Put a small file in `$S/src`, shim `pv`, run
    `backup.sh -c $S/cfg-A`. Expect `tar -tzf` to list the file and no `.tmp`
    file to remain.
4. **Excludes honored.** Put `$S/src/skip/` with a file in a config whose
    sources live under `$S/home` and set `EXCLUDES=("$S/home/src/skip")`. Expect
    no `skip/` entry in `tar -tzf` output.
5. **Verbose mode.** `--dry-run -v`. Expect `Verbose mode enabled.`
6. **Notification gating.** Shim `pgrep` (success) and `notify-send` (append
    arguments to `$S/notify.log`); run `--dry-run --notify-send`. Expect the log
    to contain `Backup would be created:`. Never run without the shim.
7. **No daemon.** Shim `pgrep` to always fail. Expect
    `[ERROR] No notification daemon is running.`, exit 1, no notification call.
8. **Documented option mismatch.** Run `--wait-for-dbus --dry-run`. Expect a
    usage line and exit 1; the parser only accepts
    `--wait-for-notification-daemon`. Do not run the accepted form without
    timeout/`pgrep` shims — it loops.
9. **Tar failure cleanup.** Stateful `tar` shim writes a partial
    `$S/out/A-*.tmp` then exits 1. Expect
    `[FAIL] Backup failed. Removing incomplete archive.` and note whether the
    `.tmp` file remains (a known cleanup defect).

### 3.5 maintenance-reminder.sh

Always use a scratch `STATE_DIR`, a `notify-send` shim, and an `ssh` shim that
logs its arguments.

<!-- AI-generated documentation (not reviewed by a human) -->
1. **First run initializes.** `SERVER=""`, empty `$S/state`. Expect
    `Local Maintenance: Good to Go!`, a new `last-reminder`, and no `pending`.
2. **Due check.** Write `date +%s - 6*86400` into `last-reminder`, set
    `DAYS_DUE=6`. Expect `Local Maintenance Due` and a new `pending` file.
3. **Pending repeats.** Rerun with `pending` present. Expect
    `Local maintenance is already pending.` plus the due notification.
4. **Reset clears pending.** Remove `pending`, write `date +%s`. Expect
    `Local maintenance is not due yet.` and `Good to Go!`.
5. **Invalid DAYS_DUE.** `DAYS_DUE=abc`. Expect
    `Invalid DAYS_DUE "abc"; using 6.` and a normal 6-day check.
6. **Zero-day boundary.** `DAYS_DUE=0` with a fresh timestamp. Expect
    `Local Maintenance Due` immediately.
7. **Invalid stored timestamp.** `last-reminder=garbage`. Expect
    `Local maintenance: invalid timestamp 'garbage'.` and `Unknown`.
8. **Future timestamp.** `last-reminder` set to now + 99999. Expect
    `Local maintenance: timestamp is in the future.` and `Unknown`.
9. **SERVER empty disables SSH.** With `SERVER=""`, expect an empty ssh log
    and no `Remote Maintenance` notification.
10. **Missing SERVER_USER.** `SERVER=example.test SERVER_USER=""`. Expect
    `WARNING: SERVER_USER is not set; skipping remote maintenance.` and no ssh
    call.
11. **Unreachable server.** ssh shim exits 1. Expect `Server unavailable.
    Skipping remote maintenance check.` and `Remote Maintenance: Unknown`.
12. **Remote first run.** ssh shim rewrites `HOME` to `$S/remote-home` and runs
    the heredoc locally. Expect `Remote countdown initialized.` and
    `Remote Maintenance: Good to Go!`.
13. **Remote due.** As 41 with an old remote `last-reminder`. Expect
    `Remote maintenance is due.` and a remote `pending` file.
14. **Remote state missing.** Remove remote `last-reminder`. Expect
    `Remote maintenance countdown is missing.` and `Unknown`.
15. **Default SERVER conflict.** No `SERVER` in the environment, repo config
    loaded. Expect the ssh log to target `cody@sork.local`, which contradicts
    README's "disabled by default" statement.

## 4. P1 — git-checker and arch-maintenance

### 4.1 git-checker.sh

Use a bare local remote at `$S/remote.git`, clones under `$S/home/visible/`, a
scratch config with `SEARCH_DIR=$S/home` (no trailing slash) and
`IGNORE_DIRS=("$S/home/.cache")`. No network access.

1. **Clean repo.** Expect `Working tree clean.`, `Up to date with
    origin/master`, and `Clean: 1`.
2. **Dirty tree.** Modify a tracked file. Expect `Uncommitted changes detected:`
    and `Needs attention: 1`.
3. **Ahead of upstream.** Make a local commit without pushing. Expect
    `Local branch is ahead by 1 commit(s).` (and note the summary still says
    `Clean: 1`).
4. **Behind upstream.** Push from a second clone, then check the first. Expect
    `Local branch is behind by 1 commit(s).` (again counted as `Clean: 1`).
5. **No upstream.** `git init` plus a commit, no remote. Expect
    `No upstream configured for branch 'master'.` and `Needs attention: 1`.
6. **Detached HEAD.** Expect `Detached HEAD. Cannot determine upstream.` and
    `Needs attention: 1`.
7. **IGNORE_DIRS prunes.** Put repos in `$S/home/.cache/` and
    `$S/home/.cache/deep/` plus `visible`. Expect `Repositories found: 1` and no
    `.cache` path in output.
8. **Omitted IGNORE_DIRS.** Config with `SEARCH_DIR` only. Expect
    `Repositories found: 3`.
9. **SEARCH_DIR env override.** Env `SEARCH_DIR=$S/home/visible`. Expect
    `Repositories found: 1`.
10. **Trailing slash boundary.** `SEARCH_DIR=$S/home/` while the ignore entry
    has no trailing slash. Expect ignored repos are nonetheless scanned,
    documenting the path-normalization fragility.

### 4.2 arch-maintenance.sh

Shim every external command: `pacman`, `checkupdates`, `paccache`,
`systemctl`, `journalctl`, `timeshift`, `fwupdmgr`, `sudo` (handles `-v`), and
point `GIT_CHECKER` at a shim. The script's read-only `find /etc "$HOME"` is
acceptable. Run as a normal user unless testing root refusal.

1. **Root refusal.** Expect `Do not run this script as root.` and exit 1.
2. **Pacman missing.** PATH without `pacman`. Expect `Pacman not found. This
    script requires Arch Linux.` and exit 1.
3. **Happy path and reset.** Scratch `STATE_DIR` with `pending`; all stubs
    succeed. Expect `MAINTENANCE COMPLETE`, `pending` removed, and
    `last-reminder` updated to roughly now.
4. **Backup freshness boundary.** Timestamp at "now" with
    `MAX_BACKUP_AGE_DAYS=30`: expect `Backup is within the required age limit.`.
    Timestamp 30 days old: expect `Backup is overdue!` (one run each).
5. **Future backup timestamp.** Expect `Backup timestamp is in the future.`
6. **Invalid filenames.** Only `wrongname.tar.gz` and an impossible date.
    Expect `No valid backups found.`
7. **Missing backup dir.** Expect `Backup directory not found: $S/missing`.
8. **Timeshift count.** Two snapshot lines with `MIN_SNAPSHOTS=3`. Expect
    `Insufficient Timeshift snapshots.`; with three fresh snapshots expect
    `Snapshot count requirement satisfied.` and
    `Snapshot freshness requirement satisfied.` (one run each).
9. **Timeshift freshness.** Old snapshot → `Latest snapshot is older than 30
    days.`; future → `Newest snapshot has a future timestamp.`; no parseable
    names → `No valid snapshot timestamps found.` (one run each).
10. **Hardcoded message.** `MAX_SNAPSHOT_AGE_DAYS=7` with an old snapshot still
    prints `older than 30 days`.
11. **sudo failure.** `sudo` shim exits 1. Expect `Sudo authentication failed.
    Skipping Timeshift check.`
12. **Git checker integration.** Shim exits 1 → `Git checker reported issues
    (exit code: 1).`; missing path → `Git checker not found or not executable: ...`.
13. **`-c` propagates.** Shim prints `$USER_SCRIPTS_CONFIG`; after
    `arch-maintenance.sh -c $S/gcfg` expect it to show `$S/gcfg`.

## 5. Gaps and latent bugs worth pinning down

These are observations from source inspection, not confirmed failures. Each has
a scenario above; decide the intended behavior before turning any into a
regression expectation.

1. README says remote checks are disabled by default, but `config` sets
   `SERVER="${SERVER-sork.local}"`, so a default run attempts SSH (scenario 44).
2. Help text advertises `--wait-for-dbus`; the parser only accepts
   `--wait-for-notification-daemon` (scenario 28).
3. Backup cleanup removes `$ARCHIVE` rather than the `.tmp` file on tar
   failure, and uses a literal `TEMP_ARCHIVE` string on verification failure
   (scenario 29).
4. `git-checker.sh` returns the dirty flag regardless of ahead/behind status,
   so those repos count as clean; the script also always exits 0, so
   `arch-maintenance.sh` cannot see failures from the real checker (47, 48, 66).
5. `uninstall.sh` deletes files in nested directories of the current working
   directory instead of removing installed scripts from `/usr/local/bin`
   (scenarios 17–20).
6. The `config` template's header comment still says `config.conf`; the scripts
   and README use `config`. Documentation-only.
7. `XDG_CONFIG_HOME` inherited through `sudo` may point deployment at root's
   config directory rather than the invoking user's (scenario 15).
8. `IGNORE_DIRS` matching depends on exact `find` output paths; trailing slashes,
   relative entries, and symlinks break pruning (scenario 54).
9. Invalid `DAYS_DUE` falls back to a hardcoded `6` rather than the configured
   default (scenario 34).
10. An empty `SERVER_USER` disables remote checks but is undocumented
    (scenario 39).
11. The Timeshift age warning hardcodes "30 days" instead of using
    `MAX_SNAPSHOT_AGE_DAYS` (scenario 64).
12. Real backups need `pv`, which README does not list under Requirements; shim
    it or confirm it is installed (scenario 23).
13. The `ARCHIVE_HEADER` value is interpolated into a regex unescaped during
    backup-freshness matching; a header containing regex metacharacters may
    match unintended files.
14. Hard to test without heavier seams: the infinite
    `--wait-for-notification-daemon` loop, real SSH/`SSH_TIMEOUT` semantics, and
    desktop notification delivery. Assert shim logs/stderr instead.

## 6. Not in scope

Do not introduce a test framework or add a test directory to the repo. The
project deliberately keeps a small, script-only codebase; these scenarios are
manual checks to be run from a disposable copy under `/tmp/opencode/`, with the
repo itself left untouched.
