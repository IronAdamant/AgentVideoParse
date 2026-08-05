import Foundation

enum AVPConstants {
    static let durationLimitSeconds: Double = 30.0
    static let defaultSampleFPS: Double = 2.0
    static let maxFrames: Int = 60

    static let disclaimer = """
    DISCLAIMER

    • Your video file must be 30 seconds or shorter. Longer files are rejected; no frames are extracted.
    • AgentVideoParse is a debugging tool for AI/agent UI review only. Do not use it as a general video editor or archival converter.
    • This software is fully open source and runs locally on your computer. It does not upload your video.
    """

    static let appName = "AgentVideoParse"
}
