import ArgumentParser
import XCTest

@testable import FluidAudioCommand

final class TtsCommandTests: XCTestCase {
  private var temporaryDirectories: [URL] = []

  override func tearDownWithError() throws {
    for directory in temporaryDirectories {
      try FileManager.default.removeItem(at: directory)
    }
    temporaryDirectories.removeAll()
    try super.tearDownWithError()
  }

  func testValidation() throws {
    XCTAssertThrowsError(try TtsCommand.parse(["   "]).validate())
    XCTAssertThrowsError(try TtsCommand.parse(["hello", "--speed", "0"]).validate())
    XCTAssertThrowsError(try TtsCommand.parse(["hello", "--speed", "4.1"]).validate())
    XCTAssertThrowsError(try TtsCommand.parse(["hello", "--voice", "   "]).validate())

    let parsed = try TtsCommand.parse(["hello", "--voice", "af_heart"])
    try parsed.validate()
    XCTAssertEqual(parsed.voice, "af_heart")
  }

  func testValidationDoesNotCreateOutputDirectories() throws {
    let directory = try makeTemporaryDirectory()
    let outputURL = directory.appendingPathComponent("nested/out.wav")
    let parsed = try TtsCommand.parse(["hello", "--output", outputURL.path])

    try parsed.validate()

    XCTAssertFalse(
      FileManager.default.fileExists(atPath: outputURL.deletingLastPathComponent().path))
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    temporaryDirectories.append(directory)
    return directory
  }
}
