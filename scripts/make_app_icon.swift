import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: make_app_icon.swift /path/to/AppIcon.icns\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iconsetURL = outputURL
    .deletingLastPathComponent()
    .appendingPathComponent("AppIcon.iconset", isDirectory: true)

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let sizes: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for size in sizes {
    let image = renderIcon(size: size.pixels)
    let url = iconsetURL.appendingPathComponent(size.name)
    try writePNG(image, to: url)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c",
    "icns",
    iconsetURL.path,
    "-o",
    outputURL.path
]

try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fputs("iconutil failed with status \(process.terminationStatus)\n", stderr)
    exit(Int32(process.terminationStatus))
}

try? FileManager.default.removeItem(at: iconsetURL)

func renderIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor(calibratedRed: 0.965, green: 0.968, blue: 0.972, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.08, dy: size * 0.08), xRadius: size * 0.2, yRadius: size * 0.2).fill()

    NSColor(calibratedRed: 0.72, green: 0.76, blue: 0.82, alpha: 0.9).setStroke()
    let border = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.08 + 1, dy: size * 0.08 + 1), xRadius: size * 0.2, yRadius: size * 0.2)
    border.lineWidth = max(1, size * 0.015)
    border.stroke()

    let symbolConfig = NSImage.SymbolConfiguration(pointSize: size * 0.56, weight: .semibold)
    let symbol = NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: "Omnibox Shield")?
        .withSymbolConfiguration(symbolConfig)

    if let symbol {
        let symbolSize = symbol.size
        let symbolRect = NSRect(
            x: (size - symbolSize.width) / 2,
            y: (size - symbolSize.height) / 2,
            width: symbolSize.width,
            height: symbolSize.height
        )
        NSColor(calibratedRed: 0.13, green: 0.16, blue: 0.20, alpha: 1).set()
        symbol.draw(in: symbolRect, from: .zero, operation: .sourceAtop, fraction: 1)
    }

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconWriter", code: 1)
    }

    try pngData.write(to: url)
}
