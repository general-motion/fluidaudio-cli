import ArgumentParser
import XCTest

@testable import FluidAudioCommand

final class DiarizeCommandTests: XCTestCase {
  func testParsesModes() throws {
    let defaultParsed = try DiarizeCommand.parse(["meeting.wav"])
    let fullFileParsed = try DiarizeCommand.parse(["meeting.wav", "--mode", "full-file"])

    XCTAssertEqual(defaultParsed.mode, .chunked)
    XCTAssertEqual(fullFileParsed.mode, .fullFile)
  }

  func testRejectsInvalidOverlap() throws {
    XCTAssertThrowsError(
      try DiarizeCommand.parse([
        "meeting.wav",
        "--chunk-seconds",
        "5",
        "--overlap-seconds",
        "5",
      ]).validate()
    )
  }

  func testRejectsOutOfRangeThreshold() throws {
    XCTAssertThrowsError(
      try DiarizeCommand.parse([
        "meeting.wav",
        "--threshold",
        "0",
      ]).validate()
    )
    XCTAssertThrowsError(
      try DiarizeCommand.parse([
        "meeting.wav",
        "--threshold",
        "1.1",
      ]).validate()
    )
    XCTAssertThrowsError(
      try DiarizeCommand.parse([
        "meeting.wav",
        "--threshold",
        "inf",
      ]).validate()
    )
    XCTAssertThrowsError(
      try DiarizeCommand.parse([
        "meeting.wav",
        "--chunk-seconds",
        "inf",
      ]).validate()
    )
  }

  func testTextRendering() {
    let output = DiarizationOutput(
      audioFile: "meeting.wav",
      mode: "chunked",
      durationSeconds: 2.0,
      processingTimeSeconds: 1.0,
      realTimeFactor: 2.0,
      speakerCount: 1,
      segmentCount: 1,
      segments: [
        DiarizationSegmentOutput(
          speaker: "speaker_0",
          startTimeSeconds: 0.5,
          endTimeSeconds: 1.25,
          durationSeconds: 0.75,
          qualityScore: 0.9
        )
      ]
    )

    XCTAssertEqual(
      DiarizeCommand.renderText(output),
      [
        "Diarization complete: 1 speakers, 1 segments",
        "RTFx: 2.00x",
        "[00:00.500 - 00:01.250] speaker_0",
      ].joined(separator: "\n")
    )
  }
}
