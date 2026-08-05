import Foundation
import AVFoundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import AppKit

struct ExportResult {
    let frameCount: Int
    let durationSeconds: Double
    let outputDirectory: URL
    let manifestURL: URL
}

enum ExportError: LocalizedError {
    case fileNotFound(String)
    case noVideoTrack
    case invalidDuration
    case tooLong(Double)
    case writeFailed(String)
    case cancelled
    case probeFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let p): return "File not found: \(p)"
        case .noVideoTrack: return "This file has no video track that can be read."
        case .invalidDuration: return "Could not determine a valid video duration."
        case .tooLong(let d):
            return String(
                format: "This video is %.2fs long. AgentVideoParse only accepts videos of %.0f seconds or less (debugging sessions). No screenshots were created.",
                d, AVPConstants.durationLimitSeconds
            )
        case .writeFailed(let m): return m
        case .cancelled: return "Export cancelled. Incomplete output was removed."
        case .probeFailed(let m): return "Could not read this video: \(m)"
        }
    }
}

enum VideoExporter {
    static func defaultOutputRoot() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/AgentVideoParse", isDirectory: true)
    }

    static func makeRunDirectory(root: URL, source: URL) throws -> URL {
        let base = source.deletingPathExtension().lastPathComponent
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let name = String(base.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }.prefix(80))
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd-HHmmss"
        let dir = root.appendingPathComponent("\(name)-\(stamp.string(from: Date()))", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func export(
        input: URL,
        outputDirectory: URL? = nil,
        progress: ((Int, Int) -> Void)? = nil,
        shouldCancel: (() -> Bool)? = nil
    ) throws -> ExportResult {
        DebugLog.shared.log("export start input=\(input.path)")
        guard FileManager.default.fileExists(atPath: input.path) else {
            throw ExportError.fileNotFound(input.path)
        }

        let duration = try probeDuration(url: input)
        DebugLog.shared.log(String(format: "probe duration=%.6f", duration))

        let decision = DurationGate.evaluate(durationSeconds: duration)
        DebugLog.shared.log("gate status=\(decision.status.rawValue)")
        switch decision.status {
        case .rejectedInvalid:
            throw ExportError.invalidDuration
        case .rejectedTooLong:
            throw ExportError.tooLong(duration)
        case .accepted:
            break
        }

        let outDir: URL
        let removeOnFailure: Bool
        if let outputDirectory {
            outDir = outputDirectory
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            removeOnFailure = false
        } else {
            let root = defaultOutputRoot()
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            outDir = try makeRunDirectory(root: root, source: input)
            removeOnFailure = true
        }
        DebugLog.shared.log("output=\(outDir.path)")

        let times = FrameSampler.sampleTimes(durationSeconds: duration)
        DebugLog.shared.log("sample_times count=\(times.count)")

        do {
            if shouldCancel?() == true { throw ExportError.cancelled }
            let actual = try extractFrames(
                url: input,
                outDir: outDir,
                times: times,
                progress: progress,
                shouldCancel: shouldCancel
            )
            var entries: [(Int, Double, String)] = []
            for (i, ts) in actual.enumerated() {
                let idx = i + 1
                let name = ManifestWriter.frameFilename(index: idx)
                let f = outDir.appendingPathComponent(name)
                guard FileManager.default.fileExists(atPath: f.path) else {
                    throw ExportError.writeFailed("Expected frame file missing: \(name)")
                }
                entries.append((idx, ts, name))
            }
            let manifest = try ManifestWriter.writeManifest(
                outputDirectory: outDir,
                sourcePath: input.path,
                durationSeconds: duration,
                entries: entries.map { (index: $0.0, timestamp: $0.1, filename: $0.2) }
            )
            _ = try ManifestWriter.writeAgentReadme(outputDirectory: outDir)
            DebugLog.shared.log("export success frames=\(entries.count)")
            return ExportResult(
                frameCount: entries.count,
                durationSeconds: duration,
                outputDirectory: outDir,
                manifestURL: manifest
            )
        } catch {
            DebugLog.shared.log("export failed: \(error.localizedDescription)")
            cleanupPartial(outDir: outDir, removeDirectory: removeOnFailure)
            throw error
        }
    }

    private static func cleanupPartial(outDir: URL, removeDirectory: Bool) {
        if removeDirectory {
            try? FileManager.default.removeItem(at: outDir)
            return
        }
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: outDir.path) else { return }
        for name in files {
            if name.hasPrefix("frame-") && name.hasSuffix(".png")
                || name == "MANIFEST.txt"
                || name == "README-FOR-AGENT.txt" {
                try? FileManager.default.removeItem(at: outDir.appendingPathComponent(name))
            }
        }
    }

    static func probeDuration(url: URL) throws -> Double {
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
            throw ExportError.probeFailed(loadError.localizedDescription)
        }
        if durationSeconds < 0 || durationSeconds.isNaN {
            throw ExportError.invalidDuration
        }
        let tracks = asset.tracks(withMediaType: .video)
        if tracks.isEmpty {
            throw ExportError.noVideoTrack
        }
        return durationSeconds
    }

    private static func extractFrames(
        url: URL,
        outDir: URL,
        times: [Double],
        progress: ((Int, Int) -> Void)?,
        shouldCancel: (() -> Bool)?
    ) throws -> [Double] {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .zero
        gen.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)

        var actualTimes: [Double] = []
        progress?(0, times.count)
        for (i, t) in times.enumerated() {
            if shouldCancel?() == true { throw ExportError.cancelled }
            let cm = CMTime(seconds: t, preferredTimescale: 600)
            var actual = CMTime.zero
            let cg: CGImage
            do {
                cg = try gen.copyCGImage(at: cm, actualTime: &actual)
            } catch {
                throw ExportError.writeFailed("extract at t=\(t): \(error.localizedDescription)")
            }
            let name = ManifestWriter.frameFilename(index: i + 1)
            let dest = outDir.appendingPathComponent(name)
            try writePNG(image: cg, to: dest)
            let actualSec = CMTimeGetSeconds(actual)
            actualTimes.append(actualSec.isFinite ? actualSec : t)
            progress?(i + 1, times.count)
        }
        return actualTimes
    }

    private static func writePNG(image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ExportError.writeFailed("CGImageDestination failed")
        }
        CGImageDestinationAddImage(dest, image, nil)
        if !CGImageDestinationFinalize(dest) {
            throw ExportError.writeFailed("PNG finalize failed")
        }
    }
}
