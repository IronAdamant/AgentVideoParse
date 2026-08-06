import Foundation

enum ManifestWriter {
    static func frameFilename(index: Int) -> String {
        String(format: "frame-%04d.%@", index, AVPConstants.frameExtension)
    }

    static func writeManifest(
        outputDirectory: URL,
        sourcePath: String,
        durationSeconds: Double,
        entries: [(index: Int, timestamp: Double, filename: String)],
        sampleFPS: Double = AVPConstants.defaultSampleFPS
    ) throws -> URL {
        let path = outputDirectory.appendingPathComponent("MANIFEST.txt")
        let generated = ISO8601DateFormatter().string(from: Date())
        var lines: [String] = [
            "# AgentVideoParse manifest",
            "# purpose: debugging / agent UI review only",
            "# source: \(sourcePath)",
            String(format: "# duration_seconds: %.6f", durationSeconds),
            "# max_allowed_seconds: \(AVPConstants.durationLimitSeconds)",
            "# sample_fps: \(sampleFPS)",
            "# frame_count: \(entries.count)",
            "# max_frames: \(AVPConstants.maxFrames)",
            "# image_format: \(AVPConstants.frameExtension)",
            "# max_long_edge: \(AVPConstants.maxLongEdge)",
            "# jpeg_quality: \(AVPConstants.jpegQuality)",
            "# platform: macos-app",
            "# generated_at: \(generated)",
            "",
            "index\ttimestamp_seconds\tfilename",
        ]
        for e in entries {
            lines.append(String(format: "%d\t%.3f\t%@", e.index, e.timestamp, e.filename))
        }
        try lines.joined(separator: "\n").appending("\n").write(to: path, atomically: true, encoding: .utf8)
        return path
    }

    static func writeAgentReadme(outputDirectory: URL) throws -> URL {
        let path = outputDirectory.appendingPathComponent("README-FOR-AGENT.txt")
        let text = """
        AgentVideoParse output
        ======================

        These ordered screenshots were extracted from a short debug video \
        (maximum 60 seconds). This folder is for AI/agent UI debugging only.

        Read MANIFEST.txt for index → timestamp → filename mapping.
        Frames are named frame-0001.jpg, frame-0002.jpg, … in time order
        (agent-friendly JPEG, long edge ≤ \(AVPConstants.maxLongEdge)px).
        """
        try text.write(to: path, atomically: true, encoding: .utf8)
        return path
    }
}
