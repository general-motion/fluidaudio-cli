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
      "--compact",
      "--quiet",
      "--verbose",
    ])

    XCTAssertTrue(options.json)
    XCTAssertTrue(options.compact)
    XCTAssertTrue(options.quiet)
    XCTAssertTrue(options.verbose)
  }

  func testCommonOutputOptionsRejectsRemovedFormattingFlag() {
    XCTAssertThrowsError(try CommonOutputOptions.parse(["--pretty"]))
  }

  func testCommonOutputOptionsKeepsJSONExpandedUnlessCompact() throws {
    let defaultOptions = try CommonOutputOptions.parse(["--json"])
    XCTAssertFalse(defaultOptions.compact)

    let compactOptions = try CommonOutputOptions.parse(["--json", "--compact"])
    XCTAssertTrue(compactOptions.compact)
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
    ) { _ in "hello\n" }
    let textData = try Data(contentsOf: URL(fileURLWithPath: textPath))
    let text = try XCTUnwrap(String(data: textData, encoding: .utf8))
    XCTAssertEqual(text, "hello\n")

    try Console.emit(
      output,
      options: try CommonOutputOptions.parse(["--json"]),
      output: jsonPath,
      statusDescriptions: StatusDescriptions(text: "fixture text", json: "fixture JSON")
    ) { _ in "hello" }
    let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
    let decoded = try JSONDecoder().decode(
      OutputFixture.self,
      from: jsonData
    )
    XCTAssertEqual(decoded, output)

    let jsonText = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertTrue(jsonText.contains("\n"))
  }

  func testWriteJSONEncodesExpandedByDefaultOrCompactJSON() throws {
    let directory = try makeTemporaryDirectory()
    let compactPath = directory.appendingPathComponent("compact.json").path
    let expandedPath = directory.appendingPathComponent("expanded.json").path
    let output = OutputFixture(message: "ready", count: 1)

    let expandedURL = try Console.writeJSON(output, to: expandedPath)
    let expandedData = try Data(contentsOf: expandedURL)
    let expandedDecoded = try JSONDecoder().decode(OutputFixture.self, from: expandedData)
    XCTAssertEqual(expandedDecoded, output)

    let expandedText = try XCTUnwrap(String(data: expandedData, encoding: .utf8))
    XCTAssertTrue(expandedText.contains("\n"))

    let compactURL = try Console.writeJSON(output, to: compactPath, compact: true)
    let compactData = try Data(contentsOf: compactURL)
    let compactDecoded = try JSONDecoder().decode(OutputFixture.self, from: compactData)
    XCTAssertEqual(compactDecoded, output)

    let compactText = try XCTUnwrap(String(data: compactData, encoding: .utf8))
    XCTAssertFalse(compactText.contains("\n"))
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

    let jsonOptions = try CommonOutputOptions.parse(["--json", "--compact"])
    try Console.emit(
      output,
      options: jsonOptions,
      output: jsonPath,
      statusDescriptions: StatusDescriptions(text: "fixture text", json: "fixture JSON")
    ) { _ in "plain report" }
    let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
    let decoded = try JSONDecoder().decode(
      OutputFixture.self,
      from: jsonData
    )
    XCTAssertEqual(decoded, output)

    let emittedJSON = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertFalse(emittedJSON.contains("\n"))
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    temporaryDirectories.append(directory)
    return directory
  }
}
