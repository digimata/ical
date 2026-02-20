# ical

Minimal macOS calendar CLI built with Swift + EventKit.

## Requirements

- macOS
- Swift toolchain (SwiftPM)
- Calendar access permission (prompted on first run)

## Build

```bash
swift build
```

## Run

```bash
swift run ical <command>
```

## Commands

### List events

```bash
swift run ical today
swift run ical tomorrow
swift run ical week
```

Output is sorted by start time with all-day events first. Empty fields are omitted. If no events exist, it prints `No events.`

### Add event

```bash
swift run ical add \
  --title "Meeting with Luke" \
  --start "today 14:00" \
  --end "today 15:00" \
  --calendar "Work" \
  --location "Zoom" \
  --notes "Discuss pricing"
```

Options:

- `--title <text>` (required)
- `--start <datetime>` (required)
- `--end <datetime>` (required)
- `--calendar <name>` (optional, defaults to first writable calendar)
- `--location <text>` (optional)
- `--notes <text>` (optional)
- `--all-day` (optional)

### Remove event

By ID:

```bash
swift run ical remove --id "<event-id>"
```

Or by title + exact start:

```bash
swift run ical remove --title "Meeting with Luke" --start "today 14:00" --calendar "Work"
```

### Edit event

```bash
swift run ical edit \
  --id "<event-id>" \
  --title "Updated title" \
  --start "today 15:00" \
  --end "today 15:30" \
  --location "Office" \
  --notes "Updated notes"
```

Edit supports these optional flags:

- `--title`, `--start`, `--end`, `--calendar`, `--location`, `--notes`
- `--all-day` or `--timed`
- `--clear-location`
- `--clear-notes`

## Datetime formats

- ISO 8601 (for example `2026-02-20T14:00:00-05:00`)
- `today HH:mm`
- `tomorrow HH:mm`
