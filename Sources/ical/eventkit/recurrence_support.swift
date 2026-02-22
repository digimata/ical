import EventKit
import Foundation

extension ICalApp {
    func recurrenceRule(pattern: RecurrencePattern, endInput: String?) -> Result<EKRecurrenceRule, CLIError> {
        let recurrenceEnd: EKRecurrenceEnd?
        if let endInput = nonEmpty(endInput) {
            switch recurrenceEndDate(from: endInput) {
            case .success(let endDate):
                recurrenceEnd = EKRecurrenceEnd(end: endDate)
            case .failure(let error):
                return .failure(error)
            }
        } else {
            recurrenceEnd = nil
        }

        let rule = EKRecurrenceRule(
            recurrenceWith: recurrenceFrequency(for: pattern),
            interval: 1,
            end: recurrenceEnd
        )
        return .success(rule)
    }

    func saveSpan(isRecurring: Bool, selection: RecurrenceSpanSelection) -> Result<EKSpan, CLIError> {
        guard isRecurring else {
            return .success(.thisEvent)
        }

        switch selection {
        case .thisOnly:
            return .success(.thisEvent)
        case .allFuture:
            return .success(.futureEvents)
        case .automatic:
            return .failure(.message("Event is recurring. Use --this-only or --all-future."))
        }
    }

    func isRecurringEvent(_ event: EKEvent) -> Bool {
        if event.occurrenceDate != nil {
            return true
        }

        return !(event.recurrenceRules ?? []).isEmpty
    }

    private func recurrenceFrequency(for pattern: RecurrencePattern) -> EKRecurrenceFrequency {
        switch pattern {
        case .daily:
            return .daily
        case .weekly:
            return .weekly
        case .monthly:
            return .monthly
        case .yearly:
            return .yearly
        }
    }

    private func recurrenceEndDate(from input: String) -> Result<Date, CLIError> {
        guard let parsedDate = dateParser.parse(input) else {
            return .failure(.message("Could not parse --recurrence-end value: \(input)"))
        }

        guard isDateOnlyInput(input) else {
            return .success(parsedDate)
        }

        let startOfDay = calendar.startOfDay(for: parsedDate)
        guard
            let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay),
            let inclusiveEnd = calendar.date(byAdding: .second, value: -1, to: nextDay)
        else {
            return .failure(.message("Could not normalize --recurrence-end value: \(input)"))
        }

        return .success(inclusiveEnd)
    }

    private func isDateOnlyInput(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
    }
}
