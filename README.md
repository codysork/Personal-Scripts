# Arch Scripts — A Suite of User Scripts

Never forget important system maintenance again!

This repository contains a collection of Arch Linux user scripts for managing an Arch Linux installation, including system maintenance tools and reminders.

The scripts use `notify-send` to provide alerts, so important information is less likely to get buried in log files. The suite was written for personal use but is designed to be easy to adapt. It includes a configuration file, along with installation and uninstallation scripts.

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

Set `USER_SCRIPTS_CONFIG` to load a different config file. Note that the config
is *sourced* as shell code, so only use files you trust.

`maintenance-reminder.sh` remote checks are disabled by default; set `SERVER`
to enable them, or use `SERVER=""` to disable them again.

Uninstallation leaves the config file in place; remove it manually if desired.

## Installation

sudo ./install.sh

## Uninstallation

sudo ./uninstall.sh

