import ArgumentParser
import XCTest

@testable import FluidAudioCommand

final class DoctorCommandTests: XCTestCase {
  func testParsesOutputAndPrettyOptions() throws {
    let parsed = try DoctorCommand.parse([
      "--json",
      "--pretty",
      "--output",
      "doctor.json",
    ])

    XCTAssertEqual(parsed.output, "doctor.json")
    XCTAssertTrue(parsed.outputOptions.json)
    XCTAssertTrue(parsed.outputOptions.pretty)
  }

  func testOverallStatusPrioritizesFailuresThenWarnings() {
    XCTAssertEqual(
      DoctorCommand.overallStatus(for: [
        DoctorCheckOutput(name: "one", status: .ok, message: "ready", detail: nil),
        DoctorCheckOutput(name: "two", status: .failed, message: "failed", detail: nil),
        DoctorCheckOutput(name: "three", status: .warning, message: "warning", detail: nil),
      ]),
      .failed
    )
    XCTAssertEqual(
      DoctorCommand.overallStatus(for: [
        DoctorCheckOutput(name: "one", status: .ok, message: "ready", detail: nil),
        DoctorCheckOutput(name: "two", status: .warning, message: "warning", detail: nil),
      ]),
      .warning
    )
    XCTAssertEqual(
      DoctorCommand.overallStatus(for: [
        DoctorCheckOutput(name: "one", status: .ok, message: "ready", detail: nil)
      ]),
      .ok
    )
  }

  func testTextRendering() {
    let checks = [
      DoctorCheckOutput(
        name: "macOS",
        status: .ok,
        message: "ready",
        detail: "14.0"
      ),
      DoctorCheckOutput(
        name: "model-cache",
        status: .failed,
        message: "not writable",
        detail: "/tmp/cache"
      ),
    ]
    let output = DoctorOutput(version: "test", status: .failed, checks: checks)

    XCTAssertEqual(
      DoctorCommand.renderText(output),
      [
        "FluidAudio CLI test: FAILED",
        "OK  macOS: ready (14.0)",
        "FAILED  model-cache: not writable (/tmp/cache)",
      ].joined(separator: "\n")
    )
  }

  func testRegistryTimeoutCheckUsesDedicatedMessage() throws {
    let url = try XCTUnwrap(URL(string: "https://example.com/models"))

    let check = DoctorCommand.registryTimeoutCheck(url: url, seconds: 10)

    XCTAssertEqual(check.name, "model-registry")
    XCTAssertEqual(check.status, .failed)
    XCTAssertEqual(check.message, "Model registry check timed out after 10s")
    XCTAssertEqual(check.detail, "https://example.com/models")
  }
}
