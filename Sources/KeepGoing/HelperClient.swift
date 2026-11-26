import Foundation
import KeepGoingShared
import ServiceManagement

struct HelperError: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}

enum HelperClient {
  static let service = SMAppService.daemon(plistName: KeepGoingIDs.helperPlist)

  /// Asks the root helper to flip the flag. `completion` runs on the main queue.
  static func setSleepDisabled(_ disabled: Bool, completion: @escaping (Error?) -> Void) {
    let connection = NSXPCConnection(
      machServiceName: KeepGoingIDs.helper, options: .privileged)
    connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
    connection.resume()

    let finish: (Error?) -> Void = { error in
      connection.invalidate()
      DispatchQueue.main.async { completion(error) }
    }
    let proxy = connection.remoteObjectProxyWithErrorHandler { finish($0) }
    guard let helper = proxy as? HelperProtocol else {
      finish(HelperError(message: "헬퍼에 연결할 수 없습니다."))
      return
    }
    helper.setSleepDisabled(disabled) { message in
      finish(message.map { HelperError(message: $0) })
    }
  }
}
