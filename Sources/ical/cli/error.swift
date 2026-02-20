import Foundation

enum CLIError: Error {
    case message(String)

    var text: String {
        switch self {
        case .message(let value):
            return value
        }
    }
}
