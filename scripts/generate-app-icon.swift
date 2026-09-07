import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = rootURL.appendingPathComponent("ClipStash/Resources", isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconImage {
    let filename: String
    let pixels: Int
}

let images = [
    IconImage(filename: "icon_16x16.png", pixels: 16),
    IconImage(filename: "icon_16x16@2x.png", pixels: 32),
    IconImage(filename: "icon_32x32.png", pixels: 32),
    IconImage(filename: "icon_32x32@2x.png", pixels: 64),
    IconImage(filename: "icon_128x128.png", pixels: 128),
    IconImage(filename: "icon_128x128@2x.png", pixels: 256),
    IconImage(filename: "icon_256x256.png", pixels: 256),
    IconImage(filename: "icon_256x256@2x.png", pixels: 512),
    IconImage(filename: "icon_512x512.png", pixels: 512),
    IconImage(filename: "icon_512x512@2x.png", pixels: 1024)
]

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.shouldAntialias = true

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let tileInset = size * 0.08
    let tile = canvas.insetBy(dx: tileInset, dy: tileInset)
    let tileRadius = size * 0.22

    let tilePath = NSBezierPath(roundedRect: tile, xRadius: tileRadius, yRadius: tileRadius)
    NSColor(hex: 0xFFFFFF).setFill()
    tilePath.fill()

    let border = NSBezierPath(roundedRect: tile.insetBy(dx: size * 0.012, dy: size * 0.012),
                              xRadius: tileRadius * 0.94,
                              yRadius: tileRadius * 0.94)
    border.lineWidth = max(1, size * 0.01)
    NSColor(hex: 0xE4E7EC).setStroke()
    border.stroke()

    let accent = NSColor(hex: 0x16A34A)
    let clipboard = NSRect(x: size * 0.285, y: size * 0.22, width: size * 0.43, height: size * 0.56)
    let clipboardPath = NSBezierPath(roundedRect: clipboard, xRadius: size * 0.07, yRadius: size * 0.07)
    clipboardPath.lineWidth = max(2, size * 0.035)
    accent.setStroke()
    clipboardPath.stroke()

    let clip = NSRect(x: size * 0.39, y: size * 0.72, width: size * 0.22, height: size * 0.08)
    let clipPath = NSBezierPath(roundedRect: clip, xRadius: size * 0.04, yRadius: size * 0.04)
    NSColor(hex: 0xFFFFFF).setFill()
    clipPath.fill()
    clipPath.lineWidth = max(2, size * 0.035)
    accent.setStroke()
    clipPath.stroke()

    let lineColor = NSColor(hex: 0x98A2B3)
    for (y, width) in [(0.54, 0.24), (0.44, 0.29)] {
        let line = NSRect(x: size * 0.355, y: size * y, width: size * width, height: max(2, size * 0.026))
        let linePath = NSBezierPath(roundedRect: line, xRadius: size * 0.013, yRadius: size * 0.013)
        lineColor.setFill()
        linePath.fill()
    }

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "ClipStashIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    try png.write(to: url)
}

for icon in images {
    let image = drawIcon(size: CGFloat(icon.pixels))
    try writePNG(image, to: iconsetURL.appendingPathComponent(icon.filename))
}

try? FileManager.default.removeItem(at: icnsURL)
