import XCTest

@testable import FluidAudioCommand

final class TimestampFormattingTests: XCTestCase {
  func testClampsAndRoundsMilliseconds() {
    XCTAssertEqual(formattedTimestamp(-1.0), "00:00.000")
    XCTAssertEqual(formattedTimestamp(65.432), "01:05.432")
    XCTAssertEqual(formattedTimestamp(0.9996), "00:01.000")
  }
}
