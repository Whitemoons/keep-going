import Foundation

enum SleepState {
  /// Reads the live `SleepDisabled` flag from `pmset -g`; nil when it can't be determined.
  static func isSleepDisabled() -> Bool? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = ["-g"]
    let stdout = Pipe()
    process.standardOutput = stdout
    process.standardError = Pipe()
    do {
      try process.run()
    } catch {
      return nil
    }
    let data = stdout.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0, let output = String(data: data, encoding: .utf8)
    else { return nil }
    return parse(output)
  }

  static func parse(_ output: String) -> Bool? {
    for line in output.split(separator: "\n") {
      let fields = line.split(whereSeparator: \.isWhitespace)
      if fields.count >= 2, fields[0] == "SleepDisabled" {
        return fields[1] == "1"
      }
    }
    // pmset omits the line entirely when the flag has never been set.
    return false
  }
}
