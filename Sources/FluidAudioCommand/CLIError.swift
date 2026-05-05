import Foundation

enum CLIError: LocalizedError, CustomStringConvertible, Sendable {
  case inputNotFound(String)
  case inputIsDirectory(String)
  case inputNotReadable(String)
  case invalidAudioFile(String)
  case invalidOutputPath(String)
  case invalidValue(String)

  var errorDescription: String? { description }

  var description: String {
    switch self {
    case .inputNotFound(let path):
      return "Input file does not exist: \(path)"
    case .inputIsDirectory(let path):
      return "Expected a file but found a directory: \(path)"
    case .inputNotReadable(let path):
      return "Input file is not readable: \(path)"
    case .invalidAudioFile(let path):
      return "Input file is not a readable audio file: \(path)"
    case .invalidOutputPath(let path):
      return "Invalid output path: \(path)"
    case .invalidValue(let message):
      return message
    }
  }
}
