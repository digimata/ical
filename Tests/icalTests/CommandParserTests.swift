import XCTest
@testable import ical

final class CommandParserTests: XCTestCase {
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
        default:
            XCTFail("Expected add command")
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
