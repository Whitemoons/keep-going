import AppKit
import Carbon.HIToolbox

/// System-wide shortcut. Carbon hot keys need no Accessibility permission.
final class HotKey {
  static let keyCode = UInt32(kVK_Escape)
  static let carbonModifiers = UInt32(controlKey)
  static let keyEquivalent = "\u{1B}"
  static let modifierMask: NSEvent.ModifierFlags = [.control]

  private var hotKeyRef: EventHotKeyRef?
  private var handlerRef: EventHandlerRef?
  private let action: () -> Void

  init(action: @escaping () -> Void) {
    self.action = action
  }

  /// False when the combination is already taken by another app.
  func register() -> Bool {
    var spec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let installed = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, userData in
        guard let userData else { return noErr }
        Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue().action()
        return noErr
      }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    guard installed == noErr else { return false }

    let id = EventHotKeyID(signature: 0x4B47_4F21, id: 1)
    let registered = RegisterEventHotKey(
      Self.keyCode, Self.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
    if registered != noErr, let handlerRef {
      RemoveEventHandler(handlerRef)
    }
    return registered == noErr
  }
}
