import EventKit
import Foundation

struct ICalApp {
    let store: EKEventStore
    let calendar: Calendar
    let parser: CommandParser
    let dateParser: DateInputParser
    let renderer: EventRenderer

    init(
        store: EKEventStore = EKEventStore(),
        calendar: Calendar = .current,
        parser: CommandParser = CommandParser()
    ) {
        self.store = store
        self.calendar = calendar
        self.parser = parser
        self.dateParser = DateInputParser(calendar: calendar)
        self.renderer = EventRenderer()
    }

    func run(arguments: [String] = CommandLine.arguments) -> Int32 {
        switch parser.parse(arguments: arguments) {
        case .error(let message):
            fputs("\(message)\n", stderr)
            return 1

        case .command(let command):
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
            }
        }
    }
}

exit(ICalApp().run())
