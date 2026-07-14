import XCTest
@testable import ical

final class CommandParserTests: XCTestCase {
    func testParsesVersionCommand() {
        let result = CommandParser().parse(arguments: ["ical", "version"])

        switch result {
        case .command(.version):
            break
        default:
            XCTFail("Expected version command")
        }
    }

    func testParsesVersionFlag() {
        let result = CommandParser().parse(arguments: ["ical", "--version"])

        switch result {
        case .command(.version):
            break
        default:
            XCTFail("Expected version command")
        }
    }

    func testParsesTodayCommand() {
        let result = CommandParser().parse(arguments: ["ical", "today"])

        switch result {
        case .command(.today):
            break
        default:
            XCTFail("Expected today command")
        }
    }

    func testParsesAddCommandWithMultiWordValues() {
        let result = CommandParser().parse(arguments: [
            "ical", "add",
            "--title", "Meeting", "with", "Luke",
            "--start", "today", "14:00",
            "--end", "today", "15:00",
            "--calendar", "Work",
            "--location", "Zoom", "Room", "A",
            "--notes", "Discuss", "pricing",
            "--all-day"
        ])

        switch result {
        case .command(.add(let options)):
            XCTAssertEqual(options.title, "Meeting with Luke")
            XCTAssertEqual(options.startInput, "today 14:00")
            XCTAssertEqual(options.endInput, "today 15:00")
            XCTAssertEqual(options.calendarName, "Work")
            XCTAssertEqual(options.location, "Zoom Room A")
            XCTAssertEqual(options.notes, "Discuss pricing")
            XCTAssertTrue(options.isAllDay)
            XCTAssertNil(options.recurrencePattern)
            XCTAssertNil(options.recurrenceEndInput)
        default:
            XCTFail("Expected add command")
        }
    }

    func testParsesAddCommandWithRecurrence() {
        let result = CommandParser().parse(arguments: [
            "ical", "add",
            "--title", "Morning", "Brief",
            "--start", "tomorrow", "10:00",
            "--end", "tomorrow", "10:30",
            "--recurrence", "weekly",
            "--recurrence-end", "2026-03-31"
        ])

        switch result {
        case .command(.add(let options)):
            XCTAssertEqual(options.recurrencePattern, .weekly)
            XCTAssertEqual(options.recurrenceEndInput, "2026-03-31")
        default:
            XCTFail("Expected add command with recurrence")
        }
    }

    func testAddRejectsRecurrenceEndWithoutRecurrence() {
        let result = CommandParser().parse(arguments: [
            "ical", "add",
            "--title", "Morning", "Brief",
            "--start", "tomorrow", "10:00",
            "--end", "tomorrow", "10:30",
            "--recurrence-end", "2026-03-31"
        ])

        switch result {
        case .error(let message):
            XCTAssertTrue(message.contains("--recurrence-end requires --recurrence."))
        default:
            XCTFail("Expected parse error")
        }
    }

    func testRemoveRejectsMixedSelectors() {
        let result = CommandParser().parse(arguments: [
            "ical", "remove",
            "--id", "abc",
            "--title", "Dentist",
            "--start", "today", "10:00"
        ])

        switch result {
        case .error(let message):
            XCTAssertTrue(message.contains("Use either --id or --title/--start selector, not both."))
        default:
            XCTFail("Expected parse error")
        }
    }

    func testRemoveParsesAllFutureSpan() {
        let result = CommandParser().parse(arguments: [
            "ical", "remove",
            "--id", "abc",
            "--all-future"
        ])

        switch result {
        case .command(.remove(let options)):
            XCTAssertEqual(options.id, "abc")
            XCTAssertEqual(options.recurrenceSpan, .allFuture)
        default:
            XCTFail("Expected remove command")
        }
    }

    func testRemoveRejectsConflictingSpanFlags() {
        let result = CommandParser().parse(arguments: [
            "ical", "remove",
            "--id", "abc",
            "--this-only",
            "--all-future"
        ])

        switch result {
        case .error(let message):
            XCTAssertTrue(message.contains("--this-only and --all-future cannot be used together."))
        default:
            XCTFail("Expected parse error")
        }
    }

    func testParsesEditRecurrenceAndSpan() {
        let result = CommandParser().parse(arguments: [
            "ical", "edit",
            "--id", "abc",
            "--recurrence", "monthly",
            "--recurrence-end", "2026-12-31",
            "--all-future"
        ])

        switch result {
        case .command(.edit(let options)):
            XCTAssertEqual(options.recurrencePattern, .monthly)
            XCTAssertEqual(options.recurrenceEndInput, "2026-12-31")
            XCTAssertEqual(options.recurrenceSpan, .allFuture)
            XCTAssertFalse(options.clearRecurrence)
        default:
            XCTFail("Expected edit command")
        }
    }

    func testEditRejectsRecurrenceAndClearRecurrence() {
        let result = CommandParser().parse(arguments: [
            "ical", "edit",
            "--id", "abc",
            "--recurrence", "daily",
            "--clear-recurrence"
        ])

        switch result {
        case .error(let message):
            XCTAssertTrue(message.contains("Use either --recurrence or --clear-recurrence, not both."))
        default:
            XCTFail("Expected parse error")
        }
    }

    func testEditRequiresAtLeastOneChange() {
        let result = CommandParser().parse(arguments: [
            "ical", "edit",
            "--id", "abc"
        ])

        switch result {
        case .error(let message):
            XCTAssertTrue(message.contains("No changes provided."))
        default:
            XCTFail("Expected parse error")
        }
    }

    func testParsesBareRemindersAsList() {
        let result = CommandParser().parse(arguments: ["ical", "reminders"])

        switch result {
        case .command(.reminders(.list(let options))):
            XCTAssertFalse(options.includeCompleted)
            XCTAssertNil(options.listName)
        default:
            XCTFail("Expected reminders list command")
        }
    }

    func testParsesRemindersListWithOptions() {
        let result = CommandParser().parse(arguments: [
            "ical", "reminders", "list",
            "--all",
            "--list", "Groceries"
        ])

        switch result {
        case .command(.reminders(.list(let options))):
            XCTAssertTrue(options.includeCompleted)
            XCTAssertEqual(options.listName, "Groceries")
        default:
            XCTFail("Expected reminders list command")
        }
    }

    func testParsesRemindersAddWithMultiWordValues() {
        let result = CommandParser().parse(arguments: [
            "ical", "reminders", "add",
            "--title", "Buy", "oat", "milk",
            "--due", "tomorrow", "09:00",
            "--list", "Groceries",
            "--notes", "The", "barista", "kind",
            "--priority", "1"
        ])

        switch result {
        case .command(.reminders(.add(let options))):
            XCTAssertEqual(options.title, "Buy oat milk")
            XCTAssertEqual(options.dueInput, "tomorrow 09:00")
            XCTAssertEqual(options.listName, "Groceries")
            XCTAssertEqual(options.notes, "The barista kind")
            XCTAssertEqual(options.priority, 1)
        default:
            XCTFail("Expected reminders add command")
        }
    }

    func testRemindersAddRequiresTitle() {
        let result = CommandParser().parse(arguments: [
            "ical", "reminders", "add",
            "--due", "tomorrow", "09:00"
        ])

        switch result {
        case .error(let message):
            XCTAssertTrue(message.contains("Missing required option: --title"))
        default:
            XCTFail("Expected parse error")
        }
    }

    func testRemindersAddRejectsInvalidPriority() {
        let result = CommandParser().parse(arguments: [
            "ical", "reminders", "add",
            "--title", "Task",
            "--priority", "12"
        ])

        switch result {
        case .error(let message):
            XCTAssertTrue(message.contains("Invalid value for --priority: 12"))
        default:
            XCTFail("Expected parse error")
        }
    }

    func testParsesRemindersDoneByTitle() {
        let result = CommandParser().parse(arguments: [
            "ical", "reminders", "done",
            "--title", "Buy", "oat", "milk"
        ])

        switch result {
        case .command(.reminders(.done(.title(let title)))):
            XCTAssertEqual(title, "Buy oat milk")
        default:
            XCTFail("Expected reminders done command")
        }
    }

    func testRemindersDoneRejectsMixedSelectors() {
        let result = CommandParser().parse(arguments: [
            "ical", "reminders", "done",
            "--id", "abc",
            "--title", "Task"
        ])

        switch result {
        case .error(let message):
            XCTAssertTrue(message.contains("Use either --id or --title, not both."))
        default:
            XCTFail("Expected parse error")
        }
    }

    func testParsesRemindersRemoveById() {
        let result = CommandParser().parse(arguments: [
            "ical", "reminders", "remove",
            "--id", "abc"
        ])

        switch result {
        case .command(.reminders(.remove(.id(let id)))):
            XCTAssertEqual(id, "abc")
        default:
            XCTFail("Expected reminders remove command")
        }
    }

    func testParsesRemindersEdit() {
        let result = CommandParser().parse(arguments: [
            "ical", "reminders", "edit",
            "--id", "abc",
            "--title", "Renamed",
            "--clear-due",
            "--priority", "5"
        ])

        switch result {
        case .command(.reminders(.edit(let options))):
            XCTAssertEqual(options.id, "abc")
            XCTAssertEqual(options.title, "Renamed")
            XCTAssertTrue(options.clearDue)
            XCTAssertEqual(options.priority, 5)
            XCTAssertNil(options.dueInput)
        default:
            XCTFail("Expected reminders edit command")
        }
    }

    func testRemindersEditRejectsDueAndClearDue() {
        let result = CommandParser().parse(arguments: [
            "ical", "reminders", "edit",
            "--id", "abc",
            "--due", "tomorrow", "09:00",
            "--clear-due"
        ])

        switch result {
        case .error(let message):
            XCTAssertTrue(message.contains("Use either --due or --clear-due, not both."))
        default:
            XCTFail("Expected parse error")
        }
    }

    func testRemindersEditRequiresAtLeastOneChange() {
        let result = CommandParser().parse(arguments: [
            "ical", "reminders", "edit",
            "--id", "abc"
        ])

        switch result {
        case .error(let message):
            XCTAssertTrue(message.contains("No changes provided."))
        default:
            XCTFail("Expected parse error")
        }
    }

    func testRemindersRejectsUnknownSubcommand() {
        let result = CommandParser().parse(arguments: ["ical", "reminders", "snooze"])

        switch result {
        case .error(let message):
            XCTAssertTrue(message.contains("Unknown reminders command: snooze"))
        default:
            XCTFail("Expected parse error")
        }
    }
}
