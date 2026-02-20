import Foundation

extension ICalApp {
    /// Handles the `today`, `tomorrow`, and `week` subcommands by fetching and rendering events in the corresponding date range.
    /// - Parameter command: The list-style command to execute.
    /// - Returns: Exit code — `0` on success, `1` on error.
    func list(_ command: Command) -> Int32 {
        guard let dateInterval = dateInterval(for: command) else {
            fputs("Could not determine date range.\n", stderr)
            return 1
        }

        let events = fetchEvents(in: dateInterval)
        renderer.render(events: events)
        return 0
    }

    /// Computes the date interval for a list command (`today`, `tomorrow`, or `week`).
    /// - Returns: The corresponding `DateInterval`, or `nil` for non-list commands.
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
}
