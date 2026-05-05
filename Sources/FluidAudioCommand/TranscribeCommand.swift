import ArgumentParser
@preconcurrency import FluidAudio
import Foundation

struct TranscriptTokenOutput: Codable, Equatable, Sendable {
  let token: String
  let tokenId: Int
  let startTimeSeconds: Double
  let endTimeSeconds: Double
  let confidence: Float
}

struct TranscriptOutput: Codable, Equatable, Sendable {
  let audioFile: String
  let text: String
  let confidence: Float
  let durationSeconds: Double
  let processingTimeSeconds: Double
  let elapsedSeconds: Double
  let realTimeFactor: Float
  let tokens: [TranscriptTokenOutput]
}

struct TranscribeCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "transcribe",
    abstract: "Transcribe an audio file with FluidAudio ASR.",
    discussion: """
      Examples:
        fluidaudio transcribe audio.wav
        fluidaudio transcribe audio.wav --json --output transcript.json
      """
  )

  @Argument(help: "Audio file to transcribe.")
  var audioFile: String

  @Option(
    name: .shortAndLong, help: "Write transcript text, or JSON when --json is set, to this path.")
  var output: String?

  @Option(
    help: "Language hint. Values: \(LanguageOption.supportedValuesDescription)."
  )
  var language: LanguageOption?

  @Option(help: "ASR model. Values: \(ASRModelOption.supportedValuesDescription).")
  var model: ASRModelOption = .parakeetV3

  @Option(
    help:
      "Encoder precision for parakeet-v3. Values: \(EncoderPrecisionOption.supportedValuesDescription)."
  )
  var encoderPrecision: EncoderPrecisionOption = .int8

  @OptionGroup
  var outputOptions: CommonOutputOptions

  func run() async throws {
    let inputURL = try FileResolver.existingFile(audioFile)
    let transcript = try await transcribe(inputURL)
    try emit(transcript)
  }

  private func transcribe(_ inputURL: URL) async throws -> TranscriptOutput {
    Console.status("Loading ASR model: \(model.rawValue)", options: outputOptions)
    let models = try await AsrModels.downloadAndLoad(
      version: model.version,
      encoderPrecision: encoderPrecision.precision
    )
    let manager = AsrManager(config: .default, models: models)
    var decoderState = try TdtDecoderState(decoderLayers: models.version.decoderLayers)

    Console.status("Transcribing \(inputURL.lastPathComponent)...", options: outputOptions)
    let started = Date()
    let result = try await manager.transcribe(
      inputURL,
      decoderState: &decoderState,
      language: language?.language
    )
    let elapsed = Date().timeIntervalSince(started)
    let realTimeFactor = elapsed > 0 ? Float(result.duration / elapsed) : 0

    return TranscriptOutput(
      audioFile: inputURL.path,
      text: result.text,
      confidence: result.confidence,
      durationSeconds: result.duration,
      processingTimeSeconds: result.processingTime,
      elapsedSeconds: elapsed,
      // CLI RTFx is duration divided by wall-clock command processing time.
      realTimeFactor: realTimeFactor,
      tokens: result.tokenTimings?.map {
        TranscriptTokenOutput(
          token: $0.token,
          tokenId: $0.tokenId,
          startTimeSeconds: $0.startTime,
          endTimeSeconds: $0.endTime,
          confidence: $0.confidence
        )
      } ?? []
    )
  }

  private func emit(_ transcript: TranscriptOutput) throws {
    try Console.emit(
      transcript,
      options: outputOptions,
      output: output,
      statusDescriptions: StatusDescriptions(text: "transcript", json: "transcript JSON")
    ) { $0.text }
  }
}
