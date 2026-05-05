import XCTest

@testable import FluidAudioCommand

final class CLIErrorTests: XCTestCase {
  func testDescriptions() {
    XCTAssertEqual(
      CLIError.inputNotFound("audio.wav").description,
      "Input file does not exist: audio.wav"
    )
    XCTAssertEqual(
      CLIError.inputIsDirectory("recordings").description,
      "Expected a file but found a directory: recordings"
    )
    XCTAssertEqual(
      CLIError.invalidOutputPath("out").description,
      "Invalid output path: out"
    )
    XCTAssertEqual(
      CLIError.invalidValue("bad value").description,
      "bad value"
    )
  }

  func testErrorDescriptionsMatchDescriptions() {
    let errors: [CLIError] = [
      .inputNotFound("audio.wav"),
      .inputIsDirectory("recordings"),
      .invalidOutputPath("out"),
      .invalidValue("bad value"),
    ]

    for error in errors {
      XCTAssertEqual(error.errorDescription, error.description)
    }
  }
}
