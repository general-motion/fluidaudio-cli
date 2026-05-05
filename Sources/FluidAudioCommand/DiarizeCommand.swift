@preconcurrency import AVFoundation
import ArgumentParser
@preconcurrency import FluidAudio
import Foundation

struct DiarizationSegmentOutput: Codable, Equatable, Sendable {
  let speaker: String
  let startTimeSeconds: Float
  let endTimeSeconds: Float
  let durationSeconds: Float
  let qualityScore: Float
}

struct DiarizationOutput: Codable, Equatable, Sendable {
  let audioFile: String
  let mode: String
  let durationSeconds: Double?
  let processingTimeSeconds: Double
  let realTimeFactor: Double?
  let speakerCount: Int
  let segmentCount: Int
  let segments: [DiarizationSegmentOutput]
}

struct DiarizeCommand: AsyncParsableCommand {
  private static let sampleRate = ASRConstants.sampleRate

  static let configuration = CommandConfiguration(
    commandName: "diarize",
    abstract: "Identify who spoke when in an audio file.",
    discussion: """
      Examples:
        fluidaudio diarize meeting.wav
        fluidaudio diarize meeting.wav --json --output result.json
      """
  )

  @Argument(help: "Audio file to diarize.")
  var audioFile: String

  @Option(
    name: .shortAndLong, help: "Write diarization text, or JSON when --json is set, to this path.")
  var output: String?

  @Option(help: "Diarization mode. Values: \(DiarizationModeOption.supportedValuesDescription).")
  var mode: DiarizationModeOption = .chunked

  @Option(help: "Speaker clustering threshold. Defaults to the selected SDK pipeline's default.")
  var threshold: Float?

  @Option(name: .customLong("chunk-seconds"), help: "Chunked mode chunk duration in seconds.")
  var chunkSeconds: Float = 10.0

  @Option(name: .customLong("overlap-seconds"), help: "Chunked mode chunk overlap in seconds.")
  var overlapSeconds: Float = 0.0

  @OptionGroup
  var outputOptions: CommonOutputOptions

  func validate() throws {
    if let threshold {
      guard threshold.isFinite, threshold > 0, threshold <= 1 else {
        throw ValidationError("--threshold must be greater than zero and at most 1.")
      }
    }
    guard chunkSeconds.isFinite, chunkSeconds > 0 else {
      throw ValidationError("--chunk-seconds must be greater than zero.")
    }
    guard overlapSeconds.isFinite, overlapSeconds >= 0, overlapSeconds < chunkSeconds else {
      throw ValidationError(
        "--overlap-seconds must be greater than or equal to zero and less than --chunk-seconds.")
    }
  }

  func run() async throws {
    let inputURL = try FileResolver.existingFile(audioFile)
    // AVFoundation metadata is fast when available; chunked mode can fall back to sample count.
    let duration = durationSeconds(for: inputURL)
    let result: DiarizationOutput

    switch mode {
    case .chunked:
      result = try await runChunked(inputURL: inputURL, duration: duration)
    case .fullFile:
      result = try await runFullFile(inputURL: inputURL, duration: duration)
    }

    try Console.emit(
      result,
      options: outputOptions,
      output: output,
      statusDescriptions: StatusDescriptions(text: "diarization report", json: "diarization JSON"),
      textRenderer: Self.renderText
    )
  }

  private func runChunked(
    inputURL: URL,
    duration metadataDuration: Double?
  ) async throws -> DiarizationOutput {
    Console.status("Loading diarization models...", options: outputOptions)
    // "chunked" is the user-facing name for FluidAudio's streaming diarization pipeline.
    let config = DiarizerConfig(
      clusteringThreshold: effectiveThreshold(for: .chunked),
      debugMode: outputOptions.verbose,
      chunkDuration: chunkSeconds,
      chunkOverlap: overlapSeconds
    )
    let manager = DiarizerManager(config: config)
    let models = try await DiarizerModels.downloadIfNeeded()
    manager.initialize(models: models)

    Console.status(
      "Diarizing \(inputURL.lastPathComponent) with chunked pipeline...", options: outputOptions)
    let started = Date()
    let samples = try AudioConverter(sampleRate: Double(Self.sampleRate)).resampleAudioFile(
      inputURL)
    let duration = metadataDuration ?? Self.durationSeconds(sampleCount: samples.count)
    let diarization = try await manager.performCompleteDiarization(
      samples,
      sampleRate: Self.sampleRate
    )
    let elapsed = Date().timeIntervalSince(started)
    return makeOutput(
      inputURL: inputURL,
      mode: mode.rawValue,
      duration: duration,
      elapsed: elapsed,
      segments: diarization.segments
    )
  }

  private func runFullFile(
    inputURL: URL, duration metadataDuration: Double?
  ) async throws -> DiarizationOutput {
    Console.status("Loading full-file diarization models...", options: outputOptions)
    // "full-file" maps to the SDK's offline diarizer, which processes the file URL directly.
    let config = OfflineDiarizerConfig(
      clusteringThreshold: Double(effectiveThreshold(for: .fullFile)))
    let manager = OfflineDiarizerManager(config: config)
    try await manager.prepareModels()

    Console.status(
      "Diarizing \(inputURL.lastPathComponent) with full-file pipeline...", options: outputOptions)
    let started = Date()
    let diarization = try await manager.process(inputURL)
    let elapsed = Date().timeIntervalSince(started)
    let duration = try metadataDuration ?? fallbackDurationSeconds(for: inputURL)
    return makeOutput(
      inputURL: inputURL,
      mode: mode.rawValue,
      duration: duration,
      elapsed: elapsed,
      segments: diarization.segments
    )
  }

  private func makeOutput(
    inputURL: URL,
    mode: String,
    duration: Double?,
    elapsed: Double,
    segments: [TimedSpeakerSegment]
  ) -> DiarizationOutput {
    let speakers = Set(segments.map(\.speakerId))
    let mappedSegments =
      segments
      .sorted { $0.startTimeSeconds < $1.startTimeSeconds }
      .map {
        DiarizationSegmentOutput(
          speaker: $0.speakerId,
          startTimeSeconds: $0.startTimeSeconds,
          endTimeSeconds: $0.endTimeSeconds,
          durationSeconds: $0.durationSeconds,
          qualityScore: $0.qualityScore
        )
      }
    let rtfx = duration.flatMap { elapsed > 0 ? $0 / elapsed : nil }
    return DiarizationOutput(
      audioFile: inputURL.path,
      mode: mode,
      durationSeconds: duration,
      processingTimeSeconds: elapsed,
      realTimeFactor: rtfx,
      speakerCount: speakers.count,
      segmentCount: mappedSegments.count,
      segments: mappedSegments
    )
  }

  private func effectiveThreshold(for mode: DiarizationModeOption) -> Float {
    if let threshold {
      return threshold
    }

    // The SDK pipelines have different calibrated defaults.
    switch mode {
    case .chunked:
      return DiarizerConfig.default.clusteringThreshold
    case .fullFile:
      return Float(OfflineDiarizerConfig.default.clusteringThreshold)
    }
  }

  private func durationSeconds(for url: URL) -> Double? {
    guard let audioFile = try? AVAudioFile(forReading: url) else { return nil }
    let sampleRate = audioFile.processingFormat.sampleRate
    guard sampleRate > 0 else { return nil }
    return Double(audioFile.length) / sampleRate
  }

  private static func durationSeconds(sampleCount: Int) -> Double {
    Double(sampleCount) / Double(Self.sampleRate)
  }

  private func fallbackDurationSeconds(for url: URL) throws -> Double {
    let samples = try AudioConverter(sampleRate: Double(Self.sampleRate)).resampleAudioFile(url)
    return Self.durationSeconds(sampleCount: samples.count)
  }

  static func renderText(_ result: DiarizationOutput) -> String {
    var lines = [
      "Diarization complete: \(result.speakerCount) speakers, \(result.segmentCount) segments"
    ]
    if let rtfx = result.realTimeFactor {
      lines.append(String(format: "RTFx: %.2fx", rtfx))
    }
    lines.append(
      contentsOf: result.segments.map { segment in
        let start = formattedTimestamp(Double(segment.startTimeSeconds))
        let end = formattedTimestamp(Double(segment.endTimeSeconds))
        return "[\(start) - \(end)] \(segment.speaker)"
      })
    return lines.joined(separator: "\n")
  }
}
