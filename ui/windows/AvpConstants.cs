namespace AgentVideoParse
{
    /// <summary>Locked v1 product constants (shared with Python/Swift cores).</summary>
    internal static class AvpConstants
    {
        public const double DurationLimitSeconds = 60.0;
        public const double DefaultSampleFps = 2.0;
        public const int MaxFrames = 60;
        public const int MaxLongEdge = 1280;
        public const int JpegQuality = 82; // 1–100 for JpegBitmapEncoder
        public const string FrameExtension = "jpg";

        public const string Disclaimer =
            "DISCLAIMER\n\n" +
            "• Your video file must be 60 seconds or shorter. Longer files are rejected; no frames are extracted.\n" +
            "• AgentVideoParse is a debugging tool for AI/agent UI review only. Do not use it as a general video editor or archival converter.\n" +
            "• This software is fully open source and runs locally on your computer (macOS, Windows, or Linux). It does not upload your video.\n";
    }
}
