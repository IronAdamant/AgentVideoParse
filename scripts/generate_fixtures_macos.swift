import Foundation
import AVFoundation
import CoreVideo
import CoreMedia
import AppKit

/// Generate solid-color synthetic videos using AVFoundation only (no FFmpeg).
/// Usage: generate_fixtures_macos <outDir> <seconds>

func makeVideo(path: URL, seconds: Double, size: CGSize = CGSize(width: 320, height: 240)) throws {
    if FileManager.default.fileExists(atPath: path.path) {
        try FileManager.default.removeItem(at: path)
    }
    let writer = try AVAssetWriter(outputURL: path, fileType: .mp4)
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: Int(size.width),
        AVVideoHeightKey: Int(size.height),
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false
    let attrs: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferWidthKey as String: Int(size.width),
        kCVPixelBufferHeightKey as String: Int(size.height),
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    let fps = 10
    let frameCount = max(1, Int(seconds * Double(fps)))
    let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))

    for i in 0..<frameCount {
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
        guard let buffer = pb else { throw NSError(domain: "fix", code: 1) }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) {
            let t = CGFloat(i) / CGFloat(max(frameCount - 1, 1))
            ctx.setFillColor(red: t, green: 0.2, blue: 1.0 - t, alpha: 1)
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        let time = CMTimeMultiply(frameDuration, multiplier: Int32(i))
        adaptor.append(buffer, withPresentationTime: time)
    }
    input.markAsFinished()
    let sem = DispatchSemaphore(value: 0)
    writer.finishWriting { sem.signal() }
    sem.wait()
    if writer.status != .completed {
        throw writer.error ?? NSError(domain: "fix", code: 2)
    }
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    fputs("usage: generate_fixtures_macos <outDir> <seconds>\n", stderr)
    exit(1)
}
let outDir = URL(fileURLWithPath: args[1], isDirectory: true)
let seconds = Double(args[2]) ?? 1
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let name = String(format: "clip-%.0fs.mp4", seconds)
let url = outDir.appendingPathComponent(name)
do {
    try makeVideo(path: url, seconds: seconds)
    print(url.path)
} catch {
    fputs("ERROR: \(error)\n", stderr)
    exit(1)
}
