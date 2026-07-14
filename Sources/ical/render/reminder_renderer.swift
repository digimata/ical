import EventKit
import Foundation

/// Formats and prints reminders to stdout.
struct ReminderRenderer {
    let calendar: Calendar

    private let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    /// Prints a list of reminders with a checkbox marker, due date, list name, priority, and notes.
    /// - Parameter reminders: The reminders to render (assumed to be pre-sorted).
    func render(reminders: [EKReminder]) {
        guard !reminders.isEmpty else {
            print("No reminders.")
            return
        }

        for (index, reminder) in reminders.enumerated() {
            let marker = reminder.isCompleted ? "[x]" : "[ ]"
            print("\(marker) \(reminderTitle(reminder))")

            if let due = dueDescription(for: reminder) {
                print("Due: \(due)")
            }

            if let listTitle = nonEmpty(reminder.calendar.title) {
                print("List: \(listTitle)")
            }

            if let priority = priorityDescription(for: reminder) {
                print("Priority: \(priority)")
            }

            if let notes = nonEmpty(reminder.notes?.replacingOccurrences(of: "\n", with: " ")) {
                print("Notes: \(notes)")
            }

            if index < reminders.count - 1 {
                print("")
            }
        }
    }

    /// Formats the due date — date-only when components carry no time, datetime otherwise.
    private func dueDescription(for reminder: EKReminder) -> String? {
        guard
            let components = reminder.dueDateComponents,
            let dueDate = calendar.date(from: components)
        else {
            return nil
        }

        let hasTime = components.hour != nil || components.minute != nil
        let formatter = hasTime ? dateTimeFormatter : dateOnlyFormatter
        return formatter.string(from: dueDate)
    }

    /// Maps EventKit's 0-9 priority scale to a label (1-4 high, 5 medium, 6-9 low).
    private func priorityDescription(for reminder: EKReminder) -> String? {
        switch reminder.priority {
        case 0:
            return nil
        case 1...4:
            return "high"
        case 5:
            return "medium"
        default:
            return "low"
        }
    }
}
