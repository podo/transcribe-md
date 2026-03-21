---
name: transcribe-md
description: Record and transcribe audio to a markdown file using whisper.cpp (mic + system audio)
allowed-tools: Bash
---

# Transcribe to Markdown

Record and transcribe audio to a timestamped markdown file using whisper.cpp with Metal acceleration. Captures both microphone and system audio (via ScreenCaptureKit). Supports 99 languages.

## Usage

```bash
~/.local/share/transcribe-md/scripts/transcribe-to-md <file.md> [options]
```

### Parameters

- `$ARGUMENTS` — Output file path and optional flags
- `--duration <MIN>` — Auto-stop after this many minutes (e.g., `--duration 30` for a 30-min meeting)
- `--mic-only` — Skip system audio capture (mic only)
- `--devices` — List available microphone devices
- `--mic <IDX>` — Use a specific microphone by device index
- `--chunk <SEC>` — Chunk duration in seconds (default: 10)
- `--setup` — Install/verify dependencies without recording
- `--language <CODE>` — Spoken language code (default: `en`, or `$TRANSCRIBE_MD_LANGUAGE` env var). Use `lt` for Lithuanian, `auto` to auto-detect. Non-English automatically uses the multilingual model (~500 MB, pre-downloaded by installer).
- `--model <NAME|PATH>` — Override model: `base.en` (~150 MB, English only), `large-v3-turbo-q5` (~500 MB, multilingual), or absolute path to a custom `.bin` file.

### Examples

- `/transcribe-md --duration 30 meeting.md` — Record a 30-minute meeting
- `/transcribe-md notes.md` — Record until Ctrl-C
- `/transcribe-md --mic-only dictation.md` — Mic only, no system audio
- `/transcribe-md --devices` — List available microphones
- `/transcribe-md --language lt susitikimas.md` — Record Lithuanian meeting
- `/transcribe-md --language lt --duration 30 meeting.md` — Lithuanian, 30-minute limit
- `/transcribe-md --language auto notes.md` — Auto-detect spoken language

### When invoked without arguments

Ask the user:
1. What to transcribe and suggest a filename
2. Whether they want a time limit (`--duration`)
3. **What language they'll be speaking** — if not English, add `--language <code>` (e.g. `--language lt` for Lithuanian)

### How it works

- Records mic via ffmpeg and system audio via a Swift helper (ScreenCaptureKit)
- Transcribes in real-time using whisper.cpp with Metal GPU acceleration
- English uses `base.en` model; all other languages use `large-v3-turbo-q5` (multilingual)
- Mic echoes of system audio are automatically deduplicated
- Output: `**[HH:MM:SS] You:** text` and `**[HH:MM:SS] Them:** text`
- Non-English transcripts include the language code in the header: `## Transcript [LT] -- ...`

### Multilingual Support

The multilingual model is pre-downloaded during installation — no extra setup needed. Just pass `--language <code>`:

```
lt  Lithuanian      de  German         fr  French
ja  Japanese        zh  Chinese        es  Spanish
uk  Ukrainian       pl  Polish         ru  Russian
```

To avoid typing `--language lt` every time, the user can set:
```bash
export TRANSCRIBE_MD_LANGUAGE=lt   # in ~/.zshrc
```

**Higher accuracy for Lithuanian** via a fine-tuned GGML model (~20.7% WER vs ~22-25%):
```bash
pip install transformers torch
git clone https://huggingface.co/DrishtiSharma/whisper-large-v2-lithuanian
python3 ~/.cache/transcribe-cli/whisper.cpp/models/convert-h5-to-ggml.py \
    ./whisper-large-v2-lithuanian \
    ~/.cache/transcribe-cli/whisper.cpp \
    ~/.cache/transcribe-cli/models/
# Then: /transcribe-md --model ~/.cache/transcribe-cli/models/ggml-model.bin --language lt notes.md
```

### Dependencies

Auto-installed on first run. whisper.cpp and models cached in `~/.cache/transcribe-cli/`. System audio requires macOS 14+ and **Screen Recording** permission for the terminal.
