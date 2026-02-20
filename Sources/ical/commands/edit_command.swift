import Foundation

extension ICalApp {
    /// Handles the `edit` subcommand — modifies an existing calendar event.
    /// - Parameter options: Parsed edit options (id plus any fields to update).
    /// - Returns: Exit code — `0` on success, `1` on error.
    func edit(_ options: EditOptions) -> Int32 {
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

    /// Looks up the event by ID, applies the requested changes, and saves it back to EventKit.
    /// - Returns: The updated event's identifier on success, or a `CLIError` on failure.
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
            guard let parsedStart = dateParser.parse(startInput) else {
                return .failure(.message("Could not parse --start value: \(startInput)"))
            }
            startDate = parsedStart
        }

        if let endInput = options.endInput {
            guard let parsedEnd = dateParser.parse(endInput) else {
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
}
