import Foundation

enum CLIError: LocalizedError, CustomStringConvertible, Sendable {
  case inputNotFound(String)
  case inputIsDirectory(String)
  case invalidOutputPath(String)
  case invalidValue(String)

  var errorDescription: String? { description }

  var description: String {
    switch self {
    case .inputNotFound(let path):
      return "Input file does not exist: \(path)"
    case .inputIsDirectory(let path):
      return "Expected a file but found a directory: \(path)"
    case .invalidOutputPath(let path):
      return "Invalid output path: \(path)"
    case .invalidValue(let message):
      return message
    }
  }
}
