import ArgumentParser
@preconcurrency import FluidAudio
import Foundation

struct VadSegmentOutput: Codable, Equatable, Sendable {
  let startTimeSeconds: Double
  let endTimeSeconds: Double
  let durationSeconds: Double
}

struct VadOutput: Codable, Equatable, Sendable {
  let audioFile: String
  let durationSeconds: Double
  let threshold: Float
  let chunkCount: Int
  let segmentCount: Int
  let speechDurationSeconds: Double
  let modelProcessingTimeSeconds: Double
  let elapsedSeconds: Double
  let realTimeFactor: Double?
  let segments: [VadSegmentOutput]
}

struct VadCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "vad",
    abstract: "Detect speech regions in an audio file.",
    discussion: """
      Examples:
        fluidaudio vad audio.wav
        fluidaudio vad audio.wav --json --output vad.json
      """
  )

  @Argument(help: "Audio file to analyze.")
  var audioFile: String

  @Option(name: .shortAndLong, help: "Write VAD text, or JSON when --json is set, to this path.")
  var output: String?

  @Option(help: "Voice activity probability threshold.")
  var threshold: Float = VadConfig.default.defaultThreshold

  @Option(
    name: .customLong("min-speech-ms"), help: "Minimum speech segment duration in milliseconds.")
  var minSpeechMilliseconds: Double = VadSegmentationConfig.default.minSpeechDuration * 1_000.0

  @Option(name: .customLong("min-silence-ms"), help: "Minimum silence gap in milliseconds.")
  var minSilenceMilliseconds: Double = VadSegmentationConfig.default.minSilenceDuration * 1_000.0

  @Option(
    name: .customLong("max-speech-seconds"), help: "Maximum speech segment duration in seconds.")
  var maxSpeechSeconds: Double = VadSegmentationConfig.default.maxSpeechDuration

  @Option(
    name: .customLong("padding-ms"), help: "Padding added around speech regions in milliseconds.")
  var paddingMilliseconds: Double = VadSegmentationConfig.default.speechPadding * 1_000.0

  @OptionGroup
  var outputOptions: CommonOutputOptions

  private var segmentationConfig: VadSegmentationConfig {
    // The SDK uses seconds; the CLI exposes millisecond controls for short segment tuning.
    VadSegmentationConfig(
      minSpeechDuration: minSpeechMilliseconds / 1_000.0,
      minSilenceDuration: minSilenceMilliseconds / 1_000.0,
      maxSpeechDuration: maxSpeechSeconds,
      speechPadding: paddingMilliseconds / 1_000.0
    )
  }

  func validate() throws {
    guard threshold.isFinite, threshold >= 0, threshold <= 1 else {
      throw ValidationError("--threshold must be between 0 and 1.")
    }
    guard minSpeechMilliseconds.isFinite, minSilenceMilliseconds.isFinite,
      maxSpeechSeconds.isFinite, paddingMilliseconds.isFinite,
      minSpeechMilliseconds >= 0, minSilenceMilliseconds >= 0, maxSpeechSeconds > 0,
      paddingMilliseconds >= 0
    else {
      throw ValidationError(
        "VAD duration options must be non-negative, and --max-speech-seconds must be positive.")
    }
  }

  func run() async throws {
    let inputURL = try FileResolver.audioFile(audioFile)
    let config = VadConfig(defaultThreshold: threshold, debugMode: outputOptions.verbose)

    Console.status("Loading VAD model...", options: outputOptions)
    let manager = try await VadManager(config: config)

    Console.status("Analyzing \(inputURL.lastPathComponent)...", options: outputOptions)
    let started = Date()
    let samples = try AudioConverter().resampleAudioFile(inputURL)
    let duration = Double(samples.count) / Double(VadManager.sampleRate)
    let chunkResults = try await manager.process(samples)
    // VAD first scores audio chunks, then applies segmentation rules to produce intervals.
    let segments = await manager.segmentSpeech(
      from: chunkResults,
      totalSamples: samples.count,
      config: segmentationConfig
    )
    let elapsed = Date().timeIntervalSince(started)
    let modelProcessingSeconds = chunkResults.reduce(0.0) { $0 + $1.processingTime }
    let mappedSegments = segments.map {
      VadSegmentOutput(
        startTimeSeconds: $0.startTime,
        endTimeSeconds: $0.endTime,
        durationSeconds: $0.duration
      )
    }
    let speechDuration = mappedSegments.reduce(0.0) { $0 + $1.durationSeconds }
    let result = VadOutput(
      audioFile: inputURL.path,
      durationSeconds: duration,
      threshold: threshold,
      chunkCount: chunkResults.count,
      segmentCount: mappedSegments.count,
      speechDurationSeconds: speechDuration,
      modelProcessingTimeSeconds: modelProcessingSeconds,
      elapsedSeconds: elapsed,
      // CLI RTFx is duration divided by wall-clock command processing time.
      realTimeFactor: elapsed > 0 ? duration / elapsed : nil,
      segments: mappedSegments
    )

    try emit(result)
  }

  private func emit(_ result: VadOutput) throws {
    try Console.emit(
      result,
      options: outputOptions,
      output: output,
      statusDescriptions: StatusDescriptions(text: "VAD report", json: "VAD JSON"),
      textRenderer: Self.renderText
    )
  }

  static func renderText(_ result: VadOutput) -> String {
    let summary = String(
      format: "VAD complete: %d speech segments, %.2fs speech",
      result.segmentCount,
      result.speechDurationSeconds
    )
    var lines = [summary]
    if let rtfx = result.realTimeFactor {
      lines.append(String(format: "RTFx: %.2fx", rtfx))
    }
    lines.append(
      contentsOf: result.segments.map { segment in
        let start = formattedTimestamp(segment.startTimeSeconds)
        let end = formattedTimestamp(segment.endTimeSeconds)
        return "[\(start) - \(end)]"
      })
    return lines.joined(separator: "\n")
  }
}
