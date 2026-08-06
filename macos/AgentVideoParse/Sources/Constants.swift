import Foundation

enum AVPConstants {
    static let durationLimitSeconds: Double = 60.0
    static let defaultSampleFPS: Double = 2.0
    static let maxFrames: Int = 60

    /// Agent-friendly stills: smaller files for LLM vision / attachments.
    static let maxLongEdge: Int = 1280
    /// JPEG quality 0…1 (ImageIO).
    static let jpegQuality: Double = 0.82
    static let frameExtension = "jpg"

    static let disclaimer = """
    DISCLAIMER

    • Your video file must be 60 seconds or shorter. Longer files are rejected; no frames are extracted.
    • AgentVideoParse is a debugging tool for AI/agent UI review only. Do not use it as a general video editor or archival converter.
    • This software is fully open source and runs locally on your computer. It does not upload your video.
    """

    static let appName = "AgentVideoParse"
}
