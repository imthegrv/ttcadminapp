// Renders the TripClub Operations app icon (purple→pink gradient + white
// paper-plane) as 1024px masters. Run: swift scripts/gen_icon.swift
import AppKit

let brandPurple = NSColor(srgbRed: 0x6D / 255.0, green: 0x28 / 255.0, blue: 0xD9 / 255.0, alpha: 1)
let brandPink = NSColor(srgbRed: 0xEC / 255.0, green: 0x48 / 255.0, blue: 0x99 / 255.0, alpha: 1)

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
  let result = NSImage(size: image.size)
  result.lockFocus()
  image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
  color.set()
  NSGraphicsContext.current?.compositingOperation = .sourceAtop
  NSBezierPath(rect: NSRect(origin: .zero, size: image.size)).fill()
  result.unlockFocus()
  return result
}

func render(size: CGFloat, fullBleed: Bool, out: String) {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let ctx = NSGraphicsContext.current!.cgContext
  ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

  // Tile geometry: full-bleed for iOS/Android, inset rounded for macOS.
  let rect: NSRect
  if fullBleed {
    rect = NSRect(x: 0, y: 0, width: size, height: size)
  } else {
    let inset = size * 0.095
    rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
  }
  let radius = rect.width * (fullBleed ? 0.225 : 0.235)

  NSGraphicsContext.current!.saveGraphicsState()
  let clip = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
  clip.addClip()
  NSGradient(starting: brandPurple, ending: brandPink)!.draw(in: rect, angle: 315)

  // Soft top-left sheen for depth.
  if let sheen = NSGradient(
    colors: [NSColor(white: 1, alpha: 0.18), NSColor(white: 1, alpha: 0.0)]) {
    sheen.draw(from: NSPoint(x: rect.minX, y: rect.maxY),
               to: NSPoint(x: rect.midX, y: rect.midY),
               options: [])
  }
  NSGraphicsContext.current!.restoreGraphicsState()

  // White paper-plane glyph, centered.
  let pt = rect.width * 0.46
  let cfg = NSImage.SymbolConfiguration(pointSize: pt, weight: .semibold)
  if let base = NSImage(systemSymbolName: "paperplane.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    let white = tinted(base, .white)
    let s = white.size
    // Nudge up slightly — paper-plane reads better optically centered high.
    let drawRect = NSRect(x: rect.midX - s.width / 2,
                          y: rect.midY - s.height / 2 + rect.height * 0.02,
                          width: s.width, height: s.height)
    white.draw(in: drawRect)
  }

  NSGraphicsContext.restoreGraphicsState()
  let data = rep.representation(using: .png, properties: [:])!
  try! data.write(to: URL(fileURLWithPath: out))
  print("wrote \(out)")
}

// Android adaptive-icon foreground: white plane only, on transparent, sized to
// sit inside the 66% safe zone (system masks/scales the rest).
func renderForeground(size: CGFloat, out: String) {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  NSGraphicsContext.current!.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))
  let pt = size * 0.30
  let cfg = NSImage.SymbolConfiguration(pointSize: pt, weight: .semibold)
  if let base = NSImage(systemSymbolName: "paperplane.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    let white = tinted(base, .white)
    let s = white.size
    white.draw(in: NSRect(x: size / 2 - s.width / 2,
                          y: size / 2 - s.height / 2 + size * 0.012,
                          width: s.width, height: s.height))
  }
  NSGraphicsContext.restoreGraphicsState()
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
  print("wrote \(out)")
}

let dir = "assets/icon"
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
render(size: 1024, fullBleed: true, out: "\(dir)/app_icon.png")
render(size: 1024, fullBleed: false, out: "\(dir)/app_icon_macos.png")
renderForeground(size: 1024, out: "\(dir)/app_icon_fg.png")
