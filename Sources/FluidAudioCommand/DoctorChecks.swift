@preconcurrency import FluidAudio
import Foundation

private enum RegistryCheckError: Error {
  case timedOut(seconds: UInt64)
  case missingResponse
}

extension DoctorCommand {
  func platformCheck() -> DoctorCheckOutput {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    let isSupported = version.majorVersion >= 14
    return DoctorCheckOutput(
      name: "macOS",
      status: isSupported ? .ok : .failed,
      message: isSupported ? "macOS version is supported" : "macOS 14 or newer is required",
      detail: ProcessInfo.processInfo.operatingSystemVersionString
    )
  }

  func architectureCheck() -> DoctorCheckOutput {
    if SystemInfo.isAppleSilicon {
      return DoctorCheckOutput(
        name: "architecture",
        status: .ok,
        message: "Running on Apple Silicon",
        detail: SystemInfo.summary()
      )
    }

    return DoctorCheckOutput(
      name: "architecture",
      status: .warning,
      message: "Most FluidAudio models are optimized for Apple Silicon",
      detail: SystemInfo.summary()
    )
  }

  func modelCacheChecks() -> [DoctorCheckOutput] {
    // FluidAudio stores TTS models separately from the ASR/diarization/VAD cache roots.
    let nonTTSRoot = MLModelConfigurationUtils.defaultModelsDirectory()
    let nonTTSDirectories = Self.uniqueURLs(
      ASRModelOption.allCases.map { AsrModels.defaultCacheDirectory(for: $0.version) } + [
        DiarizerModels.defaultModelsDirectory(),
        MLModelConfigurationUtils.defaultModelsDirectory(for: .vad),
      ])
    let nonTTSCheck = modelCacheCheck(
      name: "model-cache",
      rootDescription: "Application Support model",
      root: nonTTSRoot,
      knownModelDirectories: nonTTSDirectories
    )

    do {
      let ttsRoot = try TtsModels.cacheDirectoryURL()
      let ttsModelsRoot = ttsRoot.appendingPathComponent(
        TtsConstants.defaultModelsSubdirectory,
        isDirectory: true
      )
      let ttsCheck = modelCacheCheck(
        name: "tts-model-cache",
        rootDescription: "TTS model",
        root: ttsRoot,
        knownModelDirectories: [
          ttsModelsRoot.appendingPathComponent(Repo.kokoro.folderName, isDirectory: true)
        ]
      )
      return [nonTTSCheck, ttsCheck]
    } catch {
      let ttsCheck = DoctorCheckOutput(
        name: "tts-model-cache",
        status: .failed,
        message: "Could not prepare TTS model cache",
        detail: error.localizedDescription
      )
      return [nonTTSCheck, ttsCheck]
    }
  }

  func registryCheck() async -> DoctorCheckOutput {
    let url: URL
    do {
      url = try ModelRegistry.apiModels(Repo.vad.remotePath, "tree/main")
    } catch {
      return DoctorCheckOutput(
        name: "model-registry",
        status: .failed,
        message: "Could not create model registry URL",
        detail: error.localizedDescription
      )
    }

    do {
      let response = try await registryResponse(from: url)
      guard let http = response as? HTTPURLResponse else {
        return DoctorCheckOutput(
          name: "model-registry",
          status: .failed,
          message: "Registry returned a non-HTTP response",
          detail: url.absoluteString
        )
      }
      let ok = (200..<400).contains(http.statusCode)
      return DoctorCheckOutput(
        name: "model-registry",
        status: ok ? .ok : .failed,
        message: ok
          ? "Model registry is reachable" : "Model registry returned HTTP \(http.statusCode)",
        detail: url.absoluteString
      )
    } catch RegistryCheckError.timedOut(let seconds) {
      return Self.registryTimeoutCheck(url: url, seconds: seconds)
    } catch {
      return DoctorCheckOutput(
        name: "model-registry",
        status: .failed,
        message: "Model registry is not reachable",
        detail: error.localizedDescription
      )
    }
  }

  static func overallStatus(for checks: [DoctorCheckOutput]) -> DoctorStatus {
    if checks.contains(where: { $0.status == .failed }) {
      return .failed
    }
    if checks.contains(where: { $0.status == .warning }) {
      return .warning
    }
    return .ok
  }

  static func registryTimeoutCheck(url: URL, seconds: UInt64) -> DoctorCheckOutput {
    DoctorCheckOutput(
      name: "model-registry",
      status: .failed,
      message: "Model registry check timed out after \(seconds)s",
      detail: url.absoluteString
    )
  }

  static func renderText(_ result: DoctorOutput) -> String {
    let checkLines = result.checks.map { check in
      let detail = check.detail.map { " (\($0))" } ?? ""
      return "\(check.status.rawValue.uppercased())  \(check.name): \(check.message)\(detail)"
    }
    return
      (["FluidAudio CLI \(result.version): \(result.status.rawValue.uppercased())"] + checkLines)
      .joined(separator: "\n")
  }

  private func modelCacheCheck(
    name: String,
    rootDescription: String,
    root: URL,
    knownModelDirectories: [URL]
  ) -> DoctorCheckOutput {
    do {
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

      guard FileManager.default.isWritableFile(atPath: root.path) else {
        return DoctorCheckOutput(
          name: name,
          status: .failed,
          message: "\(rootDescription) cache is not writable",
          detail: root.path
        )
      }

      let existing = knownModelDirectories.filter { url in
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
          && isDirectory.boolValue
      }
      let message =
        existing.isEmpty
        ? "\(rootDescription) cache is ready; no models downloaded yet"
        : "\(rootDescription) cache is ready; \(existing.count) model directories found"
      return DoctorCheckOutput(
        name: name,
        status: .ok,
        message: message,
        detail: root.path
      )
    } catch {
      return DoctorCheckOutput(
        name: name,
        status: .failed,
        message: "Could not prepare \(rootDescription) cache",
        detail: error.localizedDescription
      )
    }
  }

  private func registryResponse(from url: URL) async throws -> URLResponse {
    // The SDK fetch has no timeout knob, so race it against a sleep task.
    try await withThrowingTaskGroup(of: URLResponse.self) { group in
      group.addTask {
        let (_, response) = try await DownloadUtils.fetchWithAuth(from: url)
        return response
      }
      group.addTask {
        try await Task.sleep(for: .seconds(Self.registryCheckTimeoutSeconds))
        throw RegistryCheckError.timedOut(seconds: Self.registryCheckTimeoutSeconds)
      }

      guard let response = try await group.next() else {
        throw RegistryCheckError.missingResponse
      }
      group.cancelAll()
      return response
    }
  }

  private static func uniqueURLs(_ urls: [URL]) -> [URL] {
    var seen = Set<String>()
    return urls.filter { url in
      let path = url.standardizedFileURL.path
      return seen.insert(path).inserted
    }
  }
}
