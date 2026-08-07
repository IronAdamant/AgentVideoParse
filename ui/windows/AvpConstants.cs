namespace AgentVideoParse
{
    /// <summary>Locked v1 product constants (shared with Python/Swift cores).</summary>
    internal static class AvpConstants
    {
        public const double DurationLimitSeconds = 30.0;
        public const double DefaultSampleFps = 2.0;
        public const int MaxFrames = 60;
        public const int MaxLongEdge = 1280;
        public const int JpegQuality = 82; // 1–100 for JpegBitmapEncoder
        public const string FrameExtension = "jpg";

        /// <summary>Shared GUI copy — keep in parity with macOS (<c>AVPConstants</c>).</summary>
        public const string Disclaimer =
            "DISCLAIMER\n\n" +
            "• Your video file must be 30 seconds or shorter. Longer files are rejected; no frames are extracted.\n" +
            "• AgentVideoParse is a debugging tool for AI/agent UI review only. Do not use it as a general video editor or archival converter.\n" +
            "• This software is fully open source and runs locally on your computer (macOS or Windows). It does not upload your video.\n";

        public const string ReadyStatus = "Ready. Choose a short video (≤30s).";

        public const string DropZoneHint =
            "Drop a video here (.mov, .mp4, …)\nor click to choose file";

        public const string SamplingCaption =
            "Sampling: 2 fps · max 60 stills · ≤30s · JPEG ≤1,280px";

        public const string Footer =
            "Open Source · Debug only · ≤30s · macOS / Windows";
    }
}
