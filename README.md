# ical

Minimal macOS calendar CLI built with Swift + EventKit.

## Requirements

- macOS
- Swift toolchain (SwiftPM)
- Calendar access permission (prompted on first run)

## Install

Build a release binary and copy it into a directory on your `PATH`:

```bash
swift build -c release
mkdir -p "$HOME/.local/bin"
cp .build/release/ical "$HOME/.local/bin/ical"
```

Optional system-wide install:

```bash
sudo cp .build/release/ical /usr/local/bin/ical
```

If `~/.local/bin` is not on your `PATH`, add this to `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then reload your shell:

```bash
source ~/.zshrc
```

Now you can run:

```bash
ical today
```

## Commands

### List events

```bash
ical today
ical tomorrow
ical week
```

Output is sorted by start time with all-day events first. Empty fields are omitted. If no events exist, it prints `No events.`

### Add event

```bash
ical add \
  --title "Meeting with Joe" \
  --start "today 14:00" \
  --end "today 15:00" \
  --calendar "Work" \
  --location "Google Meet" \
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
ical remove --id "<event-id>"
```

Or by title + exact start:

```bash
ical remove --title "Meeting with Luke" --start "today 14:00" --calendar "Work"
```

### Edit event

```bash
ical edit \
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
