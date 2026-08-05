"""Time-based frame sampling with hard max frame count."""

from __future__ import annotations

from typing import List

from .constants import DEFAULT_SAMPLE_FPS, MAX_FRAMES


def sample_times(
    duration_seconds: float,
    fps: float = DEFAULT_SAMPLE_FPS,
    max_frames: int = MAX_FRAMES,
) -> List[float]:
    """
    Return strictly increasing sample timestamps in [0, duration].

    Default: 2 fps (every 0.5s), capped at max_frames (60).
    """
    if duration_seconds is None:
        return []
    duration = float(duration_seconds)
    if duration < 0 or fps <= 0 or max_frames <= 0:
        return []
    if duration == 0.0:
        return [0.0]

    interval = 1.0 / float(fps)
    times: List[float] = []
    t = 0.0
    # Include t=0 and steps while t < duration
    while t < duration or (not times and t == 0.0):
        if t > duration:
            break
        times.append(round(t, 6))
        t += interval
        if len(times) > max_frames * 4:
            break

    # Near-end frame if last sample is more than ~half an interval from end
    if times:
        end = max(0.0, duration - 0.001)
        if end - times[-1] >= interval * 0.45:
            times.append(round(end, 6))

    times = [x for x in times if 0.0 <= x <= duration]

    if not times:
        times = [0.0]

    if len(times) > max_frames:
        times = _uniform_thin(times, max_frames)

    # Enforce strict increase
    cleaned: List[float] = []
    for x in times:
        if not cleaned or x > cleaned[-1]:
            cleaned.append(x)
    return cleaned[:max_frames]


def _uniform_thin(times: List[float], max_frames: int) -> List[float]:
    if max_frames <= 1:
        return [times[0]]
    n = len(times)
    if n <= max_frames:
        return times
    result: List[float] = []
    for i in range(max_frames):
        idx = round(i * (n - 1) / (max_frames - 1))
        result.append(times[idx])
    # unique preserve order
    out: List[float] = []
    for x in result:
        if not out or x > out[-1]:
            out.append(x)
    return out
