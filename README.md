# transcribe-md

Live audio transcription to Markdown, right from Claude Code or Cursor. macOS only (requires macOS 14+).

Records your microphone and system audio, transcribes in real-time using [whisper.cpp](https://github.com/ggerganov/whisper.cpp) with Metal GPU acceleration, and writes a clean timestamped transcript to a Markdown file. No cloud APIs, everything runs locally on your Mac.

Supports **99 languages** including Lithuanian, using OpenAI's Whisper large-v3-turbo model.

## What it does

Type `/transcribe-md meeting.md` in Claude Code or Cursor and it starts recording. When you stop it (or the timer runs out), you get a transcript like this:

```markdown
## Transcript -- 2025-06-15 14:30

**[14:30:05] You:** So the main issue is the authentication flow breaks on mobile.

**[14:30:12] Them:** Right, I think the redirect URI isn't being handled correctly by the webview.

**[14:30:21] You:** Can we use the universal links approach instead?

**[14:30:28] Them:** Yeah, that should work. Let me check if the backend already supports it.
```

For Lithuanian:

```markdown
## Transcript [LT] -- 2025-06-15 14:30

**[14:30:05] You:** Taigi pagrindinė problema yra autentifikavimo srautas.

**[14:30:12] Them:** Taip, manau, kad peradresavimo URI nėra tinkamai tvarkomas.
```

- **"You"** = your microphone
- **"Them"** = system audio (the other person on a call)
- Mic echoes are automatically deduplicated — if your speakers pick up the other person's audio, it won't show up twice

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/podo/transcribe-md/main/install.sh | bash
```

This installs transcribe-md and registers it as a skill in both **Claude Code** and **Cursor**. The installer downloads both the English model (~150 MB) and the multilingual model (~500 MB) so all languages work instantly with no delay on first use.

### What the installer does

1. Clones the repo to `~/.local/share/transcribe-md/`
2. Links the skill into Claude Code (via `~/.claude/commands/`)
3. Copies the skill definition into Cursor (`~/.cursor/skills-cursor/transcribe-md/`)
4. Installs dependencies (ffmpeg, whisper.cpp, models, system-audio-tap)

Re-running the installer updates to the latest version.

## Usage

In Claude Code or Cursor, use the `/transcribe-md` slash command:

```
/transcribe-md meeting.md                      → Record until you stop it
/transcribe-md --duration 30 meeting.md        → Record for 30 minutes
/transcribe-md --mic-only notes.md             → Mic only, no system audio
/transcribe-md --language lt susitikimas.md    → Record in Lithuanian
/transcribe-md --language auto meeting.md      → Auto-detect spoken language
/transcribe-md --devices                       → List available microphones
/transcribe-md --setup                         → Install dependencies without recording
```

Or run the script directly:

```bash
~/.local/share/transcribe-md/scripts/transcribe-to-md meeting.md
```

### Options

| Flag                  | Description                                                    |
| --------------------- | -------------------------------------------------------------- |
| `--duration <MIN>`    | Auto-stop after N minutes                                      |
| `--mic-only`          | Skip system audio capture                                      |
| `--mic <IDX>`         | Use a specific microphone by device index                      |
| `--chunk <SEC>`       | Chunk duration. Default: 10s for English, 20s for non-English (Whisper trains on 30s windows, so 10s causes mid-word splices in inflectional languages) |
| `--language <CODE>`   | Spoken language code (default: `en`). See [Languages](#languages) |
| `--model <NAME\|PATH>` | Override model: `base.en`, `large-v3-turbo-q5`, or a `.bin` path |
| `--prompt <TEXT>`     | Initial-prompt vocabulary hint passed to whisper. Useful for code-switched speech (e.g. `--prompt 'workshop design API frontend backend'`) |
| `--no-enhance`        | Disable the default LLM cleanup pass (see [Transcript cleanup](#transcript-cleanup)) |
| `--enhance-model <ALIAS>` | Model alias for cleanup (default: `sonnet`)                |
| `--enhance-system-prompt <TEXT>` | Replace the default cleanup system prompt entirely (for domain-specific cleanup) |
| `--devices`           | List available microphone devices                              |
| `--setup`             | Install/verify dependencies without recording                  |

## Transcript cleanup

**Enabled by default for all languages.** Each transcribed segment passes through your active Claude Code session (`claude -p` — no separate API key required) for a strict cleanup pass before being written to markdown. The cleanup is **language-aware** (the prompt template is parameterized by `--language`) and is most impactful on low-resource inflectional languages.

The cleanup model is instructed to:

- Fix phonetic mangling and incorrect word boundaries
- Correct morphology (case endings, declensions, agreement)
- Restore code-switched English tech terms to their proper English spelling
- Mark unrecoverable garbled sections as `[unclear]`
- **Never** paraphrase, summarize, or invent content

Why it matters: even `large-v3-turbo` produces transcripts with ~28% word error rate on clean Lithuanian and ~30-40% on conversational/code-switched audio. Many of those errors are 1-2 character morphology slips ("priežas" instead of "priežastys") that an LT-capable LLM can recover cheaply. English transcripts mostly pass through unchanged since `base.en` is already accurate — the strict-no-paraphrase prompt makes worst case a no-op.

```bash
# Default — cleanup on:
/transcribe-md --language lt susitikimas.md
/transcribe-md meeting.md                                # English, still cleaned

# Disable cleanup (faster, no `claude` CLI required):
/transcribe-md --no-enhance notes.md

# Customize cleanup:
/transcribe-md --enhance-model haiku notes.md            # cheaper/faster model
/transcribe-md --enhance-model opus  notes.md            # higher-quality model
/transcribe-md --enhance-system-prompt \
   "You clean transcripts of cardiology consultations. Preserve drug names, dosages, and ICD codes exactly." \
   patient-visit.md                                      # domain-specific cleanup
```

**Cost & latency:**

- Uses your current Claude Code session auth — **no separate API key needed**.
- Adds ~3-5 sec per chunk, but cleanup runs *in parallel* with the next chunk's whisper, so end-to-end real-time experience is preserved.
- Approximate cost (when routed to a metered Claude tier): ~$0.02 per hour of recording. Effectively free when routed via a flat-rate Claude Code subscription.
- **Any cleanup failure (CLI missing, timeout, network error) silently falls back to the raw whisper output**, so the recording is never broken by enhancement.
- If `claude` is not on PATH when you run transcribe-md, you'll see a one-line notice at start and recording proceeds with raw output. Pass `--no-enhance` to silence the notice.

## Languages

transcribe-md supports 99 languages via OpenAI's Whisper. Use the `--language` flag with an [ISO 639-1](https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes) code:

```
/transcribe-md --language lt notes.md    # Lithuanian
/transcribe-md --language de notes.md    # German
/transcribe-md --language fr notes.md    # French
/transcribe-md --language ja notes.md    # Japanese
/transcribe-md --language auto notes.md  # Auto-detect
```

English uses the compact `base.en` model (~150 MB). All other languages use `large-v3-turbo-q5` (~500 MB, Metal-accelerated), which is pre-downloaded by the installer.

### Setting a default language

To avoid typing `--language lt` every time, add this to your `~/.zshrc` or `~/.bash_profile`:

```bash
export TRANSCRIBE_MD_LANGUAGE=lt
```

After that, `/transcribe-md notes.md` automatically transcribes in Lithuanian.

### Bringing your own fine-tuned model

For higher accuracy on a specific language, you can convert a HuggingFace Whisper model to GGML format and use it via `--model`:

```bash
# Example: Lithuanian fine-tuned model (WER ~20.7% vs ~22-25% for large-v3-turbo)
pip install transformers torch
git clone https://huggingface.co/DrishtiSharma/whisper-large-v2-lithuanian

python3 ~/.cache/transcribe-cli/whisper.cpp/models/convert-h5-to-ggml.py \
    ./whisper-large-v2-lithuanian \
    ~/.cache/transcribe-cli/whisper.cpp \
    ~/.cache/transcribe-cli/models/

/transcribe-md --model ~/.cache/transcribe-cli/models/ggml-model.bin --language lt notes.md
```

## How it works

```
┌────────────┐     ┌─────────┐     ┌─────────────────────┐     ┌──────────┐
│ Microphone │────▶│ ffmpeg  │────▶│                     │     │          │
│ (You)      │     │ 16kHz   │     │ whisper.cpp (Metal)  │────▶│ notes.md │
│            │     │ mono WAV│     │ base.en / multilingual     │          │
└────────────┘     └─────────┘     │                     │     └──────────┘
                                   │                     │
┌────────────┐     ┌─────────┐     │                     │
│ System     │────▶│ Swift   │────▶│                     │
│ Audio      │     │ 48kHz   │     └─────────────────────┘
│ (Them)     │     │ stereo  │
└────────────┘     └─────────┘
                    ScreenCaptureKit
```

1. **Mic recording** — ffmpeg captures your microphone via AVFoundation at 16kHz mono
2. **System audio** — A Swift helper captures all system audio via macOS ScreenCaptureKit (no BlackHole or virtual audio devices needed)
3. **Chunked processing** — Audio is recorded in configurable chunks (default 10s) and transcribed in parallel
4. **Transcription** — whisper.cpp runs locally with Metal GPU acceleration. English uses `base.en`; all other languages use `large-v3-turbo-q5` with the appropriate `-l` language flag
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
- **base.en model** (~150 MB, English — downloaded from HuggingFace)
- **large-v3-turbo-q5 model** (~500 MB, multilingual — downloaded from HuggingFace)
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

# Optionally remove cached dependencies (whisper.cpp, models)
rm -rf ~/.cache/transcribe-cli
```

## Acknowledgements

This entire tool — the Python transcription script, the Swift system audio helper and the installer was written by Claude Opus 4.6.

## License

MIT
