import Foundation
import AVFoundation
import AppKit
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// System-framework-only frame extractor (AVFoundation + ImageIO).
/// Usage:
///   ExtractFrames probe <video>
///   ExtractFrames extract <video> <outDir> <t1,t2,...>

func fail(_ message: String, code: Int32 = 1) -> Never {
    fputs("ERROR: \(message)\n", stderr)
    exit(code)
}

func probe(url: URL) {
    let asset = AVURLAsset(url: url)
    let sem = DispatchSemaphore(value: 0)
    var durationSeconds: Double = -1
    var loadError: Error?

    asset.loadValuesAsynchronously(forKeys: ["duration", "tracks"]) {
        var error: NSError?
        let status = asset.statusOfValue(forKey: "duration", error: &error)
        if status == .failed {
            loadError = error
        } else {
            let d = asset.duration
            if d.isValid && !d.isIndefinite {
                durationSeconds = CMTimeGetSeconds(d)
            }
        }
        sem.signal()
    }
    _ = sem.wait(timeout: .now() + 60)

    if let loadError {
        fail("probe failed: \(loadError.localizedDescription)")
    }
    if durationSeconds < 0 || durationSeconds.isNaN {
        fail("invalid duration")
    }
    // Ensure video track
    let tracks = asset.tracks(withMediaType: .video)
    if tracks.isEmpty {
        fail("no video track", code: 3)
    }
    print(String(format: "%.6f", durationSeconds))
}

func writePNG(image: CGImage, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "AgentVideoParse", code: 2, userInfo: [NSLocalizedDescriptionKey: "CGImageDestination failed"])
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
        throw NSError(domain: "AgentVideoParse", code: 2, userInfo: [NSLocalizedDescriptionKey: "PNG finalize failed"])
    }
}

func extract(url: URL, outDir: URL, times: [Double]) {
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    let asset = AVURLAsset(url: url)
    let gen = AVAssetImageGenerator(asset: asset)
    gen.appliesPreferredTrackTransform = true
    gen.requestedTimeToleranceBefore = .zero
    gen.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)

    var index = 1
    for t in times {
        let cm = CMTime(seconds: t, preferredTimescale: 600)
        do {
            var actual = CMTime.zero
            let cg = try gen.copyCGImage(at: cm, actualTime: &actual)
            let name = String(format: "frame-%04d.png", index)
            let dest = outDir.appendingPathComponent(name)
            try writePNG(image: cg, to: dest)
            let actualSec = CMTimeGetSeconds(actual)
            print(String(format: "%d\t%.6f\t%@", index, actualSec.isFinite ? actualSec : t, name))
            index += 1
        } catch {
            fail("extract at t=\(t): \(error.localizedDescription)")
        }
    }
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    fail("usage: ExtractFrames probe <video> | ExtractFrames extract <video> <outDir> <timesCsv>")
}

let cmd = args[1]
if cmd == "probe" {
    guard args.count >= 3 else { fail("probe requires video path") }
    probe(url: URL(fileURLWithPath: args[2]))
} else if cmd == "extract" {
    guard args.count >= 5 else { fail("extract requires video outDir timesCsv") }
    let times = args[4].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    if times.isEmpty { fail("no times") }
    extract(url: URL(fileURLWithPath: args[2]), outDir: URL(fileURLWithPath: args[3]), times: times)
} else {
    fail("unknown command \(cmd)")
}
