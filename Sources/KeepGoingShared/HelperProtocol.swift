import Foundation

public enum KeepGoingIDs {
  public static let app = "io.github.whitemoons.keepgoing"
  /// launchd label and Mach service name of the root helper.
  public static let helper = "io.github.whitemoons.keepgoing.helper"
  public static let helperPlist = "io.github.whitemoons.keepgoing.helper.plist"
}

/// The helper's whole surface: it can turn sleep prevention on or off, nothing else.
@objc public protocol HelperProtocol {
  func setSleepDisabled(_ disabled: Bool, reply: @escaping (String?) -> Void)
}
