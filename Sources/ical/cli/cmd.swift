import Foundation

/// A parsed CLI command ready for dispatch.
enum Command {
    case today
    case tomorrow
    case week
    case add(AddOptions)
    case remove(RemoveOptions)
    case edit(EditOptions)
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
}

/// Options for the `remove` subcommand. Events can be targeted by `id` or by `title`+`start`.
struct RemoveOptions {
    let id: String?
    let title: String?
    let startInput: String?
    let calendarName: String?
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
}

/// The result of parsing CLI arguments — either a valid command or an error message.
enum ParseResult {
    case command(Command)
    case error(String)
}
