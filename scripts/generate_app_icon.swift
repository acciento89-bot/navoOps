#!/usr/bin/env swift

import AppKit
import Foundation

let size = 1024
let outputPath = "NavoOps/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

func polygon(_ points: [NSPoint]) -> NSBezierPath {
    let path = NSBezierPath()
    guard let first = points.first else { return path }
    path.move(to: first)
    for point in points.dropFirst() { path.line(to: point) }
    path.close()
    return path
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 3,
    hasAlpha: false,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 24
) else {
    fatalError("Unable to allocate AppIcon bitmap")
}

guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Unable to create AppIcon graphics context")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

let bounds = NSRect(x: 0, y: 0, width: size, height: size)
NSColor(calibratedRed: 0.02, green: 0.03, blue: 0.055, alpha: 1).setFill()
bounds.fill()

if let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.02, green: 0.03, blue: 0.055, alpha: 1),
    NSColor(calibratedRed: 0.035, green: 0.16, blue: 0.29, alpha: 1),
    NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.10, alpha: 1)
]) {
    background.draw(in: bounds, angle: -35)
}

let glow = NSBezierPath(ovalIn: NSRect(x: 585, y: 560, width: 520, height: 520))
NSColor(calibratedRed: 0.08, green: 0.47, blue: 1.0, alpha: 0.17).setFill()
glow.fill()

let white = NSColor(calibratedWhite: 0.98, alpha: 1)
let blue = NSColor(calibratedRed: 0.12, green: 0.58, blue: 1.0, alpha: 1)

let stem = NSBezierPath(roundedRect: NSRect(x: 220, y: 178, width: 142, height: 668), xRadius: 50, yRadius: 50)
white.setFill()
stem.fill()

let upper = polygon([
    NSPoint(x: 330, y: 510),
    NSPoint(x: 664, y: 828),
    NSPoint(x: 824, y: 828),
    NSPoint(x: 445, y: 455)
])
white.setFill()
upper.fill()

let lower = polygon([
    NSPoint(x: 342, y: 500),
    NSPoint(x: 460, y: 570),
    NSPoint(x: 830, y: 190),
    NSPoint(x: 666, y: 190)
])
blue.setFill()
lower.fill()

let accent = NSBezierPath(roundedRect: NSRect(x: 678, y: 745, width: 174, height: 34), xRadius: 17, yRadius: 17)
blue.setFill()
accent.fill()

NSGraphicsContext.restoreGraphicsState()

guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode AppIcon PNG")
}

let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try data.write(to: outputURL, options: .atomic)
print("Generated \(outputPath)")
