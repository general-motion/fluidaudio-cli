import Foundation

func formattedTimestamp(_ seconds: Double) -> String {
  let totalMilliseconds = max(0, Int((seconds * 1_000).rounded()))
  let minutes = totalMilliseconds / 60_000
  let wholeSeconds = (totalMilliseconds % 60_000) / 1_000
  let milliseconds = totalMilliseconds % 1_000
  return String(format: "%02d:%02d.%03d", minutes, wholeSeconds, milliseconds)
}
