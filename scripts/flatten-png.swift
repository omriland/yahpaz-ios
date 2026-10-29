// Re-encodes screenshots as RGB PNGs with no alpha channel (App Store Connect rejects alpha)
// and checks each one is exactly the expected pixel size.
//
//   swiftc -O scripts/flatten-png.swift -o /tmp/flatten-png
//   /tmp/flatten-png <width> <height> <out-dir> <in.png>...
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 5, let width = Int(args[1]), let height = Int(args[2]) else {
    FileHandle.standardError.write("usage: flatten-png <width> <height> <out-dir> <in.png>...\n".data(using: .utf8)!)
    exit(2)
}
let outDir = URL(fileURLWithPath: args[3])

for path in args[4...] {
    let input = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        fatalError("cannot read \(path)")
    }
    guard image.width == width, image.height == height else {
        fatalError("\(input.lastPathComponent) is \(image.width)x\(image.height), expected \(width)x\(height)")
    }
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        fatalError("cannot create context")
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let output = outDir.appendingPathComponent(input.lastPathComponent)
    guard let flat = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
        fatalError("cannot write \(output.path)")
    }
    CGImageDestinationAddImage(destination, flat, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("cannot write \(output.path)")
    }
    print("\(output.lastPathComponent) \(width)x\(height) RGB")
}
