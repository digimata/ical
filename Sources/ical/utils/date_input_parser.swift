import Foundation

/// Parses user-supplied date/time strings into `Date` values.
/// Supports ISO 8601 formats, local datetime patterns (`yyyy-MM-dd HH:mm`), and relative expressions (`today 14:00`, `tomorrow 09:30`).
struct DateInputParser {
    private let calendar: Calendar
    private let isoDateFormatters: [ISO8601DateFormatter]
    private let localDateTimeFormatters: [DateFormatter]

    /// Creates a parser with the given calendar for date arithmetic.
    init(calendar: Calendar = .current) {
        self.calendar = calendar

        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let internetDateTime = ISO8601DateFormatter()
        internetDateTime.formatOptions = [.withInternetDateTime]

        let fullDate = ISO8601DateFormatter()
        fullDate.formatOptions = [.withFullDate]

        self.isoDateFormatters = [withFractionalSeconds, internetDateTime, fullDate]

        let patterns = [
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd HH:mm:ss"
        ]

        self.localDateTimeFormatters = patterns.map { pattern in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = pattern
            return formatter
        }
    }

    /// Attempts to parse the input string, trying relative expressions first, then ISO 8601, then local datetime formats.
    /// - Parameter input: A date/time string (e.g. `"2025-03-15T10:00"`, `"today 14:00"`).
    /// - Returns: The parsed `Date`, or `nil` if no format matched.
    func parse(_ input: String) -> Date? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if let relative = parseRelative(value) {
            return relative
        }

        for formatter in isoDateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        for formatter in localDateTimeFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    /// Parses relative date expressions like `"today 14:00"` or `"tomorrow 09:30"`.
    private func parseRelative(_ input: String) -> Date? {
        let parts = input.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: { $0.isWhitespace }
        )

        guard parts.count == 2 else {
            return nil
        }

        let dayToken = String(parts[0]).lowercased()
        let timeToken = String(parts[1])

        let dayOffset: Int
        if dayToken == "today" {
            dayOffset = 0
        } else if dayToken == "tomorrow" {
            dayOffset = 1
        } else {
            return nil
        }

        guard let (hour, minute) = parseHourMinute(timeToken) else {
            return nil
        }

        let startOfToday = calendar.startOfDay(for: Date())
        guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else {
            return nil
        }

        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: targetDay)
    }

    /// Parses an `"HH:mm"` string into hour and minute components.
    /// - Returns: A `(hour, minute)` tuple, or `nil` if the format is invalid.
    private func parseHourMinute(_ input: String) -> (Int, Int)? {
        let parts = input.split(separator: ":")

        guard
            parts.count == 2,
            let hour = Int(parts[0]),
            let minute = Int(parts[1]),
            (0...23).contains(hour),
            (0...59).contains(minute)
        else {
            return nil
        }

        return (hour, minute)
    }
}
