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
- `--language <CODE>` — Spoken language code (default: `en`). Use `lt` for Lithuanian, `auto` to auto-detect. Non-English automatically downloads the multilingual model (~500 MB, one-time).
- `--model <NAME|PATH>` — Override the model. Built-in names: `base.en` (~150 MB, English only), `large-v3-turbo-q5` (~500 MB, multilingual). Or provide an absolute path to a custom `.bin` file.

### Examples

- `/transcribe-md --duration 30 meeting.md` — Record a 30-minute meeting
- `/transcribe-md notes.md` — Record until Ctrl-C
- `/transcribe-md --mic-only dictation.md` — Mic only, no system audio
- `/transcribe-md --devices` — List available microphones
- `/transcribe-md --language lt susitikimas.md` — Record Lithuanian meeting
- `/transcribe-md --language auto --duration 30 meeting.md` — Auto-detect language
- `/transcribe-md` — Ask what to transcribe, suggest a filename, ask if they want a time limit

### How it works

- Records mic via ffmpeg and system audio via a Swift helper (ScreenCaptureKit)
- Transcribes in real-time using whisper.cpp with Metal GPU acceleration
- Mic echoes of system audio are automatically deduplicated
- Output: `**[HH:MM:SS] You:** text` and `**[HH:MM:SS] Them:** text`

### Multilingual Support

Non-English languages use the `large-v3-turbo-q5` model (~500 MB, downloaded once on first use). For Lithuanian, expected Word Error Rate is ~22–25%.

**Higher accuracy for Lithuanian** (~20.7% WER): Convert the `DrishtiSharma/whisper-large-v2-lithuanian` HuggingFace model to GGML format, then use `--model`:

```bash
# One-time conversion (requires Python + transformers + torch)
pip install transformers torch
git clone https://huggingface.co/DrishtiSharma/whisper-large-v2-lithuanian
python3 ~/.cache/transcribe-cli/whisper.cpp/models/convert-h5-to-ggml.py \
    ./whisper-large-v2-lithuanian \
    ~/.cache/transcribe-cli/whisper.cpp \
    ~/.cache/transcribe-cli/models/

# Then use it:
/transcribe-md --model ~/.cache/transcribe-cli/models/ggml-model.bin --language lt notes.md
```

### Dependencies

Auto-installed on first run. whisper.cpp and models cached in `~/.cache/transcribe-cli/`. System audio requires macOS 14+ and **Screen Recording** permission for the terminal.
