import Foundation

/// Copies the app into /Applications when it is launched straight from the disk image.
enum Installer {
  static let destination = URL(fileURLWithPath: "/Applications")
    .appendingPathComponent(Bundle.main.bundleURL.lastPathComponent)

  /// True when running from a mounted disk image or a Gatekeeper-translocated copy.
  /// The helper cannot be registered from either place.
  static var runsFromDiskImage: Bool {
    let path = Bundle.main.bundlePath
    return path.hasPrefix("/Volumes/") || path.contains("/AppTranslocation/")
  }

  /// Replaces `destination` with a copy of `source`. An existing copy stays in place until
  /// the new one has been written completely.
  static func install(from source: URL, to destination: URL) throws {
    let files = FileManager.default
    let staging = destination.deletingLastPathComponent()
      .appendingPathComponent(".\(destination.lastPathComponent).installing")
    try? files.removeItem(at: staging)
    defer { try? files.removeItem(at: staging) }
    try files.copyItem(at: source, to: staging)
    if files.fileExists(atPath: destination.path) {
      try files.removeItem(at: destination)
    }
    try files.moveItem(at: staging, to: destination)

    // The copy inherits the download quarantine flag. Left in place, macOS would run the
    // installed app from a translocated path too, and the helper could never register.
    let xattr = Process()
    xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
    xattr.arguments = ["-dr", "com.apple.quarantine", destination.path]
    xattr.standardError = FileHandle.nullDevice
    try xattr.run()
    xattr.waitUntilExit()
  }
}
