<!-- AI-generated documentation (not reviewed by a human) -->
# Changelog

All notable changes to this project are recorded here.

<!-- AI-generated documentation (not reviewed by a human) -->
## [1.0.0-pre-alpha] - 2026-11-25

First documented pre-alpha version of the personal-scripts suite. The full
release is planned to add scripts for controlling servers.

### Added

- Install and uninstall scripts, a README, and the shared config template.
- Backup, Arch Linux maintenance, Git checker, and maintenance-reminder scripts.
- Remote maintenance reminders and a notification for when no maintenance is needed.
- Shared master config with generic defaults; the template was renamed to `config`.
- `-c` / `--config-file` support across the scripts.
- A dependency-free Bash test harness, a test plan, and docblock conventions.
- A machine-readable Bash suite spec and schema, with every script documented in it.
- Remote deployment support and the reorganisation of scripts into `local/` and `remote/`.
- `doc/config.schema.json` and `doc/config.example.json`, a JSON representation of
  the configuration values.

### Changed

- The installer was split into focused functions; config parsing and local/remote
  maintenance checks were unified.
- The test runner was split into focused functions and config test fixtures were
  given descriptive names.
- Script headers and function docblocks were standardised; `Tests/` was lowercased
  to `tests/`.
- The test plan was moved to `doc/`.

### Fixed

- Timeshift snapshot date parsing.
- The initial configuration test-fixture naming change was replaced with
  descriptive fixture names.
