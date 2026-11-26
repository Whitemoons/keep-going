import AppKit

/// Drives the menu bar image: still can when off, a burst when switching on,
/// then an occasional twitch so "on" stays noticeable without being a constant distraction.
final class StatusIcon {
  enum State { case off, on, unknown }

  private static let twitchInterval: TimeInterval = 10

  private let button: NSStatusBarButton
  private var state: State?
  private var frameTimer: Timer?
  private var twitchTimer: Timer?

  init(button: NSStatusBarButton) {
    self.button = button
  }

  func set(_ newState: State) {
    guard newState != state else { return }
    let oldState = state
    state = newState
    switch (oldState, newState) {
    case (.off?, .on): play(.turnOn)
    case (.on?, .off): play(.turnOff)
    default: showResting()
    }
  }

  private var reduceMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  }

  private func stopTimers() {
    frameTimer?.invalidate()
    frameTimer = nil
    twitchTimer?.invalidate()
    twitchTimer = nil
  }

  private func showResting() {
    stopTimers()
    guard state != .unknown else {
      let image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: nil)
      image?.isTemplate = true
      button.image = image
      return
    }
    button.image = CanIcon.image(CanIcon.Frame(lit: state == .on))
    guard state == .on, !reduceMotion else { return }
    let timer = Timer(timeInterval: Self.twitchInterval, repeats: false) { [weak self] _ in
      self?.play(.twitch)
    }
    RunLoop.main.add(timer, forMode: .common)
    twitchTimer = timer
  }

  private func play(_ animation: CanIcon.Animation) {
    stopTimers()
    guard !reduceMotion else {
      showResting()
      return
    }
    let start = Date()
    let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
      guard let self else { return }
      let elapsed = Date().timeIntervalSince(start)
      if elapsed >= animation.duration {
        self.showResting()
      } else {
        self.button.image = CanIcon.image(animation.frame(at: elapsed))
      }
    }
    // .common keeps the animation running while a menu is open.
    RunLoop.main.add(timer, forMode: .common)
    frameTimer = timer
  }
}
