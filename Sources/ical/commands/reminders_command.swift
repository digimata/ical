import EventKit
import Foundation

extension ICalApp {
    /// Dispatches a `reminders` subcommand to its handler.
    /// - Parameter command: The parsed reminders subcommand.
    /// - Returns: Exit code — `0` on success, `1` on error.
    func reminders(_ command: RemindersCommand) -> Int32 {
        let result: Result<String, CLIError>

        switch command {
        case .list(let options):
            return listReminders(options)
        case .add(let options):
            result = createReminder(with: options)
        case .done(let selector):
            result = setReminderCompletion(selector, completed: true)
        case .reopen(let selector):
            result = setReminderCompletion(selector, completed: false)
        case .remove(let selector):
            result = removeReminder(selector)
        case .edit(let options):
            result = editReminder(with: options)
        }

        switch result {
        case .success(let message):
            print(message)
            return 0
        case .failure(let error):
            fputs("\(error.text)\n", stderr)
            return 1
        }
    }

    /// Handles `reminders list` — fetches and renders reminders.
    private func listReminders(_ options: ReminderListOptions) -> Int32 {
        switch fetchReminders(listName: options.listName, includeCompleted: options.includeCompleted) {
        case .success(let reminders):
            reminderRenderer.render(reminders: reminders)
            return 0
        case .failure(let error):
            fputs("\(error.text)\n", stderr)
            return 1
        }
    }

    /// Handles `reminders add` — creates a new reminder in the target list.
    /// - Returns: A success message with the new reminder's identifier, or a `CLIError`.
    private func createReminder(with options: ReminderAddOptions) -> Result<String, CLIError> {
        let selectedList: EKCalendar
        switch reminderList(named: options.listName) {
        case .success(let list):
            selectedList = list
        case .failure(let error):
            return .failure(error)
        }

        let reminder = EKReminder(eventStore: store)
        reminder.title = options.title
        reminder.calendar = selectedList
        reminder.notes = options.notes

        if let priority = options.priority {
            reminder.priority = priority
        }

        if let dueInput = options.dueInput {
            switch reminderDueDate(from: dueInput) {
            case .success(let due):
                reminder.dueDateComponents = due.components
                if let alarmDate = due.alarmDate {
                    reminder.addAlarm(EKAlarm(absoluteDate: alarmDate))
                }
            case .failure(let error):
                return .failure(error)
            }
        }

        do {
            try store.save(reminder, commit: true)
            return .success("Reminder created.\nID: \(reminder.calendarItemIdentifier)")
        } catch {
            return .failure(.message("Failed to save reminder: \(error.localizedDescription)"))
        }
    }

    /// Handles `reminders done` and `reminders reopen` — toggles completion state.
    private func setReminderCompletion(_ selector: ReminderSelector, completed: Bool) -> Result<String, CLIError> {
        switch resolveReminder(selector) {
        case .success(let reminder):
            reminder.isCompleted = completed

            do {
                try store.save(reminder, commit: true)
                return .success(completed ? "Reminder completed." : "Reminder reopened.")
            } catch {
                return .failure(.message("Failed to update reminder: \(error.localizedDescription)"))
            }

        case .failure(let error):
            return .failure(error)
        }
    }

    /// Handles `reminders remove` — deletes a reminder.
    private func removeReminder(_ selector: ReminderSelector) -> Result<String, CLIError> {
        switch resolveReminder(selector) {
        case .success(let reminder):
            do {
                try store.remove(reminder, commit: true)
                return .success("Reminder removed.")
            } catch {
                return .failure(.message("Failed to remove reminder: \(error.localizedDescription)"))
            }

        case .failure(let error):
            return .failure(error)
        }
    }

    /// Handles `reminders edit` — applies the requested changes and saves the reminder.
    /// - Returns: A success message with the reminder's identifier, or a `CLIError`.
    private func editReminder(with options: ReminderEditOptions) -> Result<String, CLIError> {
        let reminder: EKReminder
        switch resolveReminder(.id(options.id)) {
        case .success(let resolved):
            reminder = resolved
        case .failure(let error):
            return .failure(error)
        }

        if let title = options.title {
            reminder.title = title
        }

        if let listName = options.listName {
            switch reminderList(named: listName) {
            case .success(let selectedList):
                reminder.calendar = selectedList
            case .failure(let error):
                return .failure(error)
            }
        }

        if let notes = options.notes {
            reminder.notes = notes
        }

        if options.clearNotes {
            reminder.notes = nil
        }

        if let priority = options.priority {
            reminder.priority = priority
        }

        if let dueInput = options.dueInput {
            switch reminderDueDate(from: dueInput) {
            case .success(let due):
                reminder.dueDateComponents = due.components
                clearAbsoluteAlarms(on: reminder)
                if let alarmDate = due.alarmDate {
                    reminder.addAlarm(EKAlarm(absoluteDate: alarmDate))
                }
            case .failure(let error):
                return .failure(error)
            }
        }

        if options.clearDue {
            reminder.dueDateComponents = nil
            clearAbsoluteAlarms(on: reminder)
        }

        do {
            try store.save(reminder, commit: true)
            return .success("Reminder updated.\nID: \(reminder.calendarItemIdentifier)")
        } catch {
            return .failure(.message("Failed to update reminder: \(error.localizedDescription)"))
        }
    }

    /// Removes absolute-date alarms so a changed or cleared due date doesn't leave stale notifications.
    private func clearAbsoluteAlarms(on reminder: EKReminder) {
        for alarm in reminder.alarms ?? [] where alarm.absoluteDate != nil {
            reminder.removeAlarm(alarm)
        }
    }
}
