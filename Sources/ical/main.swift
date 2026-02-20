import EventKit
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

enum CLIError: Error {
    case message(String)

    var text: String {
        switch self {
        case .message(let value):
            return value
        }
    }
}

struct ICalCLI {
    private let store = EKEventStore()
    private let calendar = Calendar.current
    private let usage = """
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
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    private let isoDateFormatters: [ISO8601DateFormatter] = {
        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let internetDateTime = ISO8601DateFormatter()
        internetDateTime.formatOptions = [.withInternetDateTime]

        let fullDate = ISO8601DateFormatter()
        fullDate.formatOptions = [.withFullDate]

        return [withFractionalSeconds, internetDateTime, fullDate]
    }()
    private let localDateTimeFormatters: [DateFormatter] = {
        let patterns = [
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd HH:mm:ss"
        ]

        return patterns.map { pattern in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = pattern
            return formatter
        }
    }()

    func run() -> Int32 {
        switch parseCommand() {
        case .error(let message):
            fputs("\(message)\n", stderr)
            return 1

        case .command(let command):
            guard requestCalendarAccess() else {
                fputs("Calendar access denied.\n", stderr)
                return 1
            }

            switch command {
            case .today, .tomorrow, .week:
                guard let dateInterval = dateInterval(for: command) else {
                    fputs("Could not determine date range.\n", stderr)
                    return 1
                }

                let events = fetchEvents(in: dateInterval)
                printEvents(events)
                return 0

            case .add(let options):
                switch createEvent(with: options) {
                case .success(let identifier):
                    print("Event created.")
                    if let identifier {
                        print("ID: \(identifier)")
                    }
                    return 0
                case .failure(let error):
                    fputs("\(error.text)\n", stderr)
                    return 1
                }

            case .remove(let options):
                switch removeEvent(with: options) {
                case .success:
                    print("Event removed.")
                    return 0
                case .failure(let error):
                    fputs("\(error.text)\n", stderr)
                    return 1
                }

            case .edit(let options):
                switch editEvent(with: options) {
                case .success(let identifier):
                    print("Event updated.")
                    if let identifier {
                        print("ID: \(identifier)")
                    }
                    return 0
                case .failure(let error):
                    fputs("\(error.text)\n", stderr)
                    return 1
                }
            }
        }
    }

    private func parseCommand() -> ParseResult {
        let arguments = CommandLine.arguments
        guard arguments.count >= 2 else {
            return .error(usage)
        }

        let subcommand = arguments[1]
        let remaining = Array(arguments.dropFirst(2))

        switch subcommand {
        case "today":
            guard remaining.isEmpty else {
                return .error("Unexpected arguments for 'today'.\n\n\(usage)")
            }
            return .command(.today)

        case "tomorrow":
            guard remaining.isEmpty else {
                return .error("Unexpected arguments for 'tomorrow'.\n\n\(usage)")
            }
            return .command(.tomorrow)

        case "week":
            guard remaining.isEmpty else {
                return .error("Unexpected arguments for 'week'.\n\n\(usage)")
            }
            return .command(.week)

        case "add":
            switch parseAddOptions(remaining) {
            case .success(let options):
                return .command(.add(options))
            case .failure(let error):
                return .error("\(error.text)\n\n\(usage)")
            }

        case "remove":
            switch parseRemoveOptions(remaining) {
            case .success(let options):
                return .command(.remove(options))
            case .failure(let error):
                return .error("\(error.text)\n\n\(usage)")
            }

        case "edit":
            switch parseEditOptions(remaining) {
            case .success(let options):
                return .command(.edit(options))
            case .failure(let error):
                return .error("\(error.text)\n\n\(usage)")
            }

        default:
            return .error("Unknown command: \(subcommand)\n\n\(usage)")
        }
    }

    private func parseAddOptions(_ arguments: [String]) -> Result<AddOptions, CLIError> {
        var title: String?
        var startInput: String?
        var endInput: String?
        var calendarName: String?
        var location: String?
        var notes: String?
        var isAllDay = false

        var index = 0
        while index < arguments.count {
            let token = arguments[index]

            guard token.hasPrefix("--") else {
                return .failure(.message("Unexpected argument: \(token)"))
            }

            switch token {
            case "--title":
                guard title == nil else {
                    return .failure(.message("Duplicate option: --title"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index) else {
                    return .failure(.message("Missing value for --title"))
                }
                title = value

            case "--start":
                guard startInput == nil else {
                    return .failure(.message("Duplicate option: --start"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index) else {
                    return .failure(.message("Missing value for --start"))
                }
                startInput = value

            case "--end":
                guard endInput == nil else {
                    return .failure(.message("Duplicate option: --end"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index) else {
                    return .failure(.message("Missing value for --end"))
                }
                endInput = value

            case "--calendar":
                guard calendarName == nil else {
                    return .failure(.message("Duplicate option: --calendar"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index) else {
                    return .failure(.message("Missing value for --calendar"))
                }
                calendarName = value

            case "--location":
                guard location == nil else {
                    return .failure(.message("Duplicate option: --location"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index) else {
                    return .failure(.message("Missing value for --location"))
                }
                location = value

            case "--notes":
                guard notes == nil else {
                    return .failure(.message("Duplicate option: --notes"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index) else {
                    return .failure(.message("Missing value for --notes"))
                }
                notes = value

            case "--all-day":
                isAllDay = true
                index += 1

            default:
                return .failure(.message("Unknown option: \(token)"))
            }
        }

        guard let rawTitle = title, let finalTitle = nonEmpty(rawTitle) else {
            return .failure(.message("Missing required option: --title"))
        }

        guard let rawStart = startInput, let finalStart = nonEmpty(rawStart) else {
            return .failure(.message("Missing required option: --start"))
        }

        guard let rawEnd = endInput, let finalEnd = nonEmpty(rawEnd) else {
            return .failure(.message("Missing required option: --end"))
        }

        return .success(
            AddOptions(
                title: finalTitle,
                startInput: finalStart,
                endInput: finalEnd,
                calendarName: nonEmpty(calendarName),
                location: nonEmpty(location),
                notes: nonEmpty(notes),
                isAllDay: isAllDay
            )
        )
    }

    private func parseRemoveOptions(_ arguments: [String]) -> Result<RemoveOptions, CLIError> {
        var id: String?
        var title: String?
        var startInput: String?
        var calendarName: String?

        var index = 0
        while index < arguments.count {
            let token = arguments[index]

            guard token.hasPrefix("--") else {
                return .failure(.message("Unexpected argument: \(token)"))
            }

            switch token {
            case "--id":
                guard id == nil else {
                    return .failure(.message("Duplicate option: --id"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --id"))
                }
                id = finalValue

            case "--title":
                guard title == nil else {
                    return .failure(.message("Duplicate option: --title"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --title"))
                }
                title = finalValue

            case "--start":
                guard startInput == nil else {
                    return .failure(.message("Duplicate option: --start"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --start"))
                }
                startInput = finalValue

            case "--calendar":
                guard calendarName == nil else {
                    return .failure(.message("Duplicate option: --calendar"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --calendar"))
                }
                calendarName = finalValue

            default:
                return .failure(.message("Unknown option: \(token)"))
            }
        }

        if let id {
            guard title == nil, startInput == nil, calendarName == nil else {
                return .failure(.message("Use either --id or --title/--start selector, not both."))
            }

            return .success(
                RemoveOptions(
                    id: id,
                    title: nil,
                    startInput: nil,
                    calendarName: nil
                )
            )
        }

        guard let title else {
            return .failure(.message("Missing selector. Use --id or --title with --start."))
        }

        guard let startInput else {
            return .failure(.message("Missing required option: --start"))
        }

        return .success(
            RemoveOptions(
                id: nil,
                title: title,
                startInput: startInput,
                calendarName: calendarName
            )
        )
    }

    private func parseEditOptions(_ arguments: [String]) -> Result<EditOptions, CLIError> {
        var id: String?
        var title: String?
        var startInput: String?
        var endInput: String?
        var calendarName: String?
        var location: String?
        var notes: String?
        var makeAllDay = false
        var makeTimed = false
        var clearLocation = false
        var clearNotes = false

        var index = 0
        while index < arguments.count {
            let token = arguments[index]

            guard token.hasPrefix("--") else {
                return .failure(.message("Unexpected argument: \(token)"))
            }

            switch token {
            case "--id":
                guard id == nil else {
                    return .failure(.message("Duplicate option: --id"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --id"))
                }
                id = finalValue

            case "--title":
                guard title == nil else {
                    return .failure(.message("Duplicate option: --title"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --title"))
                }
                title = finalValue

            case "--start":
                guard startInput == nil else {
                    return .failure(.message("Duplicate option: --start"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --start"))
                }
                startInput = finalValue

            case "--end":
                guard endInput == nil else {
                    return .failure(.message("Duplicate option: --end"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --end"))
                }
                endInput = finalValue

            case "--calendar":
                guard calendarName == nil else {
                    return .failure(.message("Duplicate option: --calendar"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --calendar"))
                }
                calendarName = finalValue

            case "--location":
                guard location == nil else {
                    return .failure(.message("Duplicate option: --location"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --location"))
                }
                location = finalValue

            case "--notes":
                guard notes == nil else {
                    return .failure(.message("Duplicate option: --notes"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --notes"))
                }
                notes = finalValue

            case "--all-day":
                makeAllDay = true
                index += 1

            case "--timed":
                makeTimed = true
                index += 1

            case "--clear-location":
                clearLocation = true
                index += 1

            case "--clear-notes":
                clearNotes = true
                index += 1

            default:
                return .failure(.message("Unknown option: \(token)"))
            }
        }

        guard let id else {
            return .failure(.message("Missing required option: --id"))
        }

        guard !(makeAllDay && makeTimed) else {
            return .failure(.message("--all-day and --timed cannot be used together."))
        }

        guard !(clearLocation && location != nil) else {
            return .failure(.message("Use either --location or --clear-location, not both."))
        }

        guard !(clearNotes && notes != nil) else {
            return .failure(.message("Use either --notes or --clear-notes, not both."))
        }

        let hasUpdate =
            title != nil ||
            startInput != nil ||
            endInput != nil ||
            calendarName != nil ||
            location != nil ||
            notes != nil ||
            makeAllDay ||
            makeTimed ||
            clearLocation ||
            clearNotes

        guard hasUpdate else {
            return .failure(.message("No changes provided."))
        }

        return .success(
            EditOptions(
                id: id,
                title: title,
                startInput: startInput,
                endInput: endInput,
                calendarName: calendarName,
                location: location,
                notes: notes,
                makeAllDay: makeAllDay,
                makeTimed: makeTimed,
                clearLocation: clearLocation,
                clearNotes: clearNotes
            )
        )
    }

    private func collectOptionValue(from arguments: [String], index: inout Int) -> String? {
        index += 1
        var chunks: [String] = []

        while index < arguments.count, !arguments[index].hasPrefix("--") {
            chunks.append(arguments[index])
            index += 1
        }

        guard !chunks.isEmpty else {
            return nil
        }

        return chunks.joined(separator: " ")
    }

    private func requestCalendarAccess() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var accessGranted = false

        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { granted, error in
                accessGranted = granted && error == nil
                semaphore.signal()
            }
        } else {
            store.requestAccess(to: .event) { granted, error in
                accessGranted = granted && error == nil
                semaphore.signal()
            }
        }

        semaphore.wait()
        return accessGranted
    }

    private func dateInterval(for command: Command) -> DateInterval? {
        let now = Date()

        switch command {
        case .today:
            let start = calendar.startOfDay(for: now)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
                return nil
            }
            return DateInterval(start: start, end: end)

        case .tomorrow:
            let startOfToday = calendar.startOfDay(for: now)
            guard
                let start = calendar.date(byAdding: .day, value: 1, to: startOfToday),
                let end = calendar.date(byAdding: .day, value: 1, to: start)
            else {
                return nil
            }
            return DateInterval(start: start, end: end)

        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now)

        case .add, .remove, .edit:
            return nil
        }
    }

    private func fetchEvents(in dateInterval: DateInterval) -> [EKEvent] {
        let predicate = store.predicateForEvents(
            withStart: dateInterval.start,
            end: dateInterval.end,
            calendars: nil
        )

        return store.events(matching: predicate).sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay {
                return lhs.isAllDay && !rhs.isAllDay
            }

            if lhs.startDate != rhs.startDate {
                return lhs.startDate < rhs.startDate
            }

            if lhs.endDate != rhs.endDate {
                return lhs.endDate < rhs.endDate
            }

            return normalizedTitle(for: lhs)
                .localizedCaseInsensitiveCompare(normalizedTitle(for: rhs)) == .orderedAscending
        }
    }

    private func createEvent(with options: AddOptions) -> Result<String?, CLIError> {
        guard let rawStartDate = parseDateTime(options.startInput) else {
            return .failure(.message("Could not parse --start value: \(options.startInput)"))
        }

        guard let rawEndDate = parseDateTime(options.endInput) else {
            return .failure(.message("Could not parse --end value: \(options.endInput)"))
        }

        let startDate: Date
        let endDate: Date

        if options.isAllDay {
            startDate = calendar.startOfDay(for: rawStartDate)
            let normalizedEnd = calendar.startOfDay(for: rawEndDate)

            if normalizedEnd > startDate {
                endDate = normalizedEnd
            } else if let nextDay = calendar.date(byAdding: .day, value: 1, to: startDate) {
                endDate = nextDay
            } else {
                return .failure(.message("Could not normalize all-day event dates."))
            }
        } else {
            guard rawEndDate > rawStartDate else {
                return .failure(.message("--end must be after --start"))
            }
            startDate = rawStartDate
            endDate = rawEndDate
        }

        let selectedCalendar: EKCalendar
        switch writableCalendar(named: options.calendarName) {
        case .success(let calendar):
            selectedCalendar = calendar
        case .failure(let message):
            return .failure(message)
        }

        let event = EKEvent(eventStore: store)
        event.title = options.title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = selectedCalendar
        event.location = options.location
        event.notes = options.notes
        event.isAllDay = options.isAllDay

        do {
            try store.save(event, span: .thisEvent, commit: true)
            return .success(event.eventIdentifier)
        } catch {
            return .failure(.message("Failed to save event: \(error.localizedDescription)"))
        }
    }

    private func removeEvent(with options: RemoveOptions) -> Result<Void, CLIError> {
        if let id = options.id {
            guard let event = store.event(withIdentifier: id) else {
                return .failure(.message("Event not found for id: \(id)"))
            }

            return removeEvent(event)
        }

        guard let title = options.title, let startInput = options.startInput else {
            return .failure(.message("Missing selector. Use --id or --title with --start."))
        }

        guard let startDate = parseDateTime(startInput) else {
            return .failure(.message("Could not parse --start value: \(startInput)"))
        }

        guard let dayInterval = dayInterval(containing: startDate) else {
            return .failure(.message("Could not determine day range for selector."))
        }

        let predicate = store.predicateForEvents(
            withStart: dayInterval.start,
            end: dayInterval.end,
            calendars: nil
        )

        let matches = store.events(matching: predicate).filter { event in
            guard normalizedTitle(for: event).localizedCaseInsensitiveCompare(title) == .orderedSame else {
                return false
            }

            guard let eventStart = event.startDate, abs(eventStart.timeIntervalSince(startDate)) < 1 else {
                return false
            }

            if let calendarName = options.calendarName {
                return event.calendar.title.localizedCaseInsensitiveCompare(calendarName) == .orderedSame
            }

            return true
        }

        guard !matches.isEmpty else {
            return .failure(.message("No matching event found for title/start selector."))
        }

        guard matches.count == 1 else {
            return .failure(.message("Multiple matching events found (\(matches.count)). Use --id to remove a specific event."))
        }

        return removeEvent(matches[0])
    }

    private func removeEvent(_ event: EKEvent) -> Result<Void, CLIError> {
        do {
            try store.remove(event, span: .thisEvent, commit: true)
            return .success(())
        } catch {
            return .failure(.message("Failed to remove event: \(error.localizedDescription)"))
        }
    }

    private func editEvent(with options: EditOptions) -> Result<String?, CLIError> {
        guard let event = store.event(withIdentifier: options.id) else {
            return .failure(.message("Event not found for id: \(options.id)"))
        }

        if let title = options.title {
            event.title = title
        }

        if let calendarName = options.calendarName {
            switch writableCalendar(named: calendarName) {
            case .success(let selectedCalendar):
                event.calendar = selectedCalendar
            case .failure(let error):
                return .failure(error)
            }
        }

        if let location = options.location {
            event.location = location
        }

        if options.clearLocation {
            event.location = nil
        }

        if let notes = options.notes {
            event.notes = notes
        }

        if options.clearNotes {
            event.notes = nil
        }

        guard let originalStartDate = event.startDate, let originalEndDate = event.endDate else {
            return .failure(.message("Event has invalid start or end date."))
        }

        var startDate = originalStartDate
        var endDate = originalEndDate

        if let startInput = options.startInput {
            guard let parsedStart = parseDateTime(startInput) else {
                return .failure(.message("Could not parse --start value: \(startInput)"))
            }
            startDate = parsedStart
        }

        if let endInput = options.endInput {
            guard let parsedEnd = parseDateTime(endInput) else {
                return .failure(.message("Could not parse --end value: \(endInput)"))
            }
            endDate = parsedEnd
        }

        var isAllDay = event.isAllDay
        if options.makeAllDay {
            isAllDay = true
        }
        if options.makeTimed {
            isAllDay = false
        }

        if isAllDay {
            startDate = calendar.startOfDay(for: startDate)
            let normalizedEnd = calendar.startOfDay(for: endDate)

            if normalizedEnd > startDate {
                endDate = normalizedEnd
            } else if let nextDay = calendar.date(byAdding: .day, value: 1, to: startDate) {
                endDate = nextDay
            } else {
                return .failure(.message("Could not normalize all-day event dates."))
            }
        } else {
            guard endDate > startDate else {
                return .failure(.message("--end must be after --start"))
            }
        }

        event.isAllDay = isAllDay
        event.startDate = startDate
        event.endDate = endDate

        do {
            try store.save(event, span: .thisEvent, commit: true)
            return .success(event.eventIdentifier)
        } catch {
            return .failure(.message("Failed to update event: \(error.localizedDescription)"))
        }
    }

    private func dayInterval(containing date: Date) -> DateInterval? {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    private func writableCalendar(named name: String?) -> Result<EKCalendar, CLIError> {
        let writableCalendars = store.calendars(for: .event).filter { $0.allowsContentModifications }

        guard !writableCalendars.isEmpty else {
            return .failure(.message("No writable calendars found."))
        }

        guard let name = nonEmpty(name) else {
            return .success(writableCalendars[0])
        }

        if let calendar = writableCalendars.first(where: {
            $0.title.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            return .success(calendar)
        }

        let available = writableCalendars.map(\.title).joined(separator: ", ")
        return .failure(.message("Calendar not found: \(name). Writable calendars: \(available)"))
    }

    private func parseDateTime(_ input: String) -> Date? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if let relative = parseRelativeDateTime(value) {
            return relative
        }

        for formatter in isoDateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        for formatter in localDateTimeFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private func parseRelativeDateTime(_ input: String) -> Date? {
        let parts = input.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: { $0.isWhitespace }
        )

        guard parts.count == 2 else {
            return nil
        }

        let dayToken = String(parts[0]).lowercased()
        let timeToken = String(parts[1])

        let dayOffset: Int
        if dayToken == "today" {
            dayOffset = 0
        } else if dayToken == "tomorrow" {
            dayOffset = 1
        } else {
            return nil
        }

        guard let (hour, minute) = parseHourMinute(timeToken) else {
            return nil
        }

        let startOfToday = calendar.startOfDay(for: Date())
        guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else {
            return nil
        }

        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: targetDay)
    }

    private func parseHourMinute(_ input: String) -> (Int, Int)? {
        let parts = input.split(separator: ":")

        guard
            parts.count == 2,
            let hour = Int(parts[0]),
            let minute = Int(parts[1]),
            (0...23).contains(hour),
            (0...59).contains(minute)
        else {
            return nil
        }

        return (hour, minute)
    }

    private func printEvents(_ events: [EKEvent]) {
        guard !events.isEmpty else {
            print("No events.")
            return
        }

        for (index, event) in events.enumerated() {
            if event.isAllDay {
                print("ALL DAY  \(normalizedTitle(for: event))")
            } else {
                let start = timeFormatter.string(from: event.startDate)
                let end = timeFormatter.string(from: event.endDate)
                print("\(start) - \(end)  \(normalizedTitle(for: event))")
            }

            if let calendarTitle = nonEmpty(event.calendar.title) {
                print("Calendar: \(calendarTitle)")
            }

            let location = nonEmpty(event.location)
            let urlString = nonEmpty(event.url?.absoluteString)
            if let location, let urlString {
                print("Location: \(location) (\(urlString))")
            } else if let location {
                print("Location: \(location)")
            } else if let urlString {
                print("Location: \(urlString)")
            }

            if let notes = nonEmpty(event.notes?.replacingOccurrences(of: "\n", with: " ")) {
                print("Notes: \(notes)")
            }

            if index < events.count - 1 {
                print("")
            }
        }
    }

    private func normalizedTitle(for event: EKEvent) -> String {
        nonEmpty(event.title) ?? "(No Title)"
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

exit(ICalCLI().run())
