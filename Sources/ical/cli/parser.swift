import Foundation

struct CommandParser {
    func parse(arguments: [String]) -> ParseResult {
        guard arguments.count >= 2 else {
            return .error(usageText)
        }

        let subcommand = arguments[1]
        let remaining = Array(arguments.dropFirst(2))

        switch subcommand {
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

        default:
            return .error("Unknown command: \(subcommand)\n\n\(usageText)")
        }
    }

    private func parseAddOptions(_ arguments: [String]) -> Result<AddOptions, CLIError> {
        var title: String?
        var startInput: String?
        var endInput: String?
        var calendarName: String?
        var location: String?
        var notes: String?
        var isAllDay = false

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

        return .success(
            AddOptions(
                title: finalTitle,
                startInput: finalStart,
                endInput: finalEnd,
                calendarName: nonEmpty(calendarName),
                location: nonEmpty(location),
                notes: nonEmpty(notes),
                isAllDay: isAllDay
            )
        )
    }

    private func parseRemoveOptions(_ arguments: [String]) -> Result<RemoveOptions, CLIError> {
        var id: String?
        var title: String?
        var startInput: String?
        var calendarName: String?

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

            default:
                return .failure(.message("Unknown option: \(token)"))
            }
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
                    calendarName: nil
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
                calendarName: calendarName
            )
        )
    }

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
            clearNotes

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
                clearNotes: clearNotes
            )
        )
    }

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
