import ArgumentParser
@preconcurrency import FluidAudio
import XCTest

@testable import FluidAudioCommand

final class VadCommandTests: XCTestCase {
  func testValidation() throws {
    XCTAssertThrowsError(
      try VadCommand.parse([
        "audio.wav",
        "--threshold",
        "-0.1",
      ]).validate()
    )
    XCTAssertThrowsError(
      try VadCommand.parse([
        "audio.wav",
        "--threshold",
        "1.1",
      ]).validate()
    )
    XCTAssertThrowsError(
      try VadCommand.parse([
        "audio.wav",
        "--min-speech-ms",
        "-1",
      ]).validate()
    )
    XCTAssertThrowsError(
      try VadCommand.parse([
        "audio.wav",
        "--max-speech-seconds",
        "0",
      ]).validate()
    )
    XCTAssertThrowsError(
      try VadCommand.parse([
        "audio.wav",
        "--min-silence-ms",
        "inf",
      ]).validate()
    )
  }

  func testUsesSDKSegmentationDefaults() throws {
    let parsed = try VadCommand.parse(["audio.wav"])

    XCTAssertEqual(
      parsed.minSpeechMilliseconds,
      VadSegmentationConfig.default.minSpeechDuration * 1_000.0
    )
    XCTAssertEqual(
      parsed.minSilenceMilliseconds,
      VadSegmentationConfig.default.minSilenceDuration * 1_000.0
    )
    XCTAssertEqual(parsed.maxSpeechSeconds, VadSegmentationConfig.default.maxSpeechDuration)
    XCTAssertEqual(
      parsed.paddingMilliseconds, VadSegmentationConfig.default.speechPadding * 1_000.0)
  }

  func testTextRendering() {
    let output = VadOutput(
      audioFile: "audio.wav",
      durationSeconds: 3.0,
      threshold: 0.85,
      chunkCount: 2,
      segmentCount: 1,
      speechDurationSeconds: 1.5,
      modelProcessingTimeSeconds: 0.25,
      elapsedSeconds: 1.0,
      realTimeFactor: 3.0,
      segments: [
        VadSegmentOutput(
          startTimeSeconds: 0.25,
          endTimeSeconds: 1.75,
          durationSeconds: 1.5
        )
      ]
    )

    XCTAssertEqual(
      VadCommand.renderText(output),
      [
        "VAD complete: 1 speech segments, 1.50s speech",
        "RTFx: 3.00x",
        "[00:00.250 - 00:01.750]",
      ].joined(separator: "\n")
    )
  }
}
