# AgentVideoParse shared behavioral specification

Source of truth for pure policy. All platform backends and UIs must match.

## Constants

| Name | Value |
|------|-------|
| `DURATION_LIMIT_SECONDS` | `60.0` |
| `DEFAULT_SAMPLE_FPS` | `2.0` |
| `MAX_FRAMES` | `60` |

## DurationGate

- Input: `duration_seconds` (float)
- If non-finite or `< 0` → `rejected_invalid`
- If `duration_seconds > 60.0` → `rejected_too_long` (do not extract any frames)
- Else → `accepted`

## FrameSampler

- Input: accepted duration, `fps=2.0`, `max_frames=60`
- Emit times starting at `0.0`, then every `1/fps` seconds while `t < duration`
- If duration > 0 and no times, include `0.0`
- Cap at `max_frames` by uniform thinning if needed
- All times in `[0, duration]`; strictly increasing

## Stills (agent-friendly)

| Name | Value |
|------|-------|
| Format | JPEG (`.jpg`) |
| Max long edge | `1280` px |
| Quality | ~0.82 (Swift) / 82 (Pillow) |

## Manifest

Plain UTF-8 text; comment headers; tab-separated body:

`index`, `timestamp_seconds`, `filename` with `frame-0001.jpg` style names.

## Export order

1. Probe duration  
2. **DurationGate** (reject → write nothing)  
3. Sample times  
4. Extract frames  
5. Write `MANIFEST.txt` + `README-FOR-AGENT.txt`
