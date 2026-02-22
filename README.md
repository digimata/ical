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

### Version

```bash
ical version
ical --version
```

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

ical add \
  --title "Morning Brief" \
  --start "tomorrow 10:00" \
  --end "tomorrow 10:30" \
  --recurrence daily \
  --recurrence-end "2026-03-31"
```

Options:

- `--title <text>` (required)
- `--start <datetime>` (required)
- `--end <datetime>` (required)
- `--calendar <name>` (optional, defaults to first writable calendar)
- `--location <text>` (optional)
- `--notes <text>` (optional)
- `--all-day` (optional)
- `--recurrence <daily|weekly|monthly|yearly>` (optional)
- `--recurrence-end <date>` (optional, requires `--recurrence`)

### Remove event

By ID:

```bash
ical remove --id "<event-id>"

ical remove --id "<event-id>" --this-only
ical remove --id "<event-id>" --all-future
```

Or by title + exact start:

```bash
ical remove --title "Meeting with Luke" --start "today 14:00" --calendar "Work"
```

For recurring events, use `--this-only` or `--all-future` to choose how removal is applied.

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
- `--recurrence <daily|weekly|monthly|yearly>`
- `--recurrence-end <date>` (requires `--recurrence`)
- `--clear-recurrence`
- `--this-only` or `--all-future` (required when editing a recurring event)

## Datetime formats

- ISO 8601 (for example `2026-02-20T14:00:00-05:00`)
- `today HH:mm`
- `tomorrow HH:mm`
