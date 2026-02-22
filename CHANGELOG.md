# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-02-22

- Added recurring event support for `add`, `edit`, and `remove`.
- Added recurrence controls: `--recurrence`, `--recurrence-end`, `--clear-recurrence`, `--this-only`, `--all-future`.
- Fixed absolute datetime parsing so datetime inputs preserve time and ordering.
- Added parser and datetime regression tests for recurrence and absolute datetime behavior.
- Added CLI version command support via `ical version` and `ical --version`.
