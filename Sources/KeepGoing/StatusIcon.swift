import AppKit

/// Drives the menu bar image: still can when off, a burst when switching on,
/// then an occasional twitch so "on" stays noticeable without being a constant distraction.
final class StatusIcon {
  enum State { case off, on, unknown }

  private let button: NSStatusBarButton
  private let twitchInterval: TimeInterval
  private static let templateAlpha: CGFloat = 0.87
  private static let handoverDelay: TimeInterval = 0.04

  private let stage = AnimationStage()
  private var state: State?
  private var twitchTimer: Timer?
  private var pending: [DispatchWorkItem] = []

  init(button: NSStatusBarButton, twitchInterval: TimeInterval = 10) {
    self.button = button
    self.twitchInterval = twitchInterval
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

  private func cancelPending() {
    twitchTimer?.invalidate()
    twitchTimer = nil
    for item in pending {
      item.cancel()
    }
    pending = []
    stage.stop()
  }

  private func showResting() {
    cancelPending()
    guard state != .unknown else {
      let image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: nil)
      image?.isTemplate = true
      button.image = image
      return
    }
    button.image = CanIcon.image(state == .on ? .on : .off)
    guard state == .on, !reduceMotion else { return }
    let timer = Timer(timeInterval: twitchInterval, repeats: false) { [weak self] _ in
      self?.play(.twitch)
    }
    // .common keeps the timer firing while a menu is open.
    RunLoop.main.add(timer, forMode: .common)
    twitchTimer = timer
  }

  private func play(_ animation: CanIcon.Animation) {
    cancelPending()
    guard !reduceMotion, let window = button.window else {
      showResting()
      return
    }
    let slot = window.convertToScreen(button.convert(button.bounds, to: nil))
    let dark = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    // The menu bar draws template images slightly translucent; match it so the can
    // does not change shade when the stage takes over.
    stage.play(
      animation, at: NSPoint(x: slot.midX, y: slot.midY), color: dark ? .white : .black,
      opacity: Self.templateAlpha)

    // The slot and the stage are drawn by different processes, so swapping them in the
    // same instant can leave one frame with no icon. Overlap them briefly at both ends.
    schedule(after: Self.handoverDelay) { [weak self] in
      self?.button.image = NSImage(size: CanIcon.size)
    }
    schedule(after: animation.duration) { [weak self] in
      guard let self else { return }
      self.button.image = CanIcon.image(self.state == .on ? .on : .off)
    }
    schedule(after: animation.duration + Self.handoverDelay) { [weak self] in
      self?.showResting()
    }
  }

  private func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
    let item = DispatchWorkItem(block: work)
    pending.append(item)
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
  }
}
