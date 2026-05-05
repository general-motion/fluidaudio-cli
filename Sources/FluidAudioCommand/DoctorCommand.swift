import ArgumentParser
@preconcurrency import FluidAudio
import Foundation

enum DoctorStatus: String, Codable, Equatable, Sendable {
  case ok
  case warning
  case failed
}

struct DoctorCheckOutput: Codable, Equatable, Sendable {
  let name: String
  let status: DoctorStatus
  let message: String
  let detail: String?
}

struct DoctorOutput: Codable, Equatable, Sendable {
  let version: String
  let status: DoctorStatus
  let checks: [DoctorCheckOutput]
}

struct DoctorCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "doctor",
    abstract: "Diagnose whether this Mac is ready to run local audio commands.",
    discussion: """
      Examples:
        fluidaudio doctor
        fluidaudio doctor --json --output doctor.json
      """
  )

  static let registryCheckTimeoutSeconds: UInt64 = 10

  @Flag(help: "Exit non-zero when any check fails. Warnings still exit zero.")
  var strict = false

  @Option(name: .shortAndLong, help: "Write doctor text, or JSON when --json is set, to this path.")
  var output: String?

  @OptionGroup
  var outputOptions: CommonOutputOptions

  func run() async throws {
    // Keep all checks in the result so JSON and text output explain the final status.
    var checks: [DoctorCheckOutput] = []
    checks.append(platformCheck())
    checks.append(architectureCheck())
    checks.append(contentsOf: modelCacheChecks())
    checks.append(await registryCheck())

    let overall = Self.overallStatus(for: checks)
    let result = DoctorOutput(
      version: FluidAudioCommand.cliVersion,
      status: overall,
      checks: checks
    )

    try Console.emit(
      result,
      options: outputOptions,
      output: output,
      statusDescriptions: StatusDescriptions(text: "doctor report", json: "doctor JSON"),
      textRenderer: Self.renderText
    )

    if strict && overall == .failed {
      throw ExitCode.failure
    }
  }
}
