import EventKit
import Foundation

extension ICalApp {
    /// Handles the `remove` subcommand — deletes a calendar event.
    /// - Parameter options: Parsed remove options (by id or title+start selector).
    /// - Returns: Exit code — `0` on success, `1` on error.
    func remove(_ options: RemoveOptions) -> Int32 {
        switch removeEvent(with: options) {
        case .success:
            print("Event removed.")
            return 0

        case .failure(let error):
            fputs("\(error.text)\n", stderr)
            return 1
        }
    }

    /// Resolves the target event by ID or title+start selector and removes it from EventKit.
    /// Fails if zero or multiple events match a title+start selector.
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

        guard let startDate = dateParser.parse(startInput) else {
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
            guard eventTitle(event).localizedCaseInsensitiveCompare(title) == .orderedSame else {
                return false
            }

            guard abs(event.startDate.timeIntervalSince(startDate)) < 1 else {
                return false
            }

            if let calendarName = options.calendarName {
                return event.calendar.title.localizedCaseInsensitiveCompare(calendarName)
                    == .orderedSame
            }

            return true
        }

        guard !matches.isEmpty else {
            return .failure(.message("No matching event found for title/start selector."))
        }

        guard matches.count == 1 else {
            return .failure(
                .message(
                    "Multiple matching events found (\(matches.count)). Use --id to remove a specific event."
                ))
        }

        return removeEvent(matches[0])
    }

    /// Deletes a single event from the event store.
    private func removeEvent(_ event: EKEvent) -> Result<Void, CLIError> {
        do {
            try store.remove(event, span: .thisEvent, commit: true)
            return .success(())
        } catch {
            return .failure(.message("Failed to remove event: \(error.localizedDescription)"))
        }
    }
}
