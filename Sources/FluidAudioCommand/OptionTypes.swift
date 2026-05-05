import ArgumentParser
@preconcurrency import FluidAudio

enum ASRModelOption: String, CaseIterable, ExpressibleByArgument, Sendable {
  case parakeetV3 = "parakeet-v3"
  case parakeetV2 = "parakeet-v2"
  case parakeetTdtCtc110m = "parakeet-tdt-ctc-110m"
  case parakeetJapanese = "parakeet-ja"

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

  var precision: ParakeetEncoderPrecision {
    switch self {
    case .int8:
      return .int8
    case .int4:
      return .int4
    }
  }
}

enum LanguageOption: String, CaseIterable, ExpressibleByArgument, Sendable {
  case english = "en"
  case spanish = "es"
  case french = "fr"
  case german = "de"
  case italian = "it"
  case portuguese = "pt"
  case romanian = "ro"
  case polish = "pl"
  case czech = "cs"
  case slovak = "sk"
  case slovenian = "sl"
  case croatian = "hr"
  case bosnian = "bs"
  case russian = "ru"
  case ukrainian = "uk"
  case belarusian = "be"
  case bulgarian = "bg"
  case serbian = "sr"

  var language: Language {
    switch self {
    case .english:
      return .english
    case .spanish:
      return .spanish
    case .french:
      return .french
    case .german:
      return .german
    case .italian:
      return .italian
    case .portuguese:
      return .portuguese
    case .romanian:
      return .romanian
    case .polish:
      return .polish
    case .czech:
      return .czech
    case .slovak:
      return .slovak
    case .slovenian:
      return .slovenian
    case .croatian:
      return .croatian
    case .bosnian:
      return .bosnian
    case .russian:
      return .russian
    case .ukrainian:
      return .ukrainian
    case .belarusian:
      return .belarusian
    case .bulgarian:
      return .bulgarian
    case .serbian:
      return .serbian
    }
  }
}

enum DiarizationModeOption: String, CaseIterable, ExpressibleByArgument, Sendable {
  case streaming
  case offline
}
