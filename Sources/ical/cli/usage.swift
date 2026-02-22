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

Datetime formats:
  ISO 8601
  "today HH:mm"
  "tomorrow HH:mm"
"""
