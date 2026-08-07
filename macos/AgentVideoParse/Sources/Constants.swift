import Foundation

enum AVPConstants {
    static let durationLimitSeconds: Double = 30.0
    static let defaultSampleFPS: Double = 2.0
    static let maxFrames: Int = 60

    /// Agent-friendly stills: smaller files for LLM vision / attachments.
    static let maxLongEdge: Int = 1280
    /// JPEG quality 0…1 (ImageIO).
    static let jpegQuality: Double = 0.82
    static let frameExtension = "jpg"

    /// Shared GUI copy — keep in parity with Windows (`AvpConstants`).
    static let disclaimer = """
    DISCLAIMER

    • Your video file must be 30 seconds or shorter. Longer files are rejected; no frames are extracted.
    • AgentVideoParse is a debugging tool for AI/agent UI review only. Do not use it as a general video editor or archival converter.
    • This software is fully open source and runs locally on your computer (macOS or Windows). It does not upload your video.
    """

    static let readyStatus = "Ready. Choose a short video (≤30s)."

    static let dropZoneHint = "Drop a video here (.mov, .mp4, …)\nor click to choose file"

    /// e.g. "Sampling: 2 fps · max 60 stills · ≤30s · JPEG ≤1,280px"
    static var samplingCaption: String {
        let fps = defaultSampleFPS == floor(defaultSampleFPS)
            ? String(format: "%.0f", defaultSampleFPS)
            : String(format: "%g", defaultSampleFPS)
        // Keep thousands separator stable across locales (parity with Windows copy).
        let edge = "1,280"
        return "Sampling: \(fps) fps · max \(maxFrames) stills · ≤\(Int(durationLimitSeconds))s · JPEG ≤\(edge)px"
    }

    static let footer = "Open Source · Debug only · ≤30s · macOS / Windows"

    static let appName = "AgentVideoParse"

    /// Persisted GUI appearance; dark is the product default.
    static let appearanceStorageKey = "appearance"
    static let appearanceDark = "dark"
    static let appearanceLight = "light"
}
