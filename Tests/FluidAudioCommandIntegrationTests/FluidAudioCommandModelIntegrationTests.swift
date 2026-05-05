import Foundation
import XCTest

final class FluidAudioCommandModelIntegrationTests: CLIIntegrationTestCase {
  func testModelBackedCommandsRunAgainstGeneratedSpeechExample() throws {
    let directory = try makeTemporaryDirectory()
    let speechURL = directory.appendingPathComponent("hello.wav")
    let text = "Hello from Fluid Audio."

    try synthesizeSpeechExample(text: text, to: speechURL)
    try assertVadRuns(on: speechURL)
    try assertDiarizationRuns(on: speechURL)
    try assertTranscriptionRuns(on: speechURL)
  }

  private func synthesizeSpeechExample(text: String, to speechURL: URL) throws {
    let tts = try runFluidaudio([
      "tts",
      text,
      "--output",
      speechURL.path,
      "--json",
      "--compact",
      "--quiet",
    ])
    XCTAssertEqual(tts.exitCode, 0, tts.diagnostics)

    let ttsJSON = try decodeJSONObject(from: tts.stdout)
    XCTAssertEqual(ttsJSON["text"] as? String, text)
    XCTAssertEqual(ttsJSON["outputFile"] as? String, speechURL.path)
    XCTAssertGreaterThan(try number(ttsJSON["bytes"]), 44)
    XCTAssertTrue(FileManager.default.fileExists(atPath: speechURL.path))
    XCTAssertTrue(try Data(contentsOf: speechURL).starts(with: Data("RIFF".utf8)))
  }

  private func assertVadRuns(on speechURL: URL) throws {
    let vad = try runFluidaudio([
      "vad",
      speechURL.path,
      "--json",
      "--compact",
      "--quiet",
      "--threshold",
      "0.2",
    ])
    XCTAssertEqual(vad.exitCode, 0, vad.diagnostics)

    let vadJSON = try decodeJSONObject(from: vad.stdout)
    XCTAssertEqual(vadJSON["audioFile"] as? String, speechURL.path)
    XCTAssertGreaterThan(try number(vadJSON["durationSeconds"]), 0)
    _ = try XCTUnwrap(vadJSON["segments"] as? [Any])
  }

  private func assertDiarizationRuns(on speechURL: URL) throws {
    let diarization = try runFluidaudio([
      "diarize",
      speechURL.path,
      "--json",
      "--compact",
      "--quiet",
      "--chunk-seconds",
      "5",
    ])
    XCTAssertEqual(diarization.exitCode, 0, diarization.diagnostics)

    let diarizationJSON = try decodeJSONObject(from: diarization.stdout)
    XCTAssertEqual(diarizationJSON["audioFile"] as? String, speechURL.path)
    XCTAssertEqual(diarizationJSON["mode"] as? String, "chunked")
    XCTAssertGreaterThan(try number(diarizationJSON["durationSeconds"]), 0)
    _ = try XCTUnwrap(diarizationJSON["segments"] as? [Any])
  }

  private func assertTranscriptionRuns(on speechURL: URL) throws {
    let transcript = try runFluidaudio([
      "transcribe",
      speechURL.path,
      "--json",
      "--compact",
      "--quiet",
      "--language",
      "en",
    ])
    XCTAssertEqual(transcript.exitCode, 0, transcript.diagnostics)

    let transcriptJSON = try decodeJSONObject(from: transcript.stdout)
    XCTAssertEqual(transcriptJSON["audioFile"] as? String, speechURL.path)
    XCTAssertFalse(try string(transcriptJSON["text"]).isEmpty)
    XCTAssertGreaterThan(try number(transcriptJSON["durationSeconds"]), 0)
  }
}
