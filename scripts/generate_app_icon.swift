#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let outputPath = "NavoOps/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let colorSpace = CGColorSpaceCreateDeviceRGB()

func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [red, green, blue, alpha])!
}

func polygon(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    guard let first = points.first else { return path }
    path.move(to: first)
    for point in points.dropFirst() { path.addLine(to: point) }
    path.closeSubpath()
    return path
}

guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("Unable to create AppIcon bitmap context")
}

let bounds = CGRect(x: 0, y: 0, width: size, height: size)
context.setFillColor(rgb(0.02, 0.03, 0.055))
context.fill(bounds)

let gradientColors = [
    rgb(0.02, 0.03, 0.055),
    rgb(0.035, 0.16, 0.29),
    rgb(0.02, 0.05, 0.10)
] as CFArray
if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0, 0.55, 1]) {
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 70, y: 950),
        end: CGPoint(x: 950, y: 70),
        options: []
    )
}

context.setFillColor(rgb(0.08, 0.47, 1.0, 0.16))
context.fillEllipse(in: CGRect(x: 565, y: 560, width: 560, height: 560))

let white = rgb(0.98, 0.98, 0.99)
let blue = rgb(0.12, 0.58, 1.0)

context.setFillColor(white)
context.addPath(CGPath(roundedRect: CGRect(x: 220, y: 178, width: 142, height: 668), cornerWidth: 50, cornerHeight: 50, transform: nil))
context.fillPath()

context.setFillColor(white)
context.addPath(polygon([
    CGPoint(x: 330, y: 510),
    CGPoint(x: 664, y: 828),
    CGPoint(x: 824, y: 828),
    CGPoint(x: 445, y: 455)
]))
context.fillPath()

context.setFillColor(blue)
context.addPath(polygon([
    CGPoint(x: 342, y: 500),
    CGPoint(x: 460, y: 570),
    CGPoint(x: 830, y: 190),
    CGPoint(x: 666, y: 190)
]))
context.fillPath()

context.setFillColor(blue)
context.addPath(CGPath(roundedRect: CGRect(x: 678, y: 745, width: 174, height: 34), cornerWidth: 17, cornerHeight: 17, transform: nil))
context.fillPath()

guard let image = context.makeImage() else {
    fatalError("Unable to create AppIcon image")
}

let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    fatalError("Unable to create PNG destination")
}

CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Unable to encode AppIcon PNG")
}

print("Generated \(outputPath)")
