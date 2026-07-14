import Foundation

/// A parsed CLI command ready for dispatch.
enum Command {
    case version
    case today
    case tomorrow
    case week
    case add(AddOptions)
    case remove(RemoveOptions)
    case edit(EditOptions)
    case reminders(RemindersCommand)
}

/// A parsed `reminders` subcommand ready for dispatch.
enum RemindersCommand {
    case list(ReminderListOptions)
    case add(ReminderAddOptions)
    case done(ReminderSelector)
    case reopen(ReminderSelector)
    case remove(ReminderSelector)
    case edit(ReminderEditOptions)
}

/// Options for the `reminders list` subcommand.
struct ReminderListOptions {
    let includeCompleted: Bool
    let listName: String?
}

/// Options for the `reminders add` subcommand.
struct ReminderAddOptions {
    let title: String
    let dueInput: String?
    let listName: String?
    let notes: String?
    let priority: Int?
}

/// Targets a reminder by `id` or by unique `title` match.
enum ReminderSelector {
    case id(String)
    case title(String)
}

/// Options for the `reminders edit` subcommand. Only non-nil fields are applied as updates.
struct ReminderEditOptions {
    let id: String
    let title: String?
    let dueInput: String?
    let clearDue: Bool
    let listName: String?
    let notes: String?
    let clearNotes: Bool
    let priority: Int?
}

/// Supported recurrence patterns for recurring events.
enum RecurrencePattern: String {
    case daily
    case weekly
    case monthly
    case yearly
}

/// How a recurring event mutation should be applied.
enum RecurrenceSpanSelection {
    case automatic
    case thisOnly
    case allFuture
}

/// Options for the `add` subcommand.
struct AddOptions {
    let title: String
    let startInput: String
    let endInput: String
    let calendarName: String?
    let location: String?
    let notes: String?
    let isAllDay: Bool
    let recurrencePattern: RecurrencePattern?
    let recurrenceEndInput: String?
}

/// Options for the `remove` subcommand. Events can be targeted by `id` or by `title`+`start`.
struct RemoveOptions {
    let id: String?
    let title: String?
    let startInput: String?
    let calendarName: String?
    let recurrenceSpan: RecurrenceSpanSelection
}

/// Options for the `edit` subcommand. Only non-nil fields are applied as updates.
struct EditOptions {
    let id: String
    let title: String?
    let startInput: String?
    let endInput: String?
    let calendarName: String?
    let location: String?
    let notes: String?
    let makeAllDay: Bool
    let makeTimed: Bool
    let clearLocation: Bool
    let clearNotes: Bool
    let recurrencePattern: RecurrencePattern?
    let recurrenceEndInput: String?
    let clearRecurrence: Bool
    let recurrenceSpan: RecurrenceSpanSelection
}

/// The result of parsing CLI arguments — either a valid command or an error message.
enum ParseResult {
    case command(Command)
    case error(String)
}
