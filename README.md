# ical

Minimal macOS calendar and reminders CLI built with Swift + EventKit.

## Requirements

- macOS
- Swift toolchain (SwiftPM)
- Calendar access permission (prompted on first run)
- Reminders access permission (prompted on first `reminders` command; separate from calendar access)

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
- `--calendar <name>` (optional, defaults to your default calendar)
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

## Reminders

### List reminders

```bash
ical reminders                      # incomplete reminders, sorted by due date
ical reminders list --all           # include completed reminders
ical reminders list --list "Groceries"
```

If no reminders exist, it prints `No reminders.`

### Add reminder

```bash
ical reminders add \
  --title "Buy oat milk" \
  --due "tomorrow 09:00" \
  --list "Groceries" \
  --notes "The barista kind" \
  --priority 1
```

Options:

- `--title <text>` (required)
- `--due <datetime>` (optional; a date-only value like `2026-07-20` sets a day-granularity due date, a datetime also creates an alarm so the reminder notifies)
- `--list <name>` (optional, defaults to your default reminders list)
- `--notes <text>` (optional)
- `--priority <0-9>` (optional; 0 = none, 1 = high, 5 = medium, 9 = low)

### Complete / reopen / remove

```bash
ical reminders done --title "Buy oat milk"
ical reminders reopen --id "<reminder-id>"
ical reminders remove --id "<reminder-id>"
```

Each takes `--id` or `--title`. A `--title` selector must uniquely match one incomplete reminder; use `--id` (printed by `add`) to disambiguate.

### Edit reminder

```bash
ical reminders edit \
  --id "<reminder-id>" \
  --title "Updated title" \
  --due "2026-07-20 17:00" \
  --priority 5
```

Edit supports these optional flags:

- `--title`, `--due`, `--list`, `--notes`, `--priority`
- `--clear-due`
- `--clear-notes`

Changing or clearing the due date also replaces or removes the reminder's alarm.

## Datetime formats

- ISO 8601 (for example `2026-02-20T14:00:00-05:00`)
- `today HH:mm`
- `tomorrow HH:mm`
