import EventKit
import Foundation

extension ICalApp {
    /// Synchronously requests full reminders access from EventKit.
    /// Uses `requestFullAccessToReminders` on macOS 14+ and falls back to `requestAccess(to:)` on older versions.
    /// - Returns: `true` if access was granted, `false` otherwise.
    func requestRemindersAccess() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var accessGranted = false

        if #available(macOS 14.0, *) {
            store.requestFullAccessToReminders { granted, error in
                accessGranted = granted && error == nil
                semaphore.signal()
            }
        } else {
            store.requestAccess(to: .reminder) { granted, error in
                accessGranted = granted && error == nil
                semaphore.signal()
            }
        }

        semaphore.wait()
        return accessGranted
    }

    /// Synchronously fetches reminders matching the given predicate.
    /// EventKit only offers an async reminders API, so this blocks on a semaphore.
    /// - Parameter predicate: A reminders predicate from `predicateForReminders(in:)` or similar.
    /// - Returns: The matching reminders (empty on fetch failure).
    func fetchReminders(matching predicate: NSPredicate) -> [EKReminder] {
        let semaphore = DispatchSemaphore(value: 0)
        var fetched: [EKReminder] = []

        store.fetchReminders(matching: predicate) { reminders in
            fetched = reminders ?? []
            semaphore.signal()
        }

        semaphore.wait()
        return fetched
    }

    /// Fetches reminders from the given lists, sorted by due date (no due date last), then title.
    /// - Parameters:
    ///   - listName: Optional reminder list name to filter by (case-insensitive match).
    ///   - includeCompleted: Whether completed reminders are included.
    /// - Returns: A sorted array of matching reminders, or a `CLIError` if the list is unknown.
    func fetchReminders(listName: String?, includeCompleted: Bool) -> Result<[EKReminder], CLIError> {
        let lists: [EKCalendar]?
        if let listName = nonEmpty(listName) {
            switch reminderList(named: listName, requireWritable: false) {
            case .success(let list):
                lists = [list]
            case .failure(let error):
                return .failure(error)
            }
        } else {
            lists = nil
        }

        let predicate = store.predicateForReminders(in: lists)
        let reminders = fetchReminders(matching: predicate).filter { reminder in
            includeCompleted || !reminder.isCompleted
        }

        let sorted = reminders.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted && rhs.isCompleted
            }

            let lhsDue = lhs.dueDateComponents.flatMap { calendar.date(from: $0) }
            let rhsDue = rhs.dueDateComponents.flatMap { calendar.date(from: $0) }

            switch (lhsDue, rhsDue) {
            case (.some(let lhsDate), .some(let rhsDate)) where lhsDate != rhsDate:
                return lhsDate < rhsDate
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return reminderTitle(lhs).localizedCaseInsensitiveCompare(reminderTitle(rhs)) == .orderedAscending
            }
        }

        return .success(sorted)
    }

    /// Resolves a reminder list by name, falling back to the user's default list if no name is given.
    /// - Parameters:
    ///   - name: Optional list name (case-insensitive match).
    ///   - requireWritable: Whether the resolved list must allow content modifications.
    /// - Returns: The matched `EKCalendar`, or a `CLIError` if none found.
    func reminderList(named name: String?, requireWritable: Bool = true) -> Result<EKCalendar, CLIError> {
        let allLists = store.calendars(for: .reminder)
        let candidates = requireWritable ? allLists.filter { $0.allowsContentModifications } : allLists

        guard !candidates.isEmpty else {
            return .failure(.message("No\(requireWritable ? " writable" : "") reminder lists found."))
        }

        guard let name = nonEmpty(name) else {
            if let defaultList = store.defaultCalendarForNewReminders(),
                !requireWritable || defaultList.allowsContentModifications {
                return .success(defaultList)
            }
            return .success(candidates[0])
        }

        if let selectedList = candidates.first(where: {
            $0.title.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            return .success(selectedList)
        }

        let available = candidates.map(\.title).joined(separator: ", ")
        return .failure(.message("Reminder list not found: \(name). Available lists: \(available)"))
    }

    /// Resolves a reminder by selector — direct lookup for `--id`, unique incomplete title match for `--title`.
    /// - Returns: The matched `EKReminder`, or a `CLIError` if zero or multiple reminders match.
    func resolveReminder(_ selector: ReminderSelector) -> Result<EKReminder, CLIError> {
        switch selector {
        case .id(let id):
            guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
                return .failure(.message("Reminder not found for id: \(id)"))
            }
            return .success(reminder)

        case .title(let title):
            let predicate = store.predicateForReminders(in: nil)
            let matches = fetchReminders(matching: predicate).filter { reminder in
                !reminder.isCompleted
                    && reminderTitle(reminder).localizedCaseInsensitiveCompare(title) == .orderedSame
            }

            guard !matches.isEmpty else {
                return .failure(.message("No incomplete reminder found with title: \(title)"))
            }

            guard matches.count == 1 else {
                return .failure(
                    .message(
                        "Multiple reminders found with title: \(title) (\(matches.count)). Use --id to target a specific reminder."
                    ))
            }

            return .success(matches[0])
        }
    }

    /// Builds due date components (and an optional alarm date) from a parsed due input.
    /// Date-only inputs produce day-granularity components; datetime inputs include hour and minute.
    /// - Returns: The components plus the absolute alarm date for timed reminders, or a `CLIError` on parse failure.
    func reminderDueDate(from input: String) -> Result<(components: DateComponents, alarmDate: Date?), CLIError> {
        guard let dueDate = dateParser.parse(input) else {
            return .failure(.message("Could not parse --due value: \(input)"))
        }

        if dateParser.isDateOnly(input) {
            let components = calendar.dateComponents([.year, .month, .day], from: dueDate)
            return .success((components, nil))
        }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        return .success((components, dueDate))
    }
}
