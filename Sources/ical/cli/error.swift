import Foundation

/// A simple error type carrying a human-readable message for CLI output.
enum CLIError: Error {
    case message(String)

    /// The error message suitable for printing to stderr.
    var text: String {
        switch self {
        case .message(let value):
            return value
        }
    }
}
