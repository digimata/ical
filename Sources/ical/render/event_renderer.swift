import EventKit
import Foundation

/// Formats and prints calendar events to stdout.
struct EventRenderer {
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// Prints a list of events to stdout. Shows time range (or "ALL DAY"), calendar name, location, and notes for each event.
    /// - Parameter events: The events to render (assumed to be pre-sorted).
    func render(events: [EKEvent]) {
        guard !events.isEmpty else {
            print("No events.")
            return
        }

        for (index, event) in events.enumerated() {
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

            if index < events.count - 1 {
                print("")
            }
        }
    }
}
