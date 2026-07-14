import Foundation

let usageText = """
Usage:
  ical version
  ical --version
  ical today
  ical tomorrow
  ical week
  ical add --title <text> --start <datetime> --end <datetime> [--calendar <name>] [--location <text>] [--notes <text>] [--all-day] [--recurrence <daily|weekly|monthly|yearly>] [--recurrence-end <date>]
  ical remove (--id <event-id> | --title <text> --start <datetime> [--calendar <name>]) [--this-only|--all-future]
  ical edit --id <event-id> [--title <text>] [--start <datetime>] [--end <datetime>] [--calendar <name>] [--location <text>] [--notes <text>] [--all-day|--timed] [--clear-location] [--clear-notes] [--recurrence <daily|weekly|monthly|yearly>] [--recurrence-end <date>] [--clear-recurrence] [--this-only|--all-future]
  ical reminders [list] [--all] [--list <name>]
  ical reminders add --title <text> [--due <datetime>] [--list <name>] [--notes <text>] [--priority <0-9>]
  ical reminders done (--id <reminder-id> | --title <text>)
  ical reminders reopen (--id <reminder-id> | --title <text>)
  ical reminders remove (--id <reminder-id> | --title <text>)
  ical reminders edit --id <reminder-id> [--title <text>] [--due <datetime>] [--clear-due] [--list <name>] [--notes <text>] [--clear-notes] [--priority <0-9>]

Datetime formats:
  ISO 8601
  "today HH:mm"
  "tomorrow HH:mm"
"""
