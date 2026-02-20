import Foundation

let usageText = """
Usage:
  ical today
  ical tomorrow
  ical week
  ical add --title <text> --start <datetime> --end <datetime> [--calendar <name>] [--location <text>] [--notes <text>] [--all-day]
  ical remove (--id <event-id> | --title <text> --start <datetime> [--calendar <name>])
  ical edit --id <event-id> [--title <text>] [--start <datetime>] [--end <datetime>] [--calendar <name>] [--location <text>] [--notes <text>] [--all-day|--timed] [--clear-location] [--clear-notes]

Datetime formats:
  ISO 8601
  "today HH:mm"
  "tomorrow HH:mm"
"""
