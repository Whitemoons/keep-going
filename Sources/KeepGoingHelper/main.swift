import Foundation
import KeepGoingShared
import Security

/// Team ID this helper was signed with, or nil when unsigned / ad-hoc signed.
func ownTeamID() -> String? {
  var code: SecCode?
  guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
  var staticCode: SecStaticCode?
  guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
    return nil
  }
  var info: CFDictionary?
  let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
  guard SecCodeCopySigningInformation(staticCode, flags, &info) == errSecSuccess,
    let dict = info as? [String: Any]
  else { return nil }
  return dict[kSecCodeInfoTeamIdentifier as String] as? String
}

final class Helper: NSObject, NSXPCListenerDelegate, HelperProtocol {
  func listener(
    _ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection
  ) -> Bool {
    connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
    connection.exportedObject = self
    connection.resume()
    return true
  }

  func setSleepDisabled(_ disabled: Bool, reply: @escaping (String?) -> Void) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = ["-a", "disablesleep", disabled ? "1" : "0"]
    let stderr = Pipe()
    process.standardError = stderr
    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      reply("pmset 실행 실패: \(error.localizedDescription)")
      return
    }
    guard process.terminationStatus == 0 else {
      let data = stderr.fileHandleForReading.readDataToEndOfFile()
      let message = String(data: data, encoding: .utf8) ?? ""
      reply("pmset 종료 코드 \(process.terminationStatus): \(message)")
      return
    }
    reply(nil)
  }
}

// Only the Keep Going app signed by the same team may talk to this root helper.
// Without a team ID there is nothing to pin the caller to, so refuse to serve at all.
guard let teamID = ownTeamID() else {
  NSLog("KeepGoingHelper: no team ID in own signature, refusing to start")
  exit(1)
}

let helper = Helper()
let listener = NSXPCListener(machServiceName: KeepGoingIDs.helper)
listener.setConnectionCodeSigningRequirement(
  "identifier \"\(KeepGoingIDs.app)\" and anchor apple generic"
    + " and certificate leaf[subject.OU] = \"\(teamID)\""
)
listener.delegate = helper
listener.resume()
RunLoop.main.run()
