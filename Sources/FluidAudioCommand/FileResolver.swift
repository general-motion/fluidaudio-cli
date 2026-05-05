@preconcurrency import AVFoundation
import Foundation

/// Resolves user-provided CLI paths into file URLs and validates common input/output cases.
///
/// Relative paths are resolved from the current working directory. The resolver also expands
/// the common shell-style home forms `~` and `~/...`.
enum FileResolver {
  /// Returns an absolute file URL for a user-provided path without checking whether it exists.
  private static func url(for path: String, isDirectory: Bool = false) -> URL {
    let expanded = expandTilde(in: path)
    // Expand "~" before checking absoluteness so "~/file" resolves under the home directory.
    if expanded.hasPrefix("/") {
      return URL(fileURLWithPath: expanded, isDirectory: isDirectory)
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
      .appendingPathComponent(expanded, isDirectory: isDirectory)
  }

  /// Expands only the current user's home shorthand.
  ///
  /// The CLI intentionally leaves `~other-user/...` untouched; supporting that form would require
  /// platform user lookup and is not common for command output paths.
  private static func expandTilde(in path: String) -> String {
    guard path == "~" || path.hasPrefix("~/") else {
      return path
    }

    let homePath = FileManager.default.homeDirectoryForCurrentUser.path
    guard path != "~" else {
      return homePath
    }

    let relativePath = String(path.dropFirst(2))
    return URL(fileURLWithPath: homePath, isDirectory: true)
      .appendingPathComponent(relativePath)
      .path
  }

  /// Resolves and verifies an input path that must already exist and must be a file.
  static func existingFile(_ path: String) throws -> URL {
    let url = url(for: path)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
      throw CLIError.inputNotFound(path)
    }
    guard !isDirectory.boolValue else {
      throw CLIError.inputIsDirectory(path)
    }
    guard FileManager.default.isReadableFile(atPath: url.path) else {
      throw CLIError.inputNotReadable(path)
    }
    return url
  }

  /// Resolves and verifies an input path that must be readable by AVFoundation as audio.
  static func audioFile(_ path: String) throws -> URL {
    let url = try existingFile(path)
    do {
      _ = try AVAudioFile(forReading: url)
    } catch {
      throw CLIError.invalidAudioFile(path)
    }
    return url
  }

  /// Resolves an output path, creates its parent directories, and rejects non-writable targets.
  ///
  /// This does not create the output file itself. Callers still write the final bytes so they can
  /// choose text, JSON, or binary-specific write behavior.
  static func prepareOutputFile(_ path: String) throws -> URL {
    guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw CLIError.invalidOutputPath(path)
    }

    let url = url(for: path)
    let parent = url.deletingLastPathComponent()
    guard !url.lastPathComponent.isEmpty else {
      throw CLIError.invalidOutputPath(path)
    }
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

    guard FileManager.default.isWritableFile(atPath: parent.path) else {
      throw CLIError.invalidOutputPath("\(path): parent directory is not writable")
    }

    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
      guard !isDirectory.boolValue else {
        throw CLIError.invalidOutputPath("\(path): output path is a directory")
      }
      guard FileManager.default.isWritableFile(atPath: url.path) else {
        throw CLIError.invalidOutputPath("\(path): output file is not writable")
      }
    }

    return url
  }
}
