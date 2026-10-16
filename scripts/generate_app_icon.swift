#!/usr/bin/env swift
import CoreGraphics
import Foundation
import ImageIO

// Copy the reviewed original artwork; rebuilding must not restore the old monogram.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("artwork/navoops-dashboard-1024-v1.png")
let output = root.appendingPathComponent("NavoOps/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
      image.width == 1024, image.height == 1024,
      [.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo) else {
    fatalError("The reviewed app icon must be an opaque 1024 by 1024 image")
}
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
try Data(contentsOf: source).write(to: output, options: .atomic)
print("Installed reviewed NavoOps dashboard icon")
