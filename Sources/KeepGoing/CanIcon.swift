import AppKit

/// Energy-drink can drawn in code so it stays crisp at menu bar size.
///
/// Monochrome throughout: off is an outlined can with a solid bolt, on is the inverse
/// (solid can, bolt cut out). The image is a template, so the menu bar tints it.
enum CanIcon {
  /// One spark flying outward: `progress` runs 0 (just emitted) to 1 (gone).
  struct Spark {
    var degrees: CGFloat
    var progress: CGFloat
  }

  struct Pose {
    var angle: CGFloat = 0
    /// Vertical scale; the width compensates so the can keeps its volume.
    var stretch: CGFloat = 1
    var lift: CGFloat = 0
    var dx: CGFloat = 0
    /// 0 is a pristine can, 1 is crushed to half height.
    var crumple: CGFloat = 0
    var sparks: [Spark] = []
  }

  struct Frame {
    var lit: Bool
    var pose = Pose()
  }

  enum Animation {
    case turnOn, twitch, turnOff

    var duration: TimeInterval {
      switch self {
      case .turnOn: return 2.3
      case .twitch: return 0.8
      case .turnOff: return 1.0
      }
    }

    func frame(at time: TimeInterval) -> Frame {
      let t = CGFloat(min(max(time, 0), duration))
      var pose = Pose()
      switch self {
      case .turnOn:
        // Crouch, two hops, then thrash on the base while sparks fly until the energy settles.
        pose.stretch = CanIcon.keyed(
          [
            (0, 1), (0.1, 0.78), (0.2, 1.14), (0.34, 1.02), (0.42, 0.82), (0.52, 1.12),
            (0.64, 1.02), (0.72, 0.86), (0.84, 1.04), (0.95, 1),
          ], at: t)
        pose.lift = CanIcon.keyed(
          [(0.1, 0), (0.24, 2), (0.38, 0), (0.44, 0), (0.56, 1.4), (0.7, 0)], at: t)
        pose.angle =
          CanIcon.ring(t, from: 0.1, amplitude: 0.22, decay: 4, hertz: 5)
          + CanIcon.ring(t, from: 0.7, amplitude: 0.6, decay: 2.4, hertz: 6.5)
        pose.dx = CanIcon.ring(t, from: 0.7, amplitude: 1.4, decay: 3, hertz: 11)
        let all: [CGFloat] = [-25, 10, 45, 65, 115, 135, 170, 205]
        let schedule: [(CGFloat, [CGFloat])] = [
          (0.1, [-25, 205]), (0.38, all), (0.55, [45, 135]), (0.7, all),
          (0.85, [10, 65, 135, 205]), (1.0, [-25, 45, 115, 170]), (1.15, [10, 65, 135, 205]),
          (1.3, [-25, 45, 115, 170]), (1.5, [10, 170]), (1.75, [45, 135]),
        ]
        pose.sparks = schedule.flatMap { CanIcon.burst(t, at: $0.0, life: 0.45, degrees: $0.1) }
        return Frame(lit: t >= 0.1, pose: pose)
      case .twitch:
        pose.stretch = CanIcon.keyed([(0, 1), (0.08, 0.88), (0.18, 1.08), (0.32, 1)], at: t)
        pose.lift = CanIcon.keyed([(0.08, 0), (0.18, 0.8), (0.3, 0)], at: t)
        pose.angle = CanIcon.ring(t, from: 0.08, amplitude: 0.32, decay: 5, hertz: 6)
        pose.sparks =
          CanIcon.burst(t, at: 0.08, life: 0.45, degrees: [10, 65, 170])
          + CanIcon.burst(t, at: 0.26, life: 0.4, degrees: [45, 115, 205])
        return Frame(lit: true, pose: pose)
      case .turnOff:
        // Slammed flat, a small shudder while crushed, then it snaps back upright
        // and flips to the outline at the moment it springs up.
        pose.crumple = CanIcon.keyed(
          [
            (0, 0), (0.1, 1), (0.3, 1), (0.37, 0.86), (0.44, 1.03), (0.5, 1), (0.62, 1),
            (0.72, -0.18), (0.82, 0.06), (0.92, 0),
          ], at: t)
        pose.dx =
          CanIcon.ring(t, from: 0.1, amplitude: 0.6, decay: 14, hertz: 16)
          + CanIcon.ring(t, from: 0.3, amplitude: 0.5, decay: 12, hertz: 12)
        return Frame(lit: t < 0.64, pose: pose)
      }
    }
  }

  /// Taller and wider than the resting can needs, to leave room for hops and sparks.
  static let size = NSSize(width: 26, height: 22)
  private static let bodyHeight: CGFloat = 12.6
  private static let baseline: CGFloat = 4.7

  static func image(_ frame: Frame) -> NSImage {
    let image = NSImage(size: size, flipped: false) { _ in
      guard let context = NSGraphicsContext.current?.cgContext else { return false }
      NSColor.black.set()
      drawCan(in: context, frame: frame)
      drawSparks(frame.pose.sparks)
      return true
    }
    image.isTemplate = true
    return image
  }

  // MARK: - Motion helpers

  /// Smoothstep interpolation through (time, value) keyframes.
  private static func keyed(_ keys: [(CGFloat, CGFloat)], at time: CGFloat) -> CGFloat {
    guard let first = keys.first, let last = keys.last else { return 0 }
    if time <= first.0 { return first.1 }
    for (from, to) in zip(keys, keys.dropFirst()) where time <= to.0 {
      let progress = (time - from.0) / (to.0 - from.0)
      let eased = progress * progress * (3 - 2 * progress)
      return from.1 + (to.1 - from.1) * eased
    }
    return last.1
  }

  /// Damped oscillation starting at `start`, like something rocking to a stop.
  private static func ring(
    _ time: CGFloat, from start: CGFloat, amplitude: CGFloat, decay: CGFloat, hertz: CGFloat
  ) -> CGFloat {
    let elapsed = time - start
    guard elapsed > 0 else { return 0 }
    return amplitude * exp(-decay * elapsed) * sin(2 * .pi * hertz * elapsed)
  }

  private static func burst(
    _ time: CGFloat, at start: CGFloat, life: CGFloat, degrees: [CGFloat]
  ) -> [Spark] {
    let progress = (time - start) / life
    guard progress >= 0, progress < 1 else { return [] }
    return degrees.map { Spark(degrees: $0, progress: progress) }
  }

  // MARK: - Drawing

  private static func drawCan(in context: CGContext, frame: Frame) {
    let pose = frame.pose
    context.saveGState()
    // Pivot at the bottom center so the can rocks on its base.
    context.translateBy(x: size.width / 2 + pose.dx, y: baseline + pose.lift)
    context.rotate(by: pose.angle)
    context.scaleBy(x: 1 + (1 - pose.stretch) * 0.6, y: pose.stretch)

    let height = bodyHeight * (1 - 0.5 * pose.crumple)
    let can = body(height: height, dent: max(pose.crumple, 0))

    let bolt = NSBezierPath()
    bolt.move(to: NSPoint(x: 0.9, y: 10))
    bolt.line(to: NSPoint(x: -1.9, y: 5.7))
    bolt.line(to: NSPoint(x: -0.2, y: 5.7))
    bolt.line(to: NSPoint(x: -0.9, y: 2.6))
    bolt.line(to: NSPoint(x: 1.9, y: 6.9))
    bolt.line(to: NSPoint(x: 0.2, y: 6.9))
    bolt.close()
    bolt.transform(using: AffineTransform(scaleByX: 1, byY: height / bodyHeight))

    if frame.lit {
      can.fill()
      // Punch the bolt out of the solid can.
      context.setBlendMode(.clear)
      bolt.fill()
    } else {
      // Shrink toward the center so the stroke stays inside the silhouette.
      let lineWidth: CGFloat = 1.2
      var inset = AffineTransform(translationByX: 0, byY: height / 2)
      inset.scale(x: (7 - lineWidth) / 7, y: (height - lineWidth) / height)
      inset.translate(x: 0, y: -height / 2)
      can.transform(using: inset)
      can.lineWidth = lineWidth
      can.lineJoinStyle = .round
      can.stroke()
      // A squashed bolt inside a squashed outline turns into an unreadable knot.
      if pose.crumple < 0.6 {
        bolt.fill()
      }
    }
    context.restoreGState()
  }

  /// Can silhouette, tapering at top and bottom. `dent` folds the sides in like a crushed can.
  private static func body(height: CGFloat, dent: CGFloat) -> NSBezierPath {
    let foot = min(1, height * 0.1)
    let shoulder = height - 1.4 * (1 - 0.4 * dent)
    let path = NSBezierPath()
    path.move(to: NSPoint(x: -2.8, y: 0))
    path.line(to: NSPoint(x: 2.8, y: 0))
    path.line(to: NSPoint(x: 3.5, y: foot))
    path.line(to: NSPoint(x: 3.5 + 0.5 * dent, y: height * 0.3))
    path.line(to: NSPoint(x: 3.5 - 1.7 * dent, y: height * 0.48))
    path.line(to: NSPoint(x: 3.5 + 0.3 * dent, y: height * 0.68))
    path.line(to: NSPoint(x: 3.5, y: shoulder))
    path.line(to: NSPoint(x: 2.7, y: height - 0.5 * dent))
    path.line(to: NSPoint(x: -2.7, y: height))
    path.line(to: NSPoint(x: -3.5, y: shoulder))
    path.line(to: NSPoint(x: -3.5 - 0.3 * dent, y: height * 0.74))
    path.line(to: NSPoint(x: -3.5 + 1.5 * dent, y: height * 0.56))
    path.line(to: NSPoint(x: -3.5 - 0.5 * dent, y: height * 0.36))
    path.line(to: NSPoint(x: -3.5, y: foot))
    path.close()
    return path
  }

  private static func drawSparks(_ sparks: [Spark]) {
    let center = NSPoint(x: size.width / 2, y: baseline + bodyHeight / 2)
    for spark in sparks {
      let radians = spark.degrees * .pi / 180
      let travelled = 1 - (1 - spark.progress) * (1 - spark.progress)
      let inner = 5.2 + 4.5 * travelled
      let outer = inner + 0.4 + 2.4 * (1 - spark.progress)
      let path = NSBezierPath()
      path.lineWidth = 1.2
      path.lineCapStyle = .round
      path.move(
        to: NSPoint(x: center.x + cos(radians) * inner, y: center.y + sin(radians) * inner))
      path.line(
        to: NSPoint(x: center.x + cos(radians) * outer, y: center.y + sin(radians) * outer))
      NSColor.black.withAlphaComponent(1 - spark.progress * spark.progress).setStroke()
      path.stroke()
    }
  }
}
