"""Locked v1 product constants (IMPLEMENTATION-PLAN §3.2 / §10.3)."""

DURATION_LIMIT_SECONDS = 30.0
DEFAULT_SAMPLE_FPS = 2.0
MAX_FRAMES = 60

DISCLAIMER_TEXT = (
    "DISCLAIMER\n"
    "\n"
    "• Your video file must be 30 seconds or shorter. Longer files are rejected; "
    "no frames are extracted.\n"
    "• AgentVideoParse is a debugging tool for AI/agent UI review only. Do not use it "
    "as a general video editor or archival converter.\n"
    "• This software is fully open source and runs locally on your computer "
    "(macOS, Windows, or Linux). It does not upload your video.\n"
)
