---
name: transcribe-md
description: Record and transcribe audio to a markdown file using whisper.cpp (mic + system audio)
allowed-tools: Bash
---

# Transcribe to Markdown

Record and transcribe audio to a timestamped markdown file using whisper.cpp with Metal acceleration. Captures both microphone and system audio (via ScreenCaptureKit).

## Usage

```bash
~/.local/share/transcribe-md/scripts/transcribe-to-md <file.md>
~/.local/share/transcribe-md/scripts/transcribe-to-md --duration 30 meeting.md
~/.local/share/transcribe-md/scripts/transcribe-to-md --mic-only notes.md
```

### Parameters

- `$ARGUMENTS` — Output file path and optional flags
- `--duration <MIN>` — Auto-stop after this many minutes (e.g., `--duration 30` for a 30-min meeting)
- `--mic-only` — Skip system audio capture (mic only)
- `--devices` — List available microphone devices
- `--mic <IDX>` — Use a specific microphone by device index
- `--chunk <SEC>` — Chunk duration in seconds (default: 10)
- `--setup` — Install/verify dependencies without recording

### Examples

- `/transcribe-md --duration 30 meeting.md` — Record a 30-minute meeting
- `/transcribe-md notes.md` — Record until Ctrl-C
- `/transcribe-md --mic-only dictation.md` — Mic only, no system audio
- `/transcribe-md --devices` — List available microphones
- `/transcribe-md` — Ask what to transcribe, suggest a filename, ask if they want a time limit

### How it works

- Records mic via ffmpeg and system audio via a Swift helper (ScreenCaptureKit)
- Transcribes in real-time using whisper.cpp with Metal GPU acceleration
- Mic echoes of system audio are automatically deduplicated
- Output: `**[HH:MM:SS] You:** text` and `**[HH:MM:SS] Them:** text`

### Dependencies

Auto-installed on first run. whisper.cpp and model cached in `~/.cache/transcribe-cli/`. System audio requires macOS 14+ and **Screen Recording** permission for the terminal.
