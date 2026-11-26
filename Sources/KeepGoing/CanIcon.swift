import AppKit
import QuartzCore

/// Chunky energy-drink can drawn in code so it stays crisp at menu bar size.
///
/// Monochrome: off is an outlined can with a solid barred Z, on is the inverse
/// (solid can, mark cut out). The image is a template, so the menu bar tints it. Motion is expressed
/// as layer transforms so Core Animation can run it instead of redrawing every frame.
enum CanIcon {
  static let size = NSSize(width: 16, height: 18)
  private static let bodyHeight: CGFloat = 15.5

  /// What the can shows: asleep (outlined can, solid mark) or awake (solid can, mark cut out).
  enum Look: CaseIterable {
    case off, on
  }

  static func image(_ look: Look) -> NSImage {
    let image = NSImage(size: size, flipped: false) { _ in
      guard let context = NSGraphicsContext.current?.cgContext else { return false }
      context.translateBy(x: size.width / 2, y: (size.height - bodyHeight) / 2)
      NSColor.black.set()
      if look == .off {
        outline().stroke()
      } else {
        silhouette().fill()
        // Punch the mark out of the solid can.
        context.setBlendMode(.clear)
      }
      for stroke in mark() {
        stroke.fill()
      }
      return true
    }
    image.isTemplate = true
    return image
  }

  // The shapes below share one coordinate space: origin at the can's bottom center,
  // 14 wide and `bodyHeight` tall. The app icon is drawn from the same shapes.

  static let bodySize = NSSize(width: 14, height: bodyHeight)

  /// Can silhouette, tapering at top and bottom.
  static func silhouette() -> NSBezierPath {
    let can = NSBezierPath()
    can.move(to: NSPoint(x: -5.8, y: 0))
    can.line(to: NSPoint(x: 5.8, y: 0))
    can.line(to: NSPoint(x: 7, y: 1.6))
    can.line(to: NSPoint(x: 7, y: 13.6))
    can.line(to: NSPoint(x: 5.6, y: bodyHeight))
    can.line(to: NSPoint(x: -5.6, y: bodyHeight))
    can.line(to: NSPoint(x: -7, y: 13.6))
    can.line(to: NSPoint(x: -7, y: 1.6))
    can.close()
    return can
  }

  /// The silhouette as a stroke that stays inside its own bounds.
  static func outline() -> NSBezierPath {
    let lineWidth: CGFloat = 1.4
    let can = silhouette()
    var inset = AffineTransform(translationByX: 0, byY: bodyHeight / 2)
    inset.scale(x: (14 - lineWidth) / 14, y: (bodyHeight - lineWidth) / bodyHeight)
    inset.translate(x: 0, y: -bodyHeight / 2)
    can.transform(using: inset)
    can.lineWidth = lineWidth
    can.lineJoinStyle = .round
    return can
  }

  /// A "Z" with a bar through it (no sleep), as separate strokes to fill one by one.
  /// The weights vary on purpose so it reads as a mark, not as typed text: the top bar
  /// swells to the right, the bottom bar to the left, and the diagonal and crossbar are lighter.
  static func mark() -> [NSBezierPath] {
    let strokes: [[(CGFloat, CGFloat)]] = [
      [(-3.8, 12.05), (3.8, 12.05), (3.8, 10.2), (-3.8, 10.9)],
      [(-3.8, 5.5), (3.8, 4.8), (3.8, 3.45), (-3.8, 3.45)],
      [(1.5, 10.5), (3.8, 10.5), (-1.5, 5.2), (-3.8, 5.2)],
      [(-2.7, 8.35), (2.7, 8.35), (2.7, 7.15), (-2.7, 7.15)],
    ]
    return strokes.map { points in
      let path = NSBezierPath()
      path.move(to: NSPoint(x: points[0].0, y: points[0].1))
      for point in points.dropFirst() {
        path.line(to: NSPoint(x: point.0, y: point.1))
      }
      path.close()
      return path
    }
  }

  enum Animation {
    case turnOn, twitch, turnOff

    var duration: TimeInterval {
      switch self {
      case .turnOn: return 2.0
      case .twitch: return 1.1
      case .turnOff: return 0.9
      }
    }

    var startLook: Look { self == .turnOn ? .off : .on }

    /// Moments at which the icon flips between asleep and awake.
    /// The rapid flips read as a strobe.
    var lookSchedule: [(TimeInterval, Look)] {
      switch self {
      case .turnOn:
        return [
          (0.1, .on), (0.34, .off), (0.42, .on), (0.56, .off), (0.64, .on), (0.8, .off),
          (0.88, .on), (1.06, .off), (1.14, .on),
        ]
      case .twitch: return [(0.12, .off), (0.2, .on), (0.36, .off), (0.44, .on)]
      case .turnOff: return [(0.6, .off)]
      }
    }

    /// Spark bursts: when each fires and in which directions (degrees, 0 is right).
    /// Mostly sideways and downward, because the screen edge is right above the menu bar.
    var sparkBursts: [(TimeInterval, [CGFloat])] {
      switch self {
      case .turnOn:
        return [
          (0.2, [0, 180, 28, 152, -28, 208, -60, -120, -90, 55, 125]),
          (0.45, [0, 180, -60, -120]), (0.65, [28, 152, -28, 208, -90]),
          (0.85, [0, 180, -60, -120]), (1.05, [28, 152, -28, 208]), (1.3, [0, 180, -90]),
          (1.55, [-28, 208]),
        ]
      case .twitch:
        return [(0.12, [0, 180, 28, 152, -28, 208]), (0.4, [0, 180, -60, -120])]
      case .turnOff:
        // Air squeezed out sideways as the can is flattened.
        return [(0.09, [0, 180, -15, 195])]
      }
    }

    func transform(at time: TimeInterval) -> CATransform3D {
      let t = CGFloat(time)
      var squash: CGFloat = 1
      var widen: CGFloat = 0.6
      var pulse: CGFloat = 1
      var lift: CGFloat = 0
      var shift: CGFloat = 0
      var angle: CGFloat = 0
      switch self {
      case .turnOn:
        // Crouch, pop up, then thrash from side to side until the energy settles.
        squash = CanIcon.keyed([(0, 1), (0.1, 0.7), (0.2, 1.15), (0.32, 0.92), (0.42, 1)], at: t)
        lift = CanIcon.keyed([(0.1, 0), (0.2, 1), (0.32, 0)], at: t)
        pulse = 1 + CanIcon.ring(t, from: 0.2, amplitude: 0.15, decay: 2, hertz: 4.3)
        angle = CanIcon.ring(t, from: 0.2, amplitude: 0.7, decay: 2.1, hertz: 5.5)
        shift = CanIcon.ring(t, from: 0.2, amplitude: 5, decay: 2.2, hertz: 3.4)
      case .twitch:
        squash = CanIcon.keyed(
          [(0, 1), (0.08, 0.78), (0.18, 1.14), (0.3, 0.94), (0.4, 1)], at: t)
        lift = CanIcon.keyed([(0.08, 0), (0.18, 1), (0.3, 0)], at: t)
        pulse = 1 + CanIcon.ring(t, from: 0.18, amplitude: 0.1, decay: 4, hertz: 4.3)
        angle = CanIcon.ring(t, from: 0.1, amplitude: 0.5, decay: 3.6, hertz: 5.5)
        shift = CanIcon.ring(t, from: 0.1, amplitude: 3, decay: 3.8, hertz: 3.4)
      case .turnOff:
        // Slammed flat, a small shudder while crushed, then it snaps back upright.
        squash = CanIcon.keyed(
          [
            (0, 1), (0.09, 0.4), (0.3, 0.4), (0.36, 0.5), (0.42, 0.38), (0.48, 0.4), (0.56, 0.4),
            (0.64, 1.14), (0.74, 0.95), (0.84, 1),
          ], at: t)
        widen = 0.35
        shift = CanIcon.ring(t, from: 0.09, amplitude: 0.8, decay: 14, hertz: 16)
      }
      // Keep the base planted while the can squashes and stretches.
      let drop = (1 - squash) * CanIcon.bodyHeight / 2
      let affine = CGAffineTransform(
        scaleX: pulse * (1 + (1 - squash) * widen), y: pulse * squash
      )
      .concatenating(CGAffineTransform(rotationAngle: angle))
      .concatenating(CGAffineTransform(translationX: shift, y: lift - drop))
      return CATransform3DMakeAffineTransform(affine)
    }
  }

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
}
