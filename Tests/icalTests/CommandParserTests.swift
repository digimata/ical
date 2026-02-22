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
}
