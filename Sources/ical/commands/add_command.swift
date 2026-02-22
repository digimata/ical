import EventKit
import Foundation

extension ICalApp {
    /// Handles the `add` subcommand — creates a new calendar event.
    /// - Parameter options: Parsed add options (title, start, end, etc.).
    /// - Returns: Exit code — `0` on success, `1` on error.
    func add(_ options: AddOptions) -> Int32 {
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
    }

    /// Validates dates, resolves the target calendar, and saves a new event to EventKit.
    /// - Returns: The new event's identifier on success, or a `CLIError` on failure.
    private func createEvent(with options: AddOptions) -> Result<String?, CLIError> {
        guard let rawStartDate = dateParser.parse(options.startInput) else {
            return .failure(.message("Could not parse --start value: \(options.startInput)"))
        }

        guard let rawEndDate = dateParser.parse(options.endInput) else {
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
        case .failure(let error):
            return .failure(error)
        }

        let event = EKEvent(eventStore: store)
        event.title = options.title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = selectedCalendar
        event.location = options.location
        event.notes = options.notes
        event.isAllDay = options.isAllDay

        if let recurrencePattern = options.recurrencePattern {
            switch recurrenceRule(pattern: recurrencePattern, endInput: options.recurrenceEndInput) {
            case .success(let rule):
                event.recurrenceRules = [rule]
            case .failure(let error):
                return .failure(error)
            }
        }

        do {
            try store.save(event, span: .thisEvent, commit: true)
            return .success(event.eventIdentifier)
        } catch {
            return .failure(.message("Failed to save event: \(error.localizedDescription)"))
        }
    }
}
