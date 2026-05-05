import ArgumentParser
import Foundation

struct CommonOutputOptions: ParsableArguments, Sendable {
  @Flag(help: "Emit machine-readable JSON.")
  var json = false

  @Flag(help: "Pretty-print JSON output.")
  var pretty = false

  @Flag(help: "Suppress non-result status output.")
  var quiet = false

  @Flag(help: "Show additional progress and diagnostic output.")
  var verbose = false
}

struct StatusDescriptions: Sendable {
  let text: String
  let json: String
}

/// Writes command results to stdout or files, while keeping progress/status output on stderr.
enum Console {
  static func status(_ message: String, options: CommonOutputOptions) {
    guard !options.quiet else { return }
    fputs("\(message)\n", stderr)
  }

  private static func lineTerminated(_ text: String) -> String {
    text.hasSuffix("\n") ? text : text + "\n"
  }

  private static func printText(_ text: String) {
    FileHandle.standardOutput.write(Data(lineTerminated(text).utf8))
  }

  private static func writeText(_ text: String, to path: String) throws -> URL {
    let url = try FileResolver.prepareOutputFile(path)
    try Data(text.utf8).write(to: url, options: .atomic)
    return url
  }

  /// Encodes stable JSON by sorting keys; pretty printing is opt-in for human inspection.
  private static func encodeJSON<T: Encodable>(_ value: T, pretty: Bool = false) throws -> Data {
    let encoder = JSONEncoder()
    var formatting: JSONEncoder.OutputFormatting = [.sortedKeys]
    if pretty {
      formatting.insert(.prettyPrinted)
    }
    encoder.outputFormatting = formatting
    return try encoder.encode(value)
  }

  static func printJSON<T: Encodable>(_ value: T, pretty: Bool = false) throws {
    let data = try encodeJSON(value, pretty: pretty)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
  }

  static func writeJSON<T: Encodable>(
    _ value: T,
    to path: String,
    pretty: Bool = false
  ) throws -> URL {
    let url = try FileResolver.prepareOutputFile(path)
    try encodeJSON(value, pretty: pretty).write(to: url, options: .atomic)
    return url
  }

  /// Emits a command result according to common CLI output rules.
  ///
  /// Without `--output`, text or JSON is written to stdout. With `--output`, the same result is
  /// written to a file and a short status message goes to stderr unless `--quiet` is set.
  static func emit<T: Encodable>(
    _ value: T,
    options: CommonOutputOptions,
    output: String?,
    statusDescriptions: StatusDescriptions,
    textRenderer: (T) -> String
  ) throws {
    if let output {
      if options.json {
        let url = try writeJSON(value, to: output, pretty: options.pretty)
        status("Wrote \(statusDescriptions.json) to \(url.path)", options: options)
      } else {
        let url = try writeText(lineTerminated(textRenderer(value)), to: output)
        status("Wrote \(statusDescriptions.text) to \(url.path)", options: options)
      }
      return
    }

    if options.json {
      try printJSON(value, pretty: options.pretty)
    } else {
      printText(textRenderer(value))
    }
  }
}
