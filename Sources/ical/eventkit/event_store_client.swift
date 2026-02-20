import EventKit
import Foundation

extension ICalApp {
    func requestAccess() -> Bool {
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

    func fetchEvents(in dateInterval: DateInterval) -> [EKEvent] {
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

            return eventTitle(lhs).localizedCaseInsensitiveCompare(eventTitle(rhs)) == .orderedAscending
        }
    }

    func writableCalendar(named name: String?) -> Result<EKCalendar, CLIError> {
        let writableCalendars = store.calendars(for: .event).filter { $0.allowsContentModifications }

        guard !writableCalendars.isEmpty else {
            return .failure(.message("No writable calendars found."))
        }

        guard let name = nonEmpty(name) else {
            return .success(writableCalendars[0])
        }

        if let selectedCalendar = writableCalendars.first(where: {
            $0.title.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            return .success(selectedCalendar)
        }

        let available = writableCalendars.map(\.title).joined(separator: ", ")
        return .failure(.message("Calendar not found: \(name). Writable calendars: \(available)"))
    }

    func dayInterval(containing date: Date) -> DateInterval? {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }
}
