import AppKit
import QuartzCore

/// Transparent, click-through window floated over the status item while an animation plays.
///
/// A status item clips everything to its own narrow slot, so the can could barely move and
/// sparks had nowhere to go. The stage is larger than the slot and spills past it.
final class AnimationStage {
  private static let size = NSSize(width: 64, height: 60)

  private let window: NSWindow
  private let root: CALayer

  init() {
    window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.size), styleMask: .borderless,
      backing: .buffered, defer: true)
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.animationBehavior = .none
    window.ignoresMouseEvents = true
    window.isReleasedWhenClosed = false
    window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
    window.collectionBehavior = [
      .canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary,
    ]
    let view = NSView(frame: NSRect(origin: .zero, size: Self.size))
    view.wantsLayer = true
    window.contentView = view
    root = view.layer ?? CALayer()
    // Shown once, empty, and then left on screen between animations: macOS blurs and
    // fades a window as it appears and disappears, which smeared the icon at the start
    // and end of every animation.
    window.orderFrontRegardless()
  }

  /// Plays `animation` centered on `center` (screen coordinates), drawn in `color`.
  /// `opacity` applies to everything drawn, to match how translucent the menu bar draws icons.
  func play(_ animation: CanIcon.Animation, at center: NSPoint, color: NSColor, opacity: CGFloat) {
    stop()
    window.alphaValue = opacity
    window.setFrame(
      NSRect(
        x: (center.x - Self.size.width / 2).rounded(.down),
        y: (center.y - Self.size.height / 2).rounded(.down),
        width: Self.size.width, height: Self.size.height), display: false)
    // Oversampled, so the bitmap stays sharp while it is rotated and scaled up.
    let scale = (window.screen?.backingScaleFactor ?? 2) * 2
    // Windows sit on whole points but the status item can sit on a half point. Place the
    // can relative to where the window really ended up, or it lands a pixel off the icon.
    let middle = CGPoint(x: center.x - window.frame.minX, y: center.y - window.frame.minY)

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    addCan(animation, at: middle, color: color, scale: scale)
    for (start, directions) in animation.sparkBursts {
      for degrees in directions {
        addSpark(from: middle, degrees: degrees, start: start, color: color)
      }
    }
    CATransaction.commit()
  }

  func stop() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    root.sublayers = nil
    CATransaction.commit()
  }

  private func addCan(
    _ animation: CanIcon.Animation, at middle: CGPoint, color: NSColor, scale: CGFloat
  ) {
    let image = { (look: CanIcon.Look) in Self.tinted(look, color: color, scale: scale) as Any }
    let schedule = animation.lookSchedule
    let can = CALayer()
    can.bounds = CGRect(origin: .zero, size: CanIcon.size)
    can.position = middle
    can.contentsScale = scale
    can.contents = image(schedule.last?.1 ?? animation.startLook)

    // Sampled densely and handed over once, so the render server animates it
    // without this process redrawing anything per frame.
    let samples = Int(animation.duration * 60)
    let motion = CAKeyframeAnimation(keyPath: "transform")
    motion.values = (0...samples).map {
      NSValue(
        caTransform3D: animation.transform(at: animation.duration * Double($0) / Double(samples)))
    }
    motion.duration = animation.duration
    motion.calculationMode = .linear
    can.add(motion, forKey: "motion")

    let strobe = CAKeyframeAnimation(keyPath: "contents")
    strobe.values = ([animation.startLook] + schedule.map(\.1)).map(image)
    strobe.keyTimes =
      ([0] + schedule.map { $0.0 / animation.duration } + [1]).map { NSNumber(value: $0) }
    strobe.duration = animation.duration
    strobe.calculationMode = .discrete
    can.add(strobe, forKey: "strobe")
    root.addSublayer(can)
  }

  private func addSpark(from middle: CGPoint, degrees: CGFloat, start: TimeInterval, color: NSColor)
  {
    let radians = degrees * .pi / 180
    let point = { (radius: CGFloat) in
      CGPoint(x: middle.x + cos(radians) * radius, y: middle.y + sin(radians) * radius)
    }
    let spark = CALayer()
    spark.bounds = CGRect(x: 0, y: 0, width: 5, height: 1.6)
    spark.cornerRadius = 0.8
    spark.backgroundColor = color.cgColor
    spark.setAffineTransform(CGAffineTransform(rotationAngle: radians))
    spark.position = point(24)
    // Invisible except while its own animation runs.
    spark.opacity = 0

    let move = CABasicAnimation(keyPath: "position")
    move.fromValue = NSValue(point: point(11))
    move.toValue = NSValue(point: point(24))
    move.timingFunction = CAMediaTimingFunction(name: .easeOut)
    let fade = CAKeyframeAnimation(keyPath: "opacity")
    fade.values = [1, 1, 0]
    fade.keyTimes = [0, 0.5, 1]
    let group = CAAnimationGroup()
    group.animations = [move, fade]
    group.duration = 0.4
    group.beginTime = root.convertTime(CACurrentMediaTime(), from: nil) + start
    spark.add(group, forKey: "spark")
    root.addSublayer(spark)
  }

  /// The template can drawn in a concrete color: layers get no automatic menu bar tint.
  private static func tinted(_ look: CanIcon.Look, color: NSColor, scale: CGFloat) -> CGImage? {
    let size = CanIcon.size
    guard
      let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
        pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    else { return nil }
    bitmap.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let rect = NSRect(origin: .zero, size: size)
    CanIcon.image(look).draw(in: rect)
    color.set()
    rect.fill(using: .sourceAtop)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.cgImage
  }
}
