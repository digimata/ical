import EventKit
import Foundation

func nonEmpty(_ value: String?) -> String? {
    guard let value else {
        return nil
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

func eventTitle(_ event: EKEvent) -> String {
    nonEmpty(event.title) ?? "(No Title)"
}
