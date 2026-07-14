import EventKit
import Foundation

/// Top-level application struct that wires together parsing, EventKit access, and command dispatch.
struct ICalApp {
    let store: EKEventStore
    let calendar: Calendar
    let parser: CommandParser
    let dateParser: DateInputParser
    let renderer: EventRenderer
    let reminderRenderer: ReminderRenderer

    /// Creates a new app instance with the given dependencies.
    /// - Parameters:
    ///   - store: The EventKit event store to use for calendar operations.
    ///   - calendar: The calendar used for date arithmetic (defaults to the user's current calendar).
    ///   - parser: The command-line argument parser.
    init(
        store: EKEventStore = EKEventStore(),
        calendar: Calendar = .current,
        parser: CommandParser = CommandParser()
    ) {
        self.store = store
        self.calendar = calendar
        self.parser = parser
        self.dateParser = DateInputParser(calendar: calendar)
        self.renderer = EventRenderer(calendar: calendar)
        self.reminderRenderer = ReminderRenderer(calendar: calendar)
    }

    /// Parses CLI arguments, requests calendar access, and dispatches to the matched command handler.
    /// - Parameter arguments: Raw command-line arguments (defaults to `CommandLine.arguments`).
    /// - Returns: Exit code — `0` on success, `1` on error.
    func run(arguments: [String] = CommandLine.arguments) -> Int32 {
        switch parser.parse(arguments: arguments) {
        case .error(let message):
            fputs("\(message)\n", stderr)
            return 1

        case .command(let command):
            switch command {
            case .version:
                print("ical \(appVersion)")
                return 0

            case .reminders(let remindersCommand):
                guard requestRemindersAccess() else {
                    fputs("Reminders access denied.\n", stderr)
                    return 1
                }
                return reminders(remindersCommand)

            case .today, .tomorrow, .week, .add, .remove, .edit:
                guard requestAccess() else {
                    fputs("Calendar access denied.\n", stderr)
                    return 1
                }

                switch command {
                case .today, .tomorrow, .week:
                    return list(command)
                case .add(let options):
                    return add(options)
                case .remove(let options):
                    return remove(options)
                case .edit(let options):
                    return edit(options)
                case .version, .reminders:
                    return 1
                }
            }
        }
    }
}

exit(ICalApp().run())
