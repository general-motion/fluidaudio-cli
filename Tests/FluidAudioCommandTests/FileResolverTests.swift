import XCTest

@testable import FluidAudioCommand

final class FileResolverTests: XCTestCase {
  private var temporaryDirectories: [URL] = []

  override func tearDownWithError() throws {
    for directory in temporaryDirectories {
      try FileManager.default.removeItem(at: directory)
    }
    temporaryDirectories.removeAll()
    try super.tearDownWithError()
  }

  func testExistingFileRejectsMissingFile() throws {
    let directory = try makeTemporaryDirectory()
    let missingFile = directory.appendingPathComponent("missing.wav")

    XCTAssertThrowsError(try FileResolver.existingFile(missingFile.path)) { error in
      guard case CLIError.inputNotFound = error else {
        return XCTFail("Expected inputNotFound, got \(error)")
      }
    }
  }

  func testExistingFileRejectsDirectory() throws {
    let directory = try makeTemporaryDirectory()

    XCTAssertThrowsError(try FileResolver.existingFile(directory.path)) { error in
      guard case CLIError.inputIsDirectory = error else {
        return XCTFail("Expected inputIsDirectory, got \(error)")
      }
    }
  }

  func testExistingFileRejectsUnreadableFile() throws {
    let directory = try makeTemporaryDirectory()
    let inputURL = directory.appendingPathComponent("secret.wav")
    try Data("secret".utf8).write(to: inputURL)
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: inputURL.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o600], ofItemAtPath: inputURL.path)
    }

    XCTAssertThrowsError(try FileResolver.existingFile(inputURL.path)) { error in
      guard case CLIError.inputNotReadable = error else {
        return XCTFail("Expected inputNotReadable, got \(error)")
      }
    }
  }

  func testAudioFileRejectsInvalidAudio() throws {
    let directory = try makeTemporaryDirectory()
    let inputURL = directory.appendingPathComponent("notes.txt")
    try Data("not audio".utf8).write(to: inputURL)

    XCTAssertThrowsError(try FileResolver.audioFile(inputURL.path)) { error in
      guard case CLIError.invalidAudioFile = error else {
        return XCTFail("Expected invalidAudioFile, got \(error)")
      }
    }
  }

  func testPrepareOutputFileCreatesParentDirectories() throws {
    let directory = try makeTemporaryDirectory()
    let outputURL = directory.appendingPathComponent("nested/result.json")

    let preparedURL = try FileResolver.prepareOutputFile(outputURL.path)

    XCTAssertEqual(preparedURL.path, outputURL.path)
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: outputURL.deletingLastPathComponent().path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
  }

  func testPrepareOutputFileRejectsDirectoryTarget() throws {
    let directory = try makeTemporaryDirectory()

    XCTAssertThrowsError(try FileResolver.prepareOutputFile(directory.path)) { error in
      guard case CLIError.invalidOutputPath = error else {
        return XCTFail("Expected invalidOutputPath, got \(error)")
      }
    }
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    temporaryDirectories.append(directory)
    return directory
  }
}
