import ArgumentParser

/// The root command for the FluidAudio CLI.
@available(macOS 14.0, *)
public struct FluidAudioCommand: AsyncParsableCommand {
  /// The semantic version displayed by the command-line interface.
  public static let cliVersion = "0.1.0"

  /// The command tree and metadata used by Swift Argument Parser.
  public static let configuration = CommandConfiguration(
    commandName: "fluidaudio",
    abstract: "Transcribe audio, identify speakers, detect speech, and synthesize voice locally.",
    version: cliVersion,
    subcommands: [
      TranscribeCommand.self,
      DiarizeCommand.self,
      VadCommand.self,
      DoctorCommand.self,
    ],
    helpNames: [.short, .long]
  )

  /// Creates the root FluidAudio command.
  public init() {}
}
