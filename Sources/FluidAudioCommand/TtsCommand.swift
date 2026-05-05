import ArgumentParser
@preconcurrency import FluidAudio
import Foundation

struct TtsOutput: Codable, Equatable, Sendable {
  let text: String
  let outputFile: String
  let voice: String
  let speed: Float
  let bytes: Int
  let processingTimeSeconds: Double
}

struct TtsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "tts",
    abstract: "Synthesize speech to a WAV file.",
    discussion: """
      Examples:
        fluidaudio tts "Hello from FluidAudio." --output out.wav
        fluidaudio tts "Hi" --voice af_heart --summary-output tts.json
      """
  )

  @Argument(help: "Text to synthesize.")
  var text: String

  @Option(name: .shortAndLong, help: "Output WAV path.")
  var output: String = "out.wav"

  @Option(name: .shortAndLong, help: "Kokoro voice identifier.")
  var voice: String?

  @Option(name: .customLong("summary-output"), help: "Write synthesis summary JSON to this path.")
  var summaryOutput: String?

  @Option(help: "Voice speed multiplier.")
  var speed: Float = 1.0

  @OptionGroup
  var outputOptions: CommonOutputOptions

  func validate() throws {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw ValidationError("Text cannot be empty.")
    }
    guard speed.isFinite, speed > 0, speed <= 4 else {
      throw ValidationError("--speed must be greater than 0 and at most 4.")
    }
    if let voice {
      let trimmed = voice.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else {
        throw ValidationError("--voice cannot be empty.")
      }
    }
  }

  func run() async throws {
    let outputURL = try FileResolver.prepareOutputFile(output)
    let summaryURL = try summaryOutput.map { try FileResolver.prepareOutputFile($0) }
    // Users choose voices by name; omit --voice to use the SDK's recommended default.
    let selectedVoice = normalizedVoice ?? TtsConstants.recommendedVoice
    Console.status("Loading Kokoro TTS model...", options: outputOptions)
    let manager = KokoroTtsManager(defaultVoice: TtsConstants.recommendedVoice)
    try await manager.initialize(preloadVoices: [selectedVoice])

    Console.status("Synthesizing speech...", options: outputOptions)
    let started = Date()
    let audioData = try await manager.synthesize(
      text: text,
      voice: selectedVoice,
      voiceSpeed: speed,
      // The CLI exposes named voices only; keep SDK speaker selection at its default.
      speakerId: 0
    )
    try replaceOutputFile(at: outputURL, with: audioData)
    let elapsed = Date().timeIntervalSince(started)
    let result = TtsOutput(
      text: text,
      outputFile: outputURL.path,
      voice: selectedVoice,
      speed: speed,
      bytes: fileSizeBytes(at: outputURL),
      processingTimeSeconds: elapsed
    )

    if let summaryURL {
      // For TTS, --output is the audio file. Summary metadata has its own destination.
      let url = try Console.writeJSON(result, to: summaryURL.path, pretty: outputOptions.pretty)
      Console.status("Wrote synthesis summary JSON to \(url.path)", options: outputOptions)
    }

    if outputOptions.json {
      try Console.printJSON(result, pretty: outputOptions.pretty)
    } else {
      Console.status("Wrote audio to \(outputURL.path)", options: outputOptions)
    }
  }

  private var normalizedVoice: String? {
    guard let voice else { return nil }
    let trimmed = voice.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func replaceOutputFile(at outputURL: URL, with audioData: Data) throws {
    // Write to a sibling temporary file first so failed writes do not corrupt existing audio.
    let temporaryURL = outputURL.deletingLastPathComponent()
      .appendingPathComponent(".\(outputURL.lastPathComponent).\(UUID().uuidString).tmp")
    try audioData.write(to: temporaryURL, options: .atomic)

    do {
      if FileManager.default.fileExists(atPath: outputURL.path) {
        _ = try FileManager.default.replaceItemAt(
          outputURL,
          withItemAt: temporaryURL,
          backupItemName: nil,
          options: []
        )
      } else {
        try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
      }
    } catch {
      try? FileManager.default.removeItem(at: temporaryURL)
      throw error
    }
  }
}

private func fileSizeBytes(at url: URL) -> Int {
  let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
  return attributes?[.size] as? Int ?? 0
}
