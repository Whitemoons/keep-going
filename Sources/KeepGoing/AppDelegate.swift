import AppKit
import LocalAuthentication
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private var icon: StatusIcon!
  private var demoTimer: Timer?
  private var busy = false
  private var hotKey: HotKey?

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: CanIcon.size.width + 2)
    guard let button = statusItem.button else { return }
    if CommandLine.arguments.contains("--demo") {
      icon = StatusIcon(button: button, twitchInterval: 3)
      startDemo()
      return
    }
    if Installer.runsFromDiskImage, installAndRelaunch() { return }
    icon = StatusIcon(button: button)
    button.target = self
    button.action = #selector(statusItemClicked)
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    refresh()

    let hotKey = HotKey { [weak self] in self?.toggle() }
    if hotKey.register() {
      self.hotKey = hotKey
    } else {
      NSLog("KeepGoing: 단축키를 등록하지 못했습니다 (다른 앱이 사용 중)")
    }
  }

  /// `--demo` previews the animation without touching pmset: off for 3 seconds, then on
  /// for 9 (long enough to show the idle twitch, which demo mode speeds up), repeating.
  private func startDemo(on: Bool = false) {
    icon.set(on ? .on : .off)
    let timer = Timer(timeInterval: on ? 9 : 3, repeats: false) { [weak self] _ in
      self?.startDemo(on: !on)
    }
    RunLoop.main.add(timer, forMode: .common)
    demoTimer = timer
  }

  // MARK: - Status item

  @objc private func statusItemClicked() {
    if NSApp.currentEvent?.type == .rightMouseUp {
      showMenu()
    } else {
      toggle()
    }
  }

  @discardableResult
  private func refresh() -> Bool? {
    let disabled = SleepState.isSleepDisabled()
    let tooltip: String
    switch disabled {
    case true?:
      icon.set(.on)
      tooltip = "Keep Going: 켜짐 — 덮개를 닫아도 잠들지 않습니다"
    case false?:
      icon.set(.off)
      tooltip = "Keep Going: 꺼짐 — 덮개를 닫으면 잠듭니다"
    case nil:
      icon.set(.unknown)
      tooltip = "Keep Going: 상태를 확인할 수 없습니다"
    }
    statusItem.button?.toolTip = tooltip
    statusItem.button?.setAccessibilityLabel(tooltip)
    return disabled
  }

  private func showMenu() {
    let disabled = refresh()
    let menu = NSMenu()
    let state = disabled == nil ? "상태 알 수 없음" : (disabled == true ? "켜짐" : "꺼짐")
    menu.addItem(withTitle: "잠자기 방지: \(state)", action: nil, keyEquivalent: "")
    menu.addItem(.separator())
    let toggleItem = menu.addItem(
      withTitle: disabled == true ? "끄기" : "켜기", action: #selector(toggle),
      keyEquivalent: hotKey == nil ? "" : HotKey.keyEquivalent)
    toggleItem.keyEquivalentModifierMask = HotKey.modifierMask
    let loginItem = menu.addItem(
      withTitle: "로그인 시 자동 실행", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    menu.addItem(withTitle: "제거…", action: #selector(uninstall), keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(
      withTitle: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
      item.target = self
    }
    // Assigning the menu makes the click open it; clear it so left click toggles again.
    statusItem.menu = menu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }

  // MARK: - Actions

  @objc private func toggle() {
    guard !busy, ensureHelperReady() else { return }
    guard let current = refresh() else {
      alert("현재 잠자기 설정을 읽지 못했습니다.")
      return
    }
    let target = !current
    let reason = target ? "잠자기 방지를 켭니다" : "잠자기 방지를 끕니다"
    apply(target, reason: reason) { [weak self] error in
      guard let self else { return }
      if let error {
        self.alert("설정을 바꾸지 못했습니다.", detail: error.localizedDescription)
      } else if self.refresh() != target {
        self.alert("설정이 적용되지 않았습니다.", detail: "pmset 값이 바뀌지 않았습니다.")
      }
    }
  }

  @objc private func toggleLaunchAtLogin() {
    let service = SMAppService.mainApp
    do {
      if service.status == .enabled {
        try service.unregister()
      } else {
        try service.register()
      }
    } catch {
      alert("로그인 시 자동 실행 설정을 바꾸지 못했습니다.", detail: error.localizedDescription)
    }
  }

  @objc private func uninstall() {
    guard !busy else { return }
    let confirm = NSAlert()
    confirm.messageText = "Keep Going을 제거할까요?"
    confirm.informativeText = "잠자기 방지를 끄고 백그라운드 헬퍼 등록을 해제한 뒤 종료합니다. 앱은 직접 휴지통으로 옮겨주세요."
    confirm.addButton(withTitle: "제거")
    confirm.addButton(withTitle: "취소")
    NSApp.activate(ignoringOtherApps: true)
    guard confirm.runModal() == .alertFirstButtonReturn else { return }

    let finish = {
      // Best effort: a leftover login item only points at an app the user is about to delete.
      try? SMAppService.mainApp.unregister()
      HelperClient.service.unregister { error in
        DispatchQueue.main.async {
          if let error {
            self.alert("헬퍼 등록을 해제하지 못했습니다.", detail: error.localizedDescription)
          } else {
            NSApp.terminate(nil)
          }
        }
      }
    }
    // Sleep prevention can only be switched off through the helper, so do it before unregistering.
    guard HelperClient.service.status == .enabled, refresh() != false else {
      finish()
      return
    }
    apply(false, reason: "잠자기 방지를 끄고 Keep Going을 제거합니다") { [weak self] error in
      if let error {
        self?.alert("잠자기 방지를 끄지 못해 제거를 중단했습니다.", detail: error.localizedDescription)
      } else {
        self?.refresh()
        finish()
      }
    }
  }

  /// Touch ID (or password fallback) first, then the privileged change.
  private func apply(_ disabled: Bool, reason: String, completion: @escaping (Error?) -> Void) {
    busy = true
    let context = LAContext()
    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) {
      success, error in
      DispatchQueue.main.async {
        guard success else {
          self.busy = false
          // Cancelling the prompt is a choice, not a failure worth an alert.
          if let error = error as? LAError,
            [.userCancel, .appCancel, .systemCancel].contains(error.code)
          {
            return
          }
          completion(error ?? HelperError(message: "인증에 실패했습니다."))
          return
        }
        HelperClient.setSleepDisabled(disabled) { error in
          self.busy = false
          completion(error)
        }
      }
    }
  }

  // MARK: - Installation

  /// Offers to copy the app into /Applications and start it from there. Returns true when
  /// the installed copy takes over and this instance is about to quit.
  private func installAndRelaunch() -> Bool {
    let destination = Installer.destination
    let replacing = FileManager.default.fileExists(atPath: destination.path)
    let offer = NSAlert()
    offer.messageText = "Keep Going을 응용 프로그램 폴더로 옮길까요?"
    offer.informativeText =
      replacing
      ? "이미 설치된 Keep Going을 이 버전으로 교체한 뒤 바로 실행합니다."
      : "응용 프로그램 폴더에 복사한 뒤 바로 실행합니다."
    offer.addButton(withTitle: replacing ? "교체하고 실행" : "옮기고 실행")
    offer.addButton(withTitle: "나중에")
    NSApp.activate(ignoringOtherApps: true)
    guard offer.runModal() == .alertFirstButtonReturn else { return false }

    // An installed copy that is still running would keep using its old files.
    let others = NSRunningApplication.runningApplications(
      withBundleIdentifier: Bundle.main.bundleIdentifier ?? ""
    ).filter { $0 != .current }
    for other in others { other.terminate() }
    let deadline = Date().addingTimeInterval(3)
    while others.contains(where: { !$0.isTerminated }), Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }

    do {
      try Installer.install(from: Bundle.main.bundleURL, to: destination)
    } catch {
      alert(
        "응용 프로그램 폴더로 옮기지 못했습니다.",
        detail: "Keep Going을 Applications 폴더로 직접 드래그해주세요.\n\(error.localizedDescription)")
      return false
    }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true
    NSWorkspace.shared.openApplication(at: destination, configuration: configuration) {
      _, error in
      DispatchQueue.main.async {
        if let error {
          self.alert(
            "설치했지만 실행하지 못했습니다.",
            detail: "응용 프로그램 폴더에서 Keep Going을 직접 열어주세요.\n\(error.localizedDescription)")
        }
        NSApp.terminate(nil)
      }
    }
    return true
  }

  // MARK: - Helper registration

  private func ensureHelperReady() -> Bool {
    if Installer.runsFromDiskImage {
      alert(
        "먼저 응용 프로그램 폴더로 옮겨주세요.",
        detail: "Keep Going을 Applications 폴더로 드래그한 뒤 거기에서 실행해야 합니다.")
      return false
    }
    let service = HelperClient.service
    if service.status == .notRegistered || service.status == .notFound {
      do {
        try service.register()
      } catch {
        if service.status != .requiresApproval {
          alert("헬퍼를 등록하지 못했습니다.", detail: error.localizedDescription)
          return false
        }
      }
    }
    switch service.status {
    case .enabled:
      return true
    case .requiresApproval:
      alert(
        "백그라운드 실행 허용이 필요합니다.",
        detail: "시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램에서 Keep Going을 켠 뒤 다시 클릭해주세요.")
      SMAppService.openSystemSettingsLoginItems()
      return false
    default:
      alert("헬퍼를 사용할 수 없습니다.", detail: "등록 상태: \(service.status.rawValue)")
      return false
    }
  }

  private func alert(_ message: String, detail: String = "") {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = message
    alert.informativeText = detail
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
  }
}
