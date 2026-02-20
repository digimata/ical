import Foundation

enum Command {
    case today
    case tomorrow
    case week
    case add(AddOptions)
    case remove(RemoveOptions)
    case edit(EditOptions)
}

struct AddOptions {
    let title: String
    let startInput: String
    let endInput: String
    let calendarName: String?
    let location: String?
    let notes: String?
    let isAllDay: Bool
}

struct RemoveOptions {
    let id: String?
    let title: String?
    let startInput: String?
    let calendarName: String?
}

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

enum ParseResult {
    case command(Command)
    case error(String)
}
