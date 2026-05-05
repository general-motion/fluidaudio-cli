import FluidAudioCommand
import Foundation
import XCTest

struct CLIResult {
  let exitCode: Int32
  let stdout: String
  let stderr: String

  var diagnostics: String {
    """
    exit: \(exitCode)
    stdout:
    \(stdout)
    stderr:
    \(stderr)
    """
  }
}

class CLIIntegrationTestCase: XCTestCase {
  private static let packageRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

  private var temporaryDirectories: [URL] = []

  override func tearDownWithError() throws {
    for directory in temporaryDirectories {
      try FileManager.default.removeItem(at: directory)
    }
    temporaryDirectories.removeAll()
    try super.tearDownWithError()
  }

  func runFluidaudio(_ arguments: [String]) throws -> CLIResult {
    let executableURL = try fluidaudioExecutableURL()
    let captureDirectory = try makeTemporaryDirectory()
    let stdoutURL = captureDirectory.appendingPathComponent("stdout.txt")
    let stderrURL = captureDirectory.appendingPathComponent("stderr.txt")
    _ = FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
    _ = FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
    let stdout = try FileHandle(forWritingTo: stdoutURL)
    let stderr = try FileHandle(forWritingTo: stderrURL)
    let process = Process()

    process.executableURL = executableURL
    process.arguments = arguments
    process.currentDirectoryURL = Self.packageRoot
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()
    try stdout.close()
    try stderr.close()

    let stdoutData = try Data(contentsOf: stdoutURL)
    let stderrData = try Data(contentsOf: stderrURL)
    return CLIResult(
      exitCode: process.terminationStatus,
      stdout: String(data: stdoutData, encoding: .utf8) ?? "",
      stderr: String(data: stderrData, encoding: .utf8) ?? ""
    )
  }

  func decodeJSONObject(from text: String) throws -> [String: Any] {
    let object = try JSONSerialization.jsonObject(with: Data(text.utf8))
    return try XCTUnwrap(object as? [String: Any])
  }

  func string(_ value: Any?) throws -> String {
    try XCTUnwrap(value as? String)
  }

  func number(_ value: Any?) throws -> Double {
    if let double = value as? Double {
      return double
    }
    if let int = value as? Int {
      return Double(int)
    }
    return try XCTUnwrap(nil as Double?)
  }

  func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    temporaryDirectories.append(directory)
    return directory
  }

  private func fluidaudioExecutableURL() throws -> URL {
    let environment = ProcessInfo.processInfo.environment
    if let override = environment["FLUIDAUDIO_CLI_BINARY"], !override.isEmpty {
      let url = URL(fileURLWithPath: override)
      guard FileManager.default.isExecutableFile(atPath: url.path) else {
        XCTFail("FLUIDAUDIO_CLI_BINARY is not executable: \(url.path)")
        throw CLIIntegrationError.missingExecutable
      }
      return url
    }

    let url = Self.packageRoot.appendingPathComponent(".build/debug/fluidaudio")
    guard FileManager.default.isExecutableFile(atPath: url.path) else {
      throw XCTSkip(
        "Built CLI not found at \(url.path). Run `swift build --product fluidaudio` or set FLUIDAUDIO_CLI_BINARY."
      )
    }
    return url
  }
}

final class FluidAudioCommandIntegrationTests: CLIIntegrationTestCase {
  func testHelpRunsBuiltExecutable() throws {
    let result = try runFluidaudio(["--help"])

    XCTAssertEqual(result.exitCode, 0, result.diagnostics)
    XCTAssertTrue(result.stdout.contains("USAGE: fluidaudio <subcommand>"), result.diagnostics)
    XCTAssertTrue(result.stdout.contains("transcribe"), result.diagnostics)
    XCTAssertTrue(result.stdout.contains("doctor"), result.diagnostics)
    XCTAssertEqual(result.stderr, "")
  }

  func testVersionRunsBuiltExecutable() throws {
    let result = try runFluidaudio(["--version"])

    XCTAssertEqual(result.exitCode, 0, result.diagnostics)
    XCTAssertEqual(
      result.stdout.trimmingCharacters(in: .whitespacesAndNewlines),
      FluidAudioCommand.cliVersion
    )
    XCTAssertEqual(result.stderr, "")
  }

  func testMissingAudioInputFailsBeforeLoadingModels() throws {
    let missingAudio = try makeTemporaryDirectory()
      .appendingPathComponent("missing.wav")

    let result = try runFluidaudio([
      "vad",
      missingAudio.path,
      "--json",
      "--quiet",
    ])

    XCTAssertNotEqual(result.exitCode, 0, result.diagnostics)
    XCTAssertEqual(result.stdout, "")
    XCTAssertTrue(
      result.stderr.contains("Input file does not exist: \(missingAudio.path)"),
      result.diagnostics
    )
  }

  func testInvalidAudioInputFailsBeforeLoadingModels() throws {
    let directory = try makeTemporaryDirectory()
    let invalidAudio = directory.appendingPathComponent("notes.txt")
    try Data("not audio".utf8).write(to: invalidAudio)

    let result = try runFluidaudio([
      "transcribe",
      invalidAudio.path,
      "--json",
      "--quiet",
    ])

    XCTAssertNotEqual(result.exitCode, 0, result.diagnostics)
    XCTAssertEqual(result.stdout, "")
    XCTAssertTrue(
      result.stderr.contains("Input file is not a readable audio file: \(invalidAudio.path)"),
      result.diagnostics
    )
  }
}

private enum CLIIntegrationError: Error {
  case missingExecutable
}
