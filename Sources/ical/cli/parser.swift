import Foundation

/// Parses raw CLI arguments into a structured `Command`.
struct CommandParser {
    /// Parses the given arguments array into a `ParseResult`.
    /// - Parameter arguments: The full argument list including the executable name at index 0.
    /// - Returns: A `.command` on success or `.error` with a user-facing message on failure.
    func parse(arguments: [String]) -> ParseResult {
        guard arguments.count >= 2 else {
            return .error(usageText)
        }

        let subcommand = arguments[1]
        let remaining = Array(arguments.dropFirst(2))

        switch subcommand {
        case "version", "--version", "-v":
            guard remaining.isEmpty else {
                return .error("Unexpected arguments for 'version'.\n\n\(usageText)")
            }
            return .command(.version)

        case "today":
            guard remaining.isEmpty else {
                return .error("Unexpected arguments for 'today'.\n\n\(usageText)")
            }
            return .command(.today)

        case "tomorrow":
            guard remaining.isEmpty else {
                return .error("Unexpected arguments for 'tomorrow'.\n\n\(usageText)")
            }
            return .command(.tomorrow)

        case "week":
            guard remaining.isEmpty else {
                return .error("Unexpected arguments for 'week'.\n\n\(usageText)")
            }
            return .command(.week)

        case "add":
            switch parseAddOptions(remaining) {
            case .success(let options):
                return .command(.add(options))
            case .failure(let error):
                return .error("\(error.text)\n\n\(usageText)")
            }

        case "remove":
            switch parseRemoveOptions(remaining) {
            case .success(let options):
                return .command(.remove(options))
            case .failure(let error):
                return .error("\(error.text)\n\n\(usageText)")
            }

        case "edit":
            switch parseEditOptions(remaining) {
            case .success(let options):
                return .command(.edit(options))
            case .failure(let error):
                return .error("\(error.text)\n\n\(usageText)")
            }

        case "reminders":
            switch parseRemindersCommand(remaining) {
            case .success(let command):
                return .command(.reminders(command))
            case .failure(let error):
                return .error("\(error.text)\n\n\(usageText)")
            }

        default:
            return .error("Unknown command: \(subcommand)\n\n\(usageText)")
        }
    }

    /// Parses `--key value` pairs from the argument list into `AddOptions`.
    private func parseAddOptions(_ arguments: [String]) -> Result<AddOptions, CLIError> {
        var title: String?
        var startInput: String?
        var endInput: String?
        var calendarName: String?
        var location: String?
        var notes: String?
        var isAllDay = false
        var recurrencePattern: RecurrencePattern?
        var recurrenceEndInput: String?

        var index = 0
        while index < arguments.count {
            let token = arguments[index]

            guard token.hasPrefix("--") else {
                return .failure(.message("Unexpected argument: \(token)"))
            }

            switch token {
            case "--title":
                guard title == nil else {
                    return .failure(.message("Duplicate option: --title"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index) else {
                    return .failure(.message("Missing value for --title"))
                }
                title = value

            case "--start":
                guard startInput == nil else {
                    return .failure(.message("Duplicate option: --start"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index) else {
                    return .failure(.message("Missing value for --start"))
                }
                startInput = value

            case "--end":
                guard endInput == nil else {
                    return .failure(.message("Duplicate option: --end"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index) else {
                    return .failure(.message("Missing value for --end"))
                }
                endInput = value

            case "--calendar":
                guard calendarName == nil else {
                    return .failure(.message("Duplicate option: --calendar"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index) else {
                    return .failure(.message("Missing value for --calendar"))
                }
                calendarName = value

            case "--location":
                guard location == nil else {
                    return .failure(.message("Duplicate option: --location"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index) else {
                    return .failure(.message("Missing value for --location"))
                }
                location = value

            case "--notes":
                guard notes == nil else {
                    return .failure(.message("Duplicate option: --notes"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index) else {
                    return .failure(.message("Missing value for --notes"))
                }
                notes = value

            case "--all-day":
                isAllDay = true
                index += 1

            case "--recurrence":
                guard recurrencePattern == nil else {
                    return .failure(.message("Duplicate option: --recurrence"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --recurrence"))
                }
                guard let parsedPattern = parseRecurrencePattern(finalValue) else {
                    return .failure(
                        .message(
                            "Invalid value for --recurrence: \(finalValue). Expected daily, weekly, monthly, or yearly."
                        ))
                }
                recurrencePattern = parsedPattern

            case "--recurrence-end":
                guard recurrenceEndInput == nil else {
                    return .failure(.message("Duplicate option: --recurrence-end"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --recurrence-end"))
                }
                recurrenceEndInput = finalValue

            default:
                return .failure(.message("Unknown option: \(token)"))
            }
        }

        guard let rawTitle = title, let finalTitle = nonEmpty(rawTitle) else {
            return .failure(.message("Missing required option: --title"))
        }

        guard let rawStart = startInput, let finalStart = nonEmpty(rawStart) else {
            return .failure(.message("Missing required option: --start"))
        }

        guard let rawEnd = endInput, let finalEnd = nonEmpty(rawEnd) else {
            return .failure(.message("Missing required option: --end"))
        }

        guard recurrencePattern != nil || recurrenceEndInput == nil else {
            return .failure(.message("--recurrence-end requires --recurrence."))
        }

        return .success(
            AddOptions(
                title: finalTitle,
                startInput: finalStart,
                endInput: finalEnd,
                calendarName: nonEmpty(calendarName),
                location: nonEmpty(location),
                notes: nonEmpty(notes),
                isAllDay: isAllDay,
                recurrencePattern: recurrencePattern,
                recurrenceEndInput: recurrenceEndInput
            )
        )
    }

    /// Parses `--key value` pairs from the argument list into `RemoveOptions`.
    private func parseRemoveOptions(_ arguments: [String]) -> Result<RemoveOptions, CLIError> {
        var id: String?
        var title: String?
        var startInput: String?
        var calendarName: String?
        var thisOnly = false
        var allFuture = false

        var index = 0
        while index < arguments.count {
            let token = arguments[index]

            guard token.hasPrefix("--") else {
                return .failure(.message("Unexpected argument: \(token)"))
            }

            switch token {
            case "--id":
                guard id == nil else {
                    return .failure(.message("Duplicate option: --id"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --id"))
                }
                id = finalValue

            case "--title":
                guard title == nil else {
                    return .failure(.message("Duplicate option: --title"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --title"))
                }
                title = finalValue

            case "--start":
                guard startInput == nil else {
                    return .failure(.message("Duplicate option: --start"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --start"))
                }
                startInput = finalValue

            case "--calendar":
                guard calendarName == nil else {
                    return .failure(.message("Duplicate option: --calendar"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --calendar"))
                }
                calendarName = finalValue

            case "--this-only":
                thisOnly = true
                index += 1

            case "--all-future":
                allFuture = true
                index += 1

            default:
                return .failure(.message("Unknown option: \(token)"))
            }
        }

        guard !(thisOnly && allFuture) else {
            return .failure(.message("--this-only and --all-future cannot be used together."))
        }

        let recurrenceSpan: RecurrenceSpanSelection
        if thisOnly {
            recurrenceSpan = .thisOnly
        } else if allFuture {
            recurrenceSpan = .allFuture
        } else {
            recurrenceSpan = .automatic
        }

        if let id {
            guard title == nil, startInput == nil, calendarName == nil else {
                return .failure(.message("Use either --id or --title/--start selector, not both."))
            }

            return .success(
                RemoveOptions(
                    id: id,
                    title: nil,
                    startInput: nil,
                    calendarName: nil,
                    recurrenceSpan: recurrenceSpan
                )
            )
        }

        guard let title else {
            return .failure(.message("Missing selector. Use --id or --title with --start."))
        }

        guard let startInput else {
            return .failure(.message("Missing required option: --start"))
        }

        return .success(
            RemoveOptions(
                id: nil,
                title: title,
                startInput: startInput,
                calendarName: calendarName,
                recurrenceSpan: recurrenceSpan
            )
        )
    }

    /// Parses `--key value` pairs from the argument list into `EditOptions`.
    private func parseEditOptions(_ arguments: [String]) -> Result<EditOptions, CLIError> {
        var id: String?
        var title: String?
        var startInput: String?
        var endInput: String?
        var calendarName: String?
        var location: String?
        var notes: String?
        var makeAllDay = false
        var makeTimed = false
        var clearLocation = false
        var clearNotes = false
        var recurrencePattern: RecurrencePattern?
        var recurrenceEndInput: String?
        var clearRecurrence = false
        var thisOnly = false
        var allFuture = false

        var index = 0
        while index < arguments.count {
            let token = arguments[index]

            guard token.hasPrefix("--") else {
                return .failure(.message("Unexpected argument: \(token)"))
            }

            switch token {
            case "--id":
                guard id == nil else {
                    return .failure(.message("Duplicate option: --id"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --id"))
                }
                id = finalValue

            case "--title":
                guard title == nil else {
                    return .failure(.message("Duplicate option: --title"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --title"))
                }
                title = finalValue

            case "--start":
                guard startInput == nil else {
                    return .failure(.message("Duplicate option: --start"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --start"))
                }
                startInput = finalValue

            case "--end":
                guard endInput == nil else {
                    return .failure(.message("Duplicate option: --end"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --end"))
                }
                endInput = finalValue

            case "--calendar":
                guard calendarName == nil else {
                    return .failure(.message("Duplicate option: --calendar"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --calendar"))
                }
                calendarName = finalValue

            case "--location":
                guard location == nil else {
                    return .failure(.message("Duplicate option: --location"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --location"))
                }
                location = finalValue

            case "--notes":
                guard notes == nil else {
                    return .failure(.message("Duplicate option: --notes"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --notes"))
                }
                notes = finalValue

            case "--all-day":
                makeAllDay = true
                index += 1

            case "--timed":
                makeTimed = true
                index += 1

            case "--clear-location":
                clearLocation = true
                index += 1

            case "--clear-notes":
                clearNotes = true
                index += 1

            case "--recurrence":
                guard recurrencePattern == nil else {
                    return .failure(.message("Duplicate option: --recurrence"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --recurrence"))
                }
                guard let parsedPattern = parseRecurrencePattern(finalValue) else {
                    return .failure(
                        .message(
                            "Invalid value for --recurrence: \(finalValue). Expected daily, weekly, monthly, or yearly."
                        ))
                }
                recurrencePattern = parsedPattern

            case "--recurrence-end":
                guard recurrenceEndInput == nil else {
                    return .failure(.message("Duplicate option: --recurrence-end"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --recurrence-end"))
                }
                recurrenceEndInput = finalValue

            case "--clear-recurrence":
                clearRecurrence = true
                index += 1

            case "--this-only":
                thisOnly = true
                index += 1

            case "--all-future":
                allFuture = true
                index += 1

            default:
                return .failure(.message("Unknown option: \(token)"))
            }
        }

        guard let id else {
            return .failure(.message("Missing required option: --id"))
        }

        guard !(makeAllDay && makeTimed) else {
            return .failure(.message("--all-day and --timed cannot be used together."))
        }

        guard !(clearLocation && location != nil) else {
            return .failure(.message("Use either --location or --clear-location, not both."))
        }

        guard !(clearNotes && notes != nil) else {
            return .failure(.message("Use either --notes or --clear-notes, not both."))
        }

        guard recurrencePattern != nil || recurrenceEndInput == nil else {
            return .failure(.message("--recurrence-end requires --recurrence."))
        }

        guard !(clearRecurrence && recurrencePattern != nil) else {
            return .failure(.message("Use either --recurrence or --clear-recurrence, not both."))
        }

        guard !(thisOnly && allFuture) else {
            return .failure(.message("--this-only and --all-future cannot be used together."))
        }

        let recurrenceSpan: RecurrenceSpanSelection
        if thisOnly {
            recurrenceSpan = .thisOnly
        } else if allFuture {
            recurrenceSpan = .allFuture
        } else {
            recurrenceSpan = .automatic
        }

        let hasUpdate =
            title != nil ||
            startInput != nil ||
            endInput != nil ||
            calendarName != nil ||
            location != nil ||
            notes != nil ||
            makeAllDay ||
            makeTimed ||
            clearLocation ||
            clearNotes ||
            recurrencePattern != nil ||
            clearRecurrence

        guard hasUpdate else {
            return .failure(.message("No changes provided."))
        }

        return .success(
            EditOptions(
                id: id,
                title: title,
                startInput: startInput,
                endInput: endInput,
                calendarName: calendarName,
                location: location,
                notes: notes,
                makeAllDay: makeAllDay,
                makeTimed: makeTimed,
                clearLocation: clearLocation,
                clearNotes: clearNotes,
                recurrencePattern: recurrencePattern,
                recurrenceEndInput: recurrenceEndInput,
                clearRecurrence: clearRecurrence,
                recurrenceSpan: recurrenceSpan
            )
        )
    }

    /// Parses the `reminders` subcommand family. A bare `reminders` (or options-only tail) means `list`.
    private func parseRemindersCommand(_ arguments: [String]) -> Result<RemindersCommand, CLIError> {
        guard let first = arguments.first, !first.hasPrefix("--") else {
            return parseReminderListOptions(arguments).map(RemindersCommand.list)
        }

        let remaining = Array(arguments.dropFirst())

        switch first {
        case "list":
            return parseReminderListOptions(remaining).map(RemindersCommand.list)
        case "add":
            return parseReminderAddOptions(remaining).map(RemindersCommand.add)
        case "done":
            return parseReminderSelector(remaining).map(RemindersCommand.done)
        case "reopen":
            return parseReminderSelector(remaining).map(RemindersCommand.reopen)
        case "remove":
            return parseReminderSelector(remaining).map(RemindersCommand.remove)
        case "edit":
            return parseReminderEditOptions(remaining).map(RemindersCommand.edit)
        default:
            return .failure(.message("Unknown reminders command: \(first)"))
        }
    }

    /// Parses `--key value` pairs from the argument list into `ReminderListOptions`.
    private func parseReminderListOptions(_ arguments: [String]) -> Result<ReminderListOptions, CLIError> {
        var includeCompleted = false
        var listName: String?

        var index = 0
        while index < arguments.count {
            let token = arguments[index]

            guard token.hasPrefix("--") else {
                return .failure(.message("Unexpected argument: \(token)"))
            }

            switch token {
            case "--all":
                includeCompleted = true
                index += 1

            case "--list":
                guard listName == nil else {
                    return .failure(.message("Duplicate option: --list"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --list"))
                }
                listName = finalValue

            default:
                return .failure(.message("Unknown option: \(token)"))
            }
        }

        return .success(ReminderListOptions(includeCompleted: includeCompleted, listName: listName))
    }

    /// Parses `--key value` pairs from the argument list into `ReminderAddOptions`.
    private func parseReminderAddOptions(_ arguments: [String]) -> Result<ReminderAddOptions, CLIError> {
        var title: String?
        var dueInput: String?
        var listName: String?
        var notes: String?
        var priority: Int?

        var index = 0
        while index < arguments.count {
            let token = arguments[index]

            guard token.hasPrefix("--") else {
                return .failure(.message("Unexpected argument: \(token)"))
            }

            switch token {
            case "--title":
                guard title == nil else {
                    return .failure(.message("Duplicate option: --title"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --title"))
                }
                title = finalValue

            case "--due":
                guard dueInput == nil else {
                    return .failure(.message("Duplicate option: --due"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --due"))
                }
                dueInput = finalValue

            case "--list":
                guard listName == nil else {
                    return .failure(.message("Duplicate option: --list"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --list"))
                }
                listName = finalValue

            case "--notes":
                guard notes == nil else {
                    return .failure(.message("Duplicate option: --notes"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --notes"))
                }
                notes = finalValue

            case "--priority":
                guard priority == nil else {
                    return .failure(.message("Duplicate option: --priority"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --priority"))
                }
                guard let parsedPriority = parseReminderPriority(finalValue) else {
                    return .failure(.message("Invalid value for --priority: \(finalValue). Expected 0-9 (0 = none, 1 = high, 5 = medium, 9 = low)."))
                }
                priority = parsedPriority

            default:
                return .failure(.message("Unknown option: \(token)"))
            }
        }

        guard let title else {
            return .failure(.message("Missing required option: --title"))
        }

        return .success(
            ReminderAddOptions(
                title: title,
                dueInput: dueInput,
                listName: listName,
                notes: notes,
                priority: priority
            )
        )
    }

    /// Parses a reminder selector (`--id` or `--title`) for `done`, `reopen`, and `remove`.
    private func parseReminderSelector(_ arguments: [String]) -> Result<ReminderSelector, CLIError> {
        var id: String?
        var title: String?

        var index = 0
        while index < arguments.count {
            let token = arguments[index]

            guard token.hasPrefix("--") else {
                return .failure(.message("Unexpected argument: \(token)"))
            }

            switch token {
            case "--id":
                guard id == nil else {
                    return .failure(.message("Duplicate option: --id"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --id"))
                }
                id = finalValue

            case "--title":
                guard title == nil else {
                    return .failure(.message("Duplicate option: --title"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --title"))
                }
                title = finalValue

            default:
                return .failure(.message("Unknown option: \(token)"))
            }
        }

        if let id {
            guard title == nil else {
                return .failure(.message("Use either --id or --title, not both."))
            }
            return .success(.id(id))
        }

        guard let title else {
            return .failure(.message("Missing selector. Use --id or --title."))
        }

        return .success(.title(title))
    }

    /// Parses `--key value` pairs from the argument list into `ReminderEditOptions`.
    private func parseReminderEditOptions(_ arguments: [String]) -> Result<ReminderEditOptions, CLIError> {
        var id: String?
        var title: String?
        var dueInput: String?
        var clearDue = false
        var listName: String?
        var notes: String?
        var clearNotes = false
        var priority: Int?

        var index = 0
        while index < arguments.count {
            let token = arguments[index]

            guard token.hasPrefix("--") else {
                return .failure(.message("Unexpected argument: \(token)"))
            }

            switch token {
            case "--id":
                guard id == nil else {
                    return .failure(.message("Duplicate option: --id"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --id"))
                }
                id = finalValue

            case "--title":
                guard title == nil else {
                    return .failure(.message("Duplicate option: --title"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --title"))
                }
                title = finalValue

            case "--due":
                guard dueInput == nil else {
                    return .failure(.message("Duplicate option: --due"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --due"))
                }
                dueInput = finalValue

            case "--clear-due":
                clearDue = true
                index += 1

            case "--list":
                guard listName == nil else {
                    return .failure(.message("Duplicate option: --list"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --list"))
                }
                listName = finalValue

            case "--notes":
                guard notes == nil else {
                    return .failure(.message("Duplicate option: --notes"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --notes"))
                }
                notes = finalValue

            case "--clear-notes":
                clearNotes = true
                index += 1

            case "--priority":
                guard priority == nil else {
                    return .failure(.message("Duplicate option: --priority"))
                }
                guard let value = collectOptionValue(from: arguments, index: &index), let finalValue = nonEmpty(value) else {
                    return .failure(.message("Missing value for --priority"))
                }
                guard let parsedPriority = parseReminderPriority(finalValue) else {
                    return .failure(.message("Invalid value for --priority: \(finalValue). Expected 0-9 (0 = none, 1 = high, 5 = medium, 9 = low)."))
                }
                priority = parsedPriority

            default:
                return .failure(.message("Unknown option: \(token)"))
            }
        }

        guard let id else {
            return .failure(.message("Missing required option: --id"))
        }

        guard !(clearDue && dueInput != nil) else {
            return .failure(.message("Use either --due or --clear-due, not both."))
        }

        guard !(clearNotes && notes != nil) else {
            return .failure(.message("Use either --notes or --clear-notes, not both."))
        }

        let hasUpdate =
            title != nil ||
            dueInput != nil ||
            clearDue ||
            listName != nil ||
            notes != nil ||
            clearNotes ||
            priority != nil

        guard hasUpdate else {
            return .failure(.message("No changes provided."))
        }

        return .success(
            ReminderEditOptions(
                id: id,
                title: title,
                dueInput: dueInput,
                clearDue: clearDue,
                listName: listName,
                notes: notes,
                clearNotes: clearNotes,
                priority: priority
            )
        )
    }

    /// Parses reminder priority values (`0`-`9`; 0 = none, 1 = high, 5 = medium, 9 = low).
    private func parseReminderPriority(_ value: String) -> Int? {
        guard let priority = Int(value), (0...9).contains(priority) else {
            return nil
        }
        return priority
    }

    /// Parses recurrence option values (`daily`, `weekly`, `monthly`, `yearly`).
    private func parseRecurrencePattern(_ value: String) -> RecurrencePattern? {
        RecurrencePattern(rawValue: value.lowercased())
    }

    /// Advances past the current flag and collects all subsequent non-flag tokens as a single space-joined value.
    /// - Parameters:
    ///   - arguments: The full argument list.
    ///   - index: The current position (pointing at the flag); updated to the next unprocessed position on return.
    /// - Returns: The collected value, or `nil` if no tokens follow the flag.
    private func collectOptionValue(from arguments: [String], index: inout Int) -> String? {
        index += 1
        var chunks: [String] = []

        while index < arguments.count, !arguments[index].hasPrefix("--") {
            chunks.append(arguments[index])
            index += 1
        }

        guard !chunks.isEmpty else {
            return nil
        }

        return chunks.joined(separator: " ")
    }
}
