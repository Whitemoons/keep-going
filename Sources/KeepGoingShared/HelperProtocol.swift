import Foundation

public enum KeepGoingIDs {
  public static let app = "com.whitemoon.keepgoing"
  /// launchd label and Mach service name of the root helper.
  public static let helper = "com.whitemoon.keepgoing.helper"
  public static let helperPlist = "com.whitemoon.keepgoing.helper.plist"
}

/// The helper's whole surface: it can turn sleep prevention on or off, nothing else.
@objc public protocol HelperProtocol {
  func setSleepDisabled(_ disabled: Bool, reply: @escaping (String?) -> Void)
}
