#!/usr/bin/env swift

import AppKit

// Generate DevCleaner app icon - gradient circle with paintbrush
func generateIcon(size: Int) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let s = CGFloat(size)

    // Background: rounded rect with gradient
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: s * 0.04, dy: s * 0.04), xRadius: s * 0.22, yRadius: s * 0.22)

    // Gradient: blue to purple
    let gradient = NSGradient(colors: [
        NSColor(red: 0.25, green: 0.47, blue: 0.95, alpha: 1.0),
        NSColor(red: 0.58, green: 0.33, blue: 0.87, alpha: 1.0),
    ])!
    gradient.draw(in: path, angle: -45)

    // Subtle inner shadow
    let shadowPath = NSBezierPath(roundedRect: rect.insetBy(dx: s * 0.04, dy: s * 0.04), xRadius: s * 0.22, yRadius: s * 0.22)
    NSColor.white.withAlphaComponent(0.15).setStroke()
    shadowPath.lineWidth = s * 0.02
    shadowPath.stroke()

    // Paintbrush icon (SF Symbol rendered)
    let config = NSImage.SymbolConfiguration(pointSize: s * 0.42, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "paintbrush.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let symbolSize = symbol.size
        let x = (s - symbolSize.width) / 2
        let y = (s - symbolSize.height) / 2
        NSColor.white.set()

        // Draw symbol tinted white
        let tinted = NSImage(size: symbolSize)
        tinted.lockFocus()
        symbol.draw(in: NSRect(origin: .zero, size: symbolSize))
        NSColor.white.set()
        NSRect(origin: .zero, size: symbolSize).fill(using: .sourceAtop)
        tinted.unlockFocus()

        tinted.draw(in: NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height))
    }

    img.unlockFocus()
    return img
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("Created: \(path) (\(image.size.width)x\(image.size.height))")
    } catch {
        print("Error writing \(path): \(error)")
    }
}

// Generate all required sizes
let iconsetPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/Assets.xcassets/AppIcon.appiconset"

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for entry in sizes {
    let img = generateIcon(size: entry.px)
    savePNG(img, to: "\(iconsetPath)/\(entry.name).png")
}

// Update Contents.json
let contents = """
{
  "images": [
    { "filename": "icon_16x16.png", "idiom": "mac", "scale": "1x", "size": "16x16" },
    { "filename": "icon_16x16@2x.png", "idiom": "mac", "scale": "2x", "size": "16x16" },
    { "filename": "icon_32x32.png", "idiom": "mac", "scale": "1x", "size": "32x32" },
    { "filename": "icon_32x32@2x.png", "idiom": "mac", "scale": "2x", "size": "32x32" },
    { "filename": "icon_128x128.png", "idiom": "mac", "scale": "1x", "size": "128x128" },
    { "filename": "icon_128x128@2x.png", "idiom": "mac", "scale": "2x", "size": "128x128" },
    { "filename": "icon_256x256.png", "idiom": "mac", "scale": "1x", "size": "256x256" },
    { "filename": "icon_256x256@2x.png", "idiom": "mac", "scale": "2x", "size": "256x256" },
    { "filename": "icon_512x512.png", "idiom": "mac", "scale": "1x", "size": "512x512" },
    { "filename": "icon_512x512@2x.png", "idiom": "mac", "scale": "2x", "size": "512x512" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
"""

try! contents.write(toFile: "\(iconsetPath)/Contents.json", atomically: true, encoding: .utf8)
print("Updated Contents.json")
