import ArgumentParser
@preconcurrency import FluidAudio

enum ASRModelOption: String, CaseIterable, ExpressibleByArgument, Sendable {
  case parakeetV3 = "parakeet-v3"
  case parakeetV2 = "parakeet-v2"
  case parakeetTdtCtc110m = "parakeet-tdt-ctc-110m"
  case parakeetJapanese = "parakeet-ja"

  static var supportedValuesDescription: String {
    allCases.map(\.rawValue).joined(separator: ", ")
  }

  var version: AsrModelVersion {
    switch self {
    case .parakeetV3:
      return .v3
    case .parakeetV2:
      return .v2
    case .parakeetTdtCtc110m:
      return .tdtCtc110m
    case .parakeetJapanese:
      return .tdtJa
    }
  }
}

enum EncoderPrecisionOption: String, CaseIterable, ExpressibleByArgument, Sendable {
  case int8
  case int4

  static var supportedValuesDescription: String {
    allCases.map(\.rawValue).joined(separator: ", ")
  }

  var precision: ParakeetEncoderPrecision {
    switch self {
    case .int8:
      return .int8
    case .int4:
      return .int4
    }
  }
}

struct LanguageOption: Equatable, ExpressibleByArgument, Sendable {
  let language: Language

  init?(argument: String) {
    guard let language = Language(rawValue: argument) else {
      return nil
    }
    self.language = language
  }

  static var supportedValuesDescription: String {
    Language.allCases.map(\.rawValue).joined(separator: ", ")
  }
}

enum DiarizationModeOption: String, CaseIterable, ExpressibleByArgument, Sendable {
  case chunked
  case fullFile = "full-file"

  static var supportedValuesDescription: String {
    allCases.map(\.rawValue).joined(separator: ", ")
  }
}
