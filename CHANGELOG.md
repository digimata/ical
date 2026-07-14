# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2026-07-14

- Added Reminders support via the `reminders` subcommand family: `list`, `add`, `done`, `reopen`, `remove`, `edit`.
- Reminder options: `--due`, `--clear-due`, `--list`, `--notes`, `--clear-notes`, `--priority`, `--all`.
- Timed due dates create an absolute alarm so the reminder actually notifies; date-only due dates stay day-granularity.
- `done`, `reopen`, and `remove` accept `--id` or a unique `--title` match.
- Grouped event list output by day with date headers.
- New events default to the user's default calendar instead of the first writable calendar when `--calendar` is omitted.

## [0.1.0] - 2026-02-22

- Added recurring event support for `add`, `edit`, and `remove`.
- Added recurrence controls: `--recurrence`, `--recurrence-end`, `--clear-recurrence`, `--this-only`, `--all-future`.
- Fixed absolute datetime parsing so datetime inputs preserve time and ordering.
- Added parser and datetime regression tests for recurrence and absolute datetime behavior.
- Added CLI version command support via `ical version` and `ical --version`.
