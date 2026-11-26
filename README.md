# Arch Scripts — A Suite of User Scripts

Never forget important system maintenance again!

This repository contains a collection of Arch Linux user scripts for managing an Arch Linux installation, including system maintenance tools and reminders.

The scripts use `notify-send` to provide alerts, so important information is less likely to get buried in log files. The suite was written for personal use but is designed to be easy to adapt. It includes a configuration file, along with installation and uninstallation scripts.

<!-- AI-generated documentation (not reviewed by a human) -->
## Script layout

Scripts are grouped by the machine they run on:

- `local/` — installed on this machine by `install.sh`.
- `remote/` — installed on each host in `REMOTE_SERVERS` by `install.sh`.

`install.sh` and `uninstall.sh` stay at the repository root. Remote deployment
copies each script with `scp` to a temporary directory, installs it there with
remote `sudo install`, and then removes the temporary directory. An empty
`REMOTE_SERVERS` disables remote deployment entirely.

## Requirements

- 'notify-send'

## Configuration

Shared settings live in `config`. `install.sh` deploys a copy to:

```
${XDG_CONFIG_HOME:-$HOME/.config}/user-scripts/config
```

Edit that copy to customize the suite; the repo's `config` is the template used
for fresh installs and contains generic defaults only — set your own backup
directory, archive name, and remote server there. The scripts also fall back to
the repo copy, so they work when run directly from this directory before
installation. A legacy `config.conf` in the user config directory is still
recognized, and `install.sh` migrates it to `config` when reinstalling.

Values are resolved in this order, highest priority first:

1. Environment variables (e.g. `DAYS_DUE=14 maintenance-reminder.sh`)
2. The loaded config file
3. Built-in defaults in `config`

Set `USER_SCRIPTS_CONFIG` to load a different config file, or pass
`--config-file FILE` (short form `-c FILE`) to `backup.sh`,
`arch-maintenance.sh`, `maintenance-reminder.sh`, or `git-checker.sh`. The
command-line option takes precedence over `USER_SCRIPTS_CONFIG`; otherwise the
installed, legacy, and repository config lookup applies. Environment variables
still take precedence over values set by the loaded config. Note that the
config is *sourced* as shell code, so only use files you trust.

`maintenance-reminder.sh` remote checks are disabled by default; set `SERVER`
to enable them, or use `SERVER=""` to disable them again.

<!-- AI-generated documentation (not reviewed by a human) -->
Remote deployment targets are listed separately in `REMOTE_SERVERS`, an array
of `user@host` strings. `REMOTE_INSTALL_DIR` sets the destination directory on
each host and defaults to `/usr/local/bin`.

Uninstallation removes the local scripts and leaves the config file in place;
remove it manually if desired. Remote copies are not removed by `uninstall.sh`.

## Git repository checks

`git-checker.sh` searches `SEARCH_DIR` (default `$HOME`) for Git repositories
and compares each with its upstream. Set `SEARCH_DIR` to narrow the search.

Directories listed in `IGNORE_DIRS` are skipped entirely, along with everything
below them. Use absolute paths built from `$HOME` so they match the paths `find`
produces:

```sh
IGNORE_DIRS=(
    "$HOME/.cache"
    "$HOME/.oh-my-zsh"
)
```

A custom config passed with `-c`/`--config-file` may omit `IGNORE_DIRS` to
search every directory under `SEARCH_DIR`.

## Installation

sudo ./install.sh

## Uninstallation

sudo ./uninstall.sh
