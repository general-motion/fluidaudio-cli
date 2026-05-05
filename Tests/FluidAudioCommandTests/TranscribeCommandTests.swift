import ArgumentParser
@preconcurrency import FluidAudio
import XCTest

@testable import FluidAudioCommand

final class TranscribeCommandTests: XCTestCase {
  func testUsesDefaultModelAndPrecision() throws {
    let parsed = try TranscribeCommand.parse(["sample.wav"])

    XCTAssertEqual(parsed.model, .parakeetV3)
    XCTAssertEqual(parsed.encoderPrecision, .int8)
    XCTAssertNil(parsed.language)
  }

  func testParsesCommonOptions() throws {
    let parsed = try TranscribeCommand.parse([
      "sample.wav",
      "--json",
      "--quiet",
      "--output",
      "result.json",
      "--language",
      "en",
    ])

    XCTAssertEqual(parsed.audioFile, "sample.wav")
    XCTAssertEqual(parsed.output, "result.json")
    XCTAssertEqual(parsed.language?.language, .english)
    XCTAssertTrue(parsed.outputOptions.json)
    XCTAssertTrue(parsed.outputOptions.quiet)
  }

  func testParsesModelLanguageAndEncoderPrecision() throws {
    let parsed = try TranscribeCommand.parse([
      "sample.wav",
      "--model",
      "parakeet-v2",
      "--language",
      "es",
      "--encoder-precision",
      "int4",
    ])

    XCTAssertEqual(parsed.model, .parakeetV2)
    XCTAssertEqual(parsed.language?.language, .spanish)
    XCTAssertEqual(parsed.encoderPrecision, .int4)
  }

  func testLanguageHelpComesFromFluidAudioLanguages() {
    XCTAssertEqual(
      LanguageOption.supportedValuesDescription,
      Language.allCases.map(\.rawValue).joined(separator: ", ")
    )
  }
}
