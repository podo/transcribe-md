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
- `--chunk <SEC>` — Chunk duration in seconds (default: 10s for English, 20s for non-English — Whisper was trained on 30s windows, so 10s causes mid-word splices on inflectional languages)
- `--setup` — Install/verify dependencies without recording
- `--language <CODE>` — Spoken language code (default: `en`, or `$TRANSCRIBE_MD_LANGUAGE` env var). Use `lt` for Lithuanian, `auto` to auto-detect. Non-English automatically uses the multilingual model (~500 MB, pre-downloaded by installer).
- `--model <NAME|PATH>` — Override model: `base.en` (~150 MB, English only), `large-v3-turbo-q5` (~500 MB, multilingual), or absolute path to a custom `.bin` file.
- `--prompt <TEXT>` — Initial-prompt vocabulary hint for whisper. Useful for code-switched speech, e.g. `--prompt 'workshop design API frontend backend'` to preserve English tech terms.
- `--no-enhance` — Disable the default LLM cleanup pass (faster, no `claude` CLI required). By default each transcribed segment runs through `claude -p` (your active Claude Code session, no separate API key) for typo/morphology correction and English-term restoration. Cleanup is language-aware and runs in parallel with the next chunk's whisper.
- `--enhance-model <ALIAS>` — Model alias for cleanup (default: `sonnet`). Examples: `sonnet`, `opus`, `haiku`.
- `--enhance-system-prompt <TEXT>` — Replace the default cleanup prompt entirely (for domain-specific cleanup like medical or legal jargon).

### Examples

- `/transcribe-md --duration 30 meeting.md` — Record a 30-minute meeting
- `/transcribe-md notes.md` — Record until Ctrl-C
- `/transcribe-md --mic-only dictation.md` — Mic only, no system audio
- `/transcribe-md --devices` — List available microphones
- `/transcribe-md --language lt susitikimas.md` — Record Lithuanian meeting (cleanup on by default)
- `/transcribe-md --language lt --duration 30 meeting.md` — Lithuanian, 30-minute limit
- `/transcribe-md --language auto notes.md` — Auto-detect spoken language
- `/transcribe-md --no-enhance notes.md` — Skip cleanup pass (faster, raw whisper output)
- `/transcribe-md --language lt --prompt 'workshop design API' meeting.md` — Tech-meeting vocabulary hint
- `/transcribe-md --enhance-model haiku notes.md` — Use cheaper Haiku model for cleanup

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
- **By default**, each chunk's whisper output is passed through `claude -p` for a professional-style cleanup pass before being written to markdown. The cleanup is language-aware (prompt parameterized by `--language`) and produces transcripts with:
  - Proper punctuation and capitalization
  - Fixed morphology and code-switching (English tech terms restored to proper spelling)
  - Light filler-word removal (`uh`, `um`) and stutter collapse — intelligent verbatim
  - `[unclear]` markers on unrecoverable garbled sections
  - Strict no-paraphrase: speaker meaning preserved exactly
  
  Uses your active Claude Code session auth (no separate API key), runs in parallel with the next chunk's whisper, and falls back silently to raw whisper text on any failure. Disable with `--no-enhance`.

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

### Updating

Re-run the install command to update — it detects an existing install and updates it in place:

```bash
curl -fsSL https://raw.githubusercontent.com/podo/transcribe-md/main/install.sh | bash
```

Same command for install and update. A clean checkout is fast-forwarded; a different remote, diverged history, or local edits trigger a fresh re-clone (local changes are backed up to a timestamped directory first). Cached models and builds in `~/.cache/transcribe-cli/` are preserved. Add `--reclone` to force a clean re-clone.
