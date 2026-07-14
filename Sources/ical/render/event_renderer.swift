import EventKit
import Foundation

/// Formats and prints calendar events to stdout.
struct EventRenderer {
    let calendar: Calendar

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private let dateHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    /// Prints a list of events grouped by day with date headers.
    /// For single-day views (`today`, `tomorrow`), shows the date header once at the top.
    /// For multi-day views (`week`), shows a header for each day that has events.
    /// - Parameter events: The events to render (assumed to be pre-sorted).
    func render(events: [EKEvent]) {
        guard !events.isEmpty else {
            print("No events.")
            return
        }

        // Group events by calendar day.
        let grouped = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.startDate)
        }
        let sortedDays = grouped.keys.sorted()

        for (dayIndex, day) in sortedDays.enumerated() {
            if dayIndex > 0 {
                print("")
            }

            let header = dateHeaderFormatter.string(from: day)
            print(header)

            let dayEvents = grouped[day]!
            for (eventIndex, event) in dayEvents.enumerated() {
                if event.isAllDay {
                    print("ALL DAY  \(eventTitle(event))")
                } else {
                    let start = timeFormatter.string(from: event.startDate)
                    let end = timeFormatter.string(from: event.endDate)
                    print("\(start) - \(end)  \(eventTitle(event))")
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

                if eventIndex < dayEvents.count - 1 {
                    print("")
                }
            }
        }
    }
}
