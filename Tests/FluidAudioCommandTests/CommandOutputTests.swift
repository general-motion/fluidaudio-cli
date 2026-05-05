import ArgumentParser
import XCTest

@testable import FluidAudioCommand

final class CommandOutputTests: XCTestCase {
  private struct OutputFixture: Codable, Equatable {
    let message: String
    let count: Int
  }

  private var temporaryDirectories: [URL] = []

  override func tearDownWithError() throws {
    for directory in temporaryDirectories {
      try FileManager.default.removeItem(at: directory)
    }
    temporaryDirectories.removeAll()
    try super.tearDownWithError()
  }

  func testCommonOutputOptionsParseFlags() throws {
    let options = try CommonOutputOptions.parse([
      "--json",
      "--pretty",
      "--quiet",
      "--verbose",
    ])

    XCTAssertTrue(options.json)
    XCTAssertTrue(options.pretty)
    XCTAssertTrue(options.quiet)
    XCTAssertTrue(options.verbose)
  }

  func testEmitWritesTextAndJSONCreatingParentDirectories() throws {
    let directory = try makeTemporaryDirectory()
    let textPath = directory.appendingPathComponent("nested/transcript.txt").path
    let jsonPath = directory.appendingPathComponent("nested/result.json").path
    let output = OutputFixture(message: "ready", count: 1)

    try Console.emit(
      output,
      options: try CommonOutputOptions.parse([]),
      output: textPath,
      statusDescriptions: StatusDescriptions(text: "fixture text", json: "fixture JSON")
    ) { _ in "hello" }
    let textData = try Data(contentsOf: URL(fileURLWithPath: textPath))
    let text = try XCTUnwrap(String(data: textData, encoding: .utf8))
    XCTAssertEqual(text, "hello\n")

    try Console.emit(
      output,
      options: try CommonOutputOptions.parse(["--json"]),
      output: jsonPath,
      statusDescriptions: StatusDescriptions(text: "fixture text", json: "fixture JSON")
    ) { _ in "hello" }
    let decoded = try JSONDecoder().decode(
      OutputFixture.self,
      from: Data(contentsOf: URL(fileURLWithPath: jsonPath))
    )
    XCTAssertEqual(decoded, output)
  }

  func testWriteJSONEncodesCompactOrPrettyJSON() throws {
    let directory = try makeTemporaryDirectory()
    let compactPath = directory.appendingPathComponent("compact.json").path
    let prettyPath = directory.appendingPathComponent("pretty.json").path
    let output = OutputFixture(message: "ready", count: 1)

    let compactURL = try Console.writeJSON(output, to: compactPath)
    let compactData = try Data(contentsOf: compactURL)
    let decoded = try JSONDecoder().decode(OutputFixture.self, from: compactData)
    XCTAssertEqual(decoded, output)

    let compactText = try XCTUnwrap(String(data: compactData, encoding: .utf8))
    XCTAssertFalse(compactText.contains("\n"))

    let prettyURL = try Console.writeJSON(output, to: prettyPath, pretty: true)
    let prettyText = try XCTUnwrap(String(data: Data(contentsOf: prettyURL), encoding: .utf8))
    XCTAssertTrue(prettyText.contains("\n"))
  }

  func testConsoleEmitWritesTextOrJSONBasedOnOptions() throws {
    let directory = try makeTemporaryDirectory()
    let textPath = directory.appendingPathComponent("report.txt").path
    let jsonPath = directory.appendingPathComponent("report.json").path
    let output = OutputFixture(message: "ready", count: 1)

    let textOptions = try CommonOutputOptions.parse([])
    try Console.emit(
      output,
      options: textOptions,
      output: textPath,
      statusDescriptions: StatusDescriptions(text: "fixture text", json: "fixture JSON")
    ) { _ in "plain report" }
    let emittedText = try XCTUnwrap(
      String(data: Data(contentsOf: URL(fileURLWithPath: textPath)), encoding: .utf8)
    )
    XCTAssertEqual(emittedText, "plain report\n")

    let jsonOptions = try CommonOutputOptions.parse(["--json"])
    try Console.emit(
      output,
      options: jsonOptions,
      output: jsonPath,
      statusDescriptions: StatusDescriptions(text: "fixture text", json: "fixture JSON")
    ) { _ in "plain report" }
    let decoded = try JSONDecoder().decode(
      OutputFixture.self,
      from: Data(contentsOf: URL(fileURLWithPath: jsonPath))
    )
    XCTAssertEqual(decoded, output)
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    temporaryDirectories.append(directory)
    return directory
  }
}
