// Renders the app icon and the DMG window background from the same shapes the menu bar
// icon uses. Compiled together with Sources/KeepGoing/CanIcon.swift by `make assets`.
import AppKit

let accent = NSColor(srgbRed: 0xF1 / 255, green: 0xAB / 255, blue: 0x3D / 255, alpha: 1)
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])

func render(pixels: NSSize, points: NSSize, to name: String, _ draw: () -> Void) throws {
  guard
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
  else { fatalError("cannot create bitmap for \(name)") }
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  context.cgContext.scaleBy(x: pixels.width / points.width, y: pixels.height / points.height)
  draw()
  NSGraphicsContext.restoreGraphicsState()
  let url = outputDirectory.appendingPathComponent(name)
  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

/// App icon on a 1024-point canvas: warm white tile, the can outline and its mark in the accent.
func drawAppIcon() {
  guard let context = NSGraphicsContext.current?.cgContext else { return }
  let tile = NSBezierPath(
    roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)

  context.saveGState()
  context.setShadow(
    offset: CGSize(width: 0, height: -10), blur: 24,
    color: NSColor.black.withAlphaComponent(0.28).cgColor)
  NSColor.white.setFill()
  tile.fill()
  context.restoreGState()

  NSGradient(
    starting: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
    ending: NSColor(srgbRed: 0.965, green: 0.94, blue: 0.895, alpha: 1))?
    .draw(in: tile, angle: -90)

  let scale: CGFloat = 34
  context.translateBy(x: 512, y: 512 - CanIcon.bodySize.height * scale / 2)
  context.scaleBy(x: scale, y: scale)
  accent.set()
  CanIcon.outline().stroke()
  for stroke in CanIcon.mark() {
    stroke.fill()
  }
}

/// DMG window background, 600 x 400 points: an arrow from the app to Applications and one line.
func drawDMGBackground() {
  NSColor(srgbRed: 0.968, green: 0.953, blue: 0.925, alpha: 1).setFill()
  NSRect(x: 0, y: 0, width: 600, height: 400).fill()

  // Icons sit at x = 160 and x = 440, 185 points from the top (see Scripts/dmg-settings.py).
  let y: CGFloat = 400 - 185
  let arrow = NSBezierPath()
  arrow.move(to: NSPoint(x: 262, y: y))
  arrow.line(to: NSPoint(x: 338, y: y))
  arrow.move(to: NSPoint(x: 322, y: y + 16))
  arrow.line(to: NSPoint(x: 338, y: y))
  arrow.line(to: NSPoint(x: 322, y: y - 16))
  arrow.lineWidth = 7
  arrow.lineCapStyle = .round
  arrow.lineJoinStyle = .round
  accent.setStroke()
  arrow.stroke()

  let text = NSAttributedString(
    string: "응용 프로그램 폴더로 드래그하세요",
    attributes: [
      .font: NSFont.systemFont(ofSize: 13, weight: .medium),
      .foregroundColor: NSColor(srgbRed: 0.62, green: 0.59, blue: 0.54, alpha: 1),
    ])
  let size = text.size()
  text.draw(at: NSPoint(x: (600 - size.width) / 2, y: 400 - 322 - size.height / 2))
}

let canvas = NSSize(width: 1024, height: 1024)
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
  let pixels = CGFloat(points * scale)
  let suffix = scale == 2 ? "@2x" : ""
  try render(
    pixels: NSSize(width: pixels, height: pixels), points: canvas,
    to: "AppIcon.iconset/icon_\(points)x\(points)\(suffix).png", drawAppIcon)
}
let window = NSSize(width: 600, height: 400)
try render(pixels: window, points: window, to: "dmg-background.png", drawDMGBackground)
try render(
  pixels: NSSize(width: 1200, height: 800), points: window, to: "dmg-background@2x.png",
  drawDMGBackground)
