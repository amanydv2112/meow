import AppKit
import Foundation
import MeowCore

// Renders the shared cat artwork into Resources/meow.icns.
// Run with `swift run MeowIconGen` after changing anything in CatIcon.swift.

let arguments = CommandLine.arguments
let outputPath = arguments.count > 1
    ? arguments[1]
    : FileManager.default.currentDirectoryPath + "/Resources/meow.icns"
let outputURL = URL(fileURLWithPath: outputPath)

// Every page macOS expects in an iconset, as (base point size, scale).
let pages: [(Int, Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2)
]

let iconsetURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("meow-\(UUID().uuidString).iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconsetURL) }

for (base, scale) in pages {
    let pixelSize = base * scale
    guard let bitmap = CatIcon.appIconBitmap(pixelSize: pixelSize),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("MeowIconGen failed to render \(pixelSize)px\n".utf8))
        exit(1)
    }

    let suffix = scale == 1 ? "" : "@\(scale)x"
    let name = "icon_\(base)x\(base)\(suffix).png"
    try data.write(to: iconsetURL.appendingPathComponent(name))
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["--convert", "icns", iconsetURL.path, "--output", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("MeowIconGen: iconutil failed\n".utf8))
    exit(iconutil.terminationStatus)
}

print("Wrote \(outputURL.path)")
