# transcribe-md

Live audio transcription to Markdown, right from Claude Code or Cursor. macOS only (requires macOS 14+).

Records your microphone and system audio, transcribes in real-time using [whisper.cpp](https://github.com/ggerganov/whisper.cpp) with Metal GPU acceleration, and writes a clean timestamped transcript to a Markdown file. No cloud APIs, everything runs locally on your Mac.

## What it does

Type `/transcribe-md meeting.md` in Claude Code or Cursor and it starts recording. When you stop it (or the timer runs out), you get a transcript like this:

```markdown
## Transcript -- 2025-06-15 14:30

**[14:30:05] You:** So the main issue is the authentication flow breaks on mobile.

**[14:30:12] Them:** Right, I think the redirect URI isn't being handled correctly by the webview.

**[14:30:21] You:** Can we use the universal links approach instead?

**[14:30:28] Them:** Yeah, that should work. Let me check if the backend already supports it.
```

- **"You"** = your microphone
- **"Them"** = system audio (the other person on a call)
- Mic echoes are automatically deduplicated — if your speakers pick up the other person's audio, it won't show up twice

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/hrescak/transcribe-md/main/install.sh | bash
```

This installs transcribe-md and registers it as a skill in both **Claude Code** and **Cursor**. That's it.

### What the installer does

1. Clones the repo to `~/.local/share/transcribe-md/`
2. Links the skill into Claude Code (via `~/.claude/commands/`)
3. Copies the skill definition into Cursor (`~/.cursor/skills-cursor/transcribe-md/`)
4. Installs dependencies (ffmpeg, whisper.cpp, model, system-audio-tap)

Re-running the installer updates to the latest version.

## Usage

In Claude Code or Cursor, use the `/transcribe-md` slash command:

```
/transcribe-md meeting.md                  → Record until you stop it
/transcribe-md --duration 30 meeting.md    → Record for 30 minutes
/transcribe-md --mic-only notes.md         → Mic only, no system audio
/transcribe-md --devices                   → List available microphones
/transcribe-md --setup                     → Install dependencies without recording
```

Or run the script directly:

```bash
~/.local/share/transcribe-md/scripts/transcribe-to-md meeting.md
```

### Options

| Flag               | Description                                   |
| ------------------ | --------------------------------------------- |
| `--duration <MIN>` | Auto-stop after N minutes                     |
| `--mic-only`       | Skip system audio capture                     |
| `--mic <IDX>`      | Use a specific microphone by device index     |
| `--chunk <SEC>`    | Chunk duration in seconds (default: 10)       |
| `--devices`        | List available microphone devices             |
| `--setup`          | Install/verify dependencies without recording |

## How it works

```
┌────────────┐     ┌─────────┐     ┌────────────┐     ┌──────────┐
│ Microphone │────▶│ ffmpeg  │────▶│            │     │          │
│ (You)      │     │ 16kHz   │     │ whisper.cpp│────▶│ notes.md │
│            │     │ mono WAV│     │  (Metal)   │     │          │
└────────────┘     └─────────┘     │            │     └──────────┘
                                   │            │
┌────────────┐     ┌─────────┐     │            │
│ System     │────▶│ Swift   │────▶│            │
│ Audio      │     │ 48kHz   │     └────────────┘
│ (Them)     │     │ stereo  │
└────────────┘     └─────────┘
                    ScreenCaptureKit
```

1. **Mic recording** — ffmpeg captures your microphone via AVFoundation at 16kHz mono
2. **System audio** — A Swift helper captures all system audio via macOS ScreenCaptureKit (no BlackHole or virtual audio devices needed)
3. **Chunked processing** — Audio is recorded in configurable chunks (default 10s) and transcribed in parallel
4. **Transcription** — whisper.cpp runs the `base.en` model with Metal GPU acceleration
5. **Deduplication** — When using speakers (no headphones), the mic picks up system audio. transcribe-md uses text similarity matching to detect and remove these echoes
6. **Output** — Timestamped, speaker-labeled Markdown appended to your file in real-time

## Requirements

- **macOS 14+** (Sonoma) — required for ScreenCaptureKit audio capture
- **Apple Silicon or Intel Mac** — whisper.cpp builds with Metal acceleration on both
- **Python 3** — comes with macOS
- **Screen Recording permission** — your terminal app needs this for system audio capture. Go to System Settings → Privacy & Security → Screen Recording and add your terminal (Terminal.app, iTerm2, Ghostty, etc.)

### Dependencies

The installer automatically sets up:

- **ffmpeg** via Homebrew (for mic recording)
- **whisper.cpp** built from source with Metal support (for transcription)
- **base.en model** (~150 MB, downloaded from HuggingFace)
- **system-audio-tap** Swift binary (for system audio capture)

Everything is cached in `~/.cache/transcribe-cli/` so subsequent runs start instantly.

## Uninstall

```bash
# Remove the installation
rm -rf ~/.local/share/transcribe-md

# Remove Claude Code skill link
rm -f ~/.claude/commands/transcribe-md.md

# Remove Cursor skill
rm -rf ~/.cursor/skills-cursor/transcribe-md

# Optionally remove cached dependencies (whisper.cpp, model)
rm -rf ~/.cache/transcribe-cli
```

## Acknowledgements

This entire tool — the Python transcription script, the Swift system audio helper and the installer was written by Claude Opus 4.6.

## License

MIT
