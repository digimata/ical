import Foundation
import XCTest
@testable import ical

final class DateInputParserTests: XCTestCase {
    func testParsesTodayTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let parser = DateInputParser(calendar: calendar)

        let parsed = try XCTUnwrap(parser.parse("today 09:45"))
        let components = calendar.dateComponents([.hour, .minute], from: parsed)

        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 45)
    }

    func testParsesTomorrowTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let parser = DateInputParser(calendar: calendar)

        let parsed = try XCTUnwrap(parser.parse("tomorrow 07:15"))
        let todayStart = calendar.startOfDay(for: Date())
        let parsedStart = calendar.startOfDay(for: parsed)
        let dayDelta = calendar.dateComponents([.day], from: todayStart, to: parsedStart).day

        XCTAssertEqual(dayDelta, 1)
    }

    func testParsesISODateTime() {
        let parser = DateInputParser()
        let parsed = parser.parse("2026-02-20T14:00:00Z")
        XCTAssertNotNil(parsed)
    }

    func testParsesLocalDateTime() {
        let parser = DateInputParser()
        let parsed = parser.parse("2026-02-20 14:00")
        XCTAssertNotNil(parsed)
    }

    func testRejectsInvalidTimeInput() {
        let parser = DateInputParser()
        XCTAssertNil(parser.parse("today 99:99"))
    }
}
