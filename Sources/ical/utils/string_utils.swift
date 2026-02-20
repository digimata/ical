import EventKit
import Foundation

/// Returns the trimmed string if it's non-nil and non-empty, otherwise `nil`.
func nonEmpty(_ value: String?) -> String? {
    guard let value else {
        return nil
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

/// Returns the event's title, falling back to `"(No Title)"` if blank or nil.
func eventTitle(_ event: EKEvent) -> String {
    nonEmpty(event.title) ?? "(No Title)"
}
