# AgentVideoParse — project basis

**Name:** AgentVideoParse  
**Location:** `/Users/aron/Documents/coding_projects/agentvideoparse`  
**Status:** Conversation basis only (not an implementation plan, not a language decision)  
**Origin:** Discussion while building Interpres (local Live Captions companion). Agents often cannot fully watch video; they can read still images well. This project exists to bridge that gap for short debug recordings.

Further work on AgentVideoParse will happen in a **separate interface/session**. This file is the shared starting point for that conversation.

---

## Problem

Coding agents (and similar assistants) are weak at “watching” video end-to-end. They may:

- See that a video file exists (size, type, duration)
- Sometimes get a single thumbnail
- Struggle without tools to extract many frames
- Not hear the audio track

They *are* strong at reviewing **still images** (screenshots, phone photos of a screen, exported frames).

For debugging desktop apps (e.g. Interpres showing Live Captions next to YouTube), users often have short **phone videos or screen recordings**. Agents need a way to turn those into a **bounded set of stills** they can open and reason about.

---

## Product idea (one sentence)

**AgentVideoParse** is a local, open-source helper that takes a **short** video (hard cap **30 seconds**), autonomously turns it into **ordered screenshots/frames**, and stops if the clip is longer—so agents can debug UI and timing without drowning in images.

---

## Hard rules (non-negotiable from conversation)

1. **Maximum video length: 30 seconds.**  
   - Anything longer is **rejected** (not partially processed by default).  
   - Reason: longer clips create too many images and overwhelm debug sessions.

2. **Purpose: debugging / agent review**, not general video editing or archival.

3. **Output: still images** (screenshots of frames), not a re-encoded long video as the main deliverable.

4. **Local and open source** — runs on the user’s machine; no requirement to upload video to a cloud service for the core job.

5. **Keep scope general for now** — no committed programming language, stack, or packaging choice in this document.

---

## Intended use case

Example flow (from Interpres debugging):

1. User records a short phone video or screen capture of the Mac running the app + YouTube (≤ 30s).
2. User runs AgentVideoParse on that file.
3. Tool writes a folder of frames (and preferably a simple index: time → image file).
4. User points an agent at that folder (or attaches frames).
5. Agent reviews stills for UI state, lag, captions on screen, button labels, etc.

Complements (does not replace) app-side **debug logs** and **text transcripts**. Frames help with **what was on the screen**; logs/transcripts help with **what the app thought**.

---

## Suggested product shape (language-agnostic)

These are intent-level only—not a tech stack:

| Concern | Intent |
|--------|--------|
| Input | One short video file (common phone/desktop formats) |
| Gate | Duration check → fail clearly if > 30s |
| Sampling | Extract frames at a controlled rate (e.g. time-based or capped count) so output stays small |
| Cap | Optional hard max number of images (e.g. dozens, not hundreds) in addition to the 30s rule |
| Output | Directory of ordered stills + lightweight manifest (frame number / timestamp → path) |
| UX | Simple enough for repeated debug use; CLI is enough unless later product needs demand a GUI |
| Failure modes | Clear errors: too long, unreadable file, no frames produced |

Exact frame rate, naming scheme, and UI are **open** for the separate project conversation.

---

## Explicit non-goals (for now)

- Parsing videos longer than 30 seconds  
- Full speech-to-text from video audio as the primary feature  
- Replacing Live Captions capture tools (e.g. Interpres)  
- Cloud upload / SaaS dependency for core conversion  
- Choosing implementation language or frameworks in this document  
- Building inside the Interpres repository (AgentVideoParse is a **separate** project)

---

## Relationship to Interpres

| Project | Job |
|---------|-----|
| **Interpres** | Hook OS Live Captions, show/save transcripts, accessibility-focused companion |
| **AgentVideoParse** | Short video → still frames so agents can *see* a debug session |

They can be used together in a workflow; they remain separate codebases and product identities.

---

## Open questions (for the next conversation)

- Default sampling rate vs “key frames only”  
- Exact max image count  
- Manifest format (plain text vs structured)  
- Phone screen-recording quirks (rotation, reflections, UI chrome)  
- Whether the tool should ever strip or warn on upside-down/mirrored phone shots  
- Packaging for non-technical users later  

No decisions required here—only noted so the next session can pick them up.

---

## One-line summary for a new chat

> **AgentVideoParse** is a local open-source project to turn **≤30s** debug videos into an ordered set of **frame screenshots** so AI coding agents can review UI/debug sessions; longer videos are not allowed; language/stack TBD.

---

*Saved as conversation basis, not a build plan. Continue in a separate interface under this project directory.*
