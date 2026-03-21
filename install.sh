#!/usr/bin/env bash
set -euo pipefail

# transcribe-md installer
# Installs the transcribe-md skill for Claude Code and Cursor.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/hrescak/transcribe-md/main/install.sh | bash

REPO="https://github.com/hrescak/transcribe-md.git"
INSTALL_DIR="$HOME/.local/share/transcribe-md"

CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"
CURSOR_SKILLS_DIR="$HOME/.cursor/skills-cursor"
CURSOR_MANIFEST="$CURSOR_SKILLS_DIR/.cursor-managed-skills-manifest.json"

# ── Helpers ─────────────────────────────────────────────────────────────────

info()  { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
err()   { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

# ── Pre-flight ──────────────────────────────────────────────────────────────

[[ "$(uname -s)" == "Darwin" ]] || err "transcribe-md requires macOS (uses AVFoundation, ScreenCaptureKit, Metal)"
command -v git >/dev/null 2>&1 || err "git is required but not found"

# ── Clone / update ──────────────────────────────────────────────────────────

info "Installing transcribe-md"

if [ -d "$INSTALL_DIR/.git" ]; then
  info "Updating existing installation..."
  git -C "$INSTALL_DIR" pull --ff-only --quiet 2>/dev/null || {
    warn "Could not fast-forward; re-cloning..."
    rm -rf "$INSTALL_DIR"
    git clone --depth 1 "$REPO" "$INSTALL_DIR" --quiet
  }
else
  rm -rf "$INSTALL_DIR"
  git clone --depth 1 "$REPO" "$INSTALL_DIR" --quiet
fi

chmod +x "$INSTALL_DIR/scripts/transcribe-to-md"
ok "Installed to $INSTALL_DIR"

# ── Claude Code ─────────────────────────────────────────────────────────────

info "Setting up Claude Code skill"

mkdir -p "$CLAUDE_COMMANDS_DIR"
ln -sfn "$INSTALL_DIR/skills/transcribe-md/SKILL.md" "$CLAUDE_COMMANDS_DIR/transcribe-md.md"
ok "Linked skill → ~/.claude/commands/transcribe-md.md"

# ── Cursor ──────────────────────────────────────────────────────────────────

info "Setting up Cursor skill"

if [ -d "$CURSOR_SKILLS_DIR" ]; then
  # Copy skill into Cursor's skills directory
  mkdir -p "$CURSOR_SKILLS_DIR/transcribe-md"
  cp "$INSTALL_DIR/skills/transcribe-md/SKILL.md" "$CURSOR_SKILLS_DIR/transcribe-md/SKILL.md"

  # Add to manifest if not already present
  if [ -f "$CURSOR_MANIFEST" ]; then
    if ! grep -q '"transcribe-md"' "$CURSOR_MANIFEST" 2>/dev/null; then
      # Add transcribe-md to managedSkillIds array
      if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json, sys
with open('$CURSOR_MANIFEST') as f:
    m = json.load(f)
if 'managedSkillIds' not in m:
    m['managedSkillIds'] = []
if 'transcribe-md' not in m['managedSkillIds']:
    m['managedSkillIds'].append('transcribe-md')
with open('$CURSOR_MANIFEST', 'w') as f:
    json.dump(m, f, indent=2)
    f.write('\n')
"
        ok "Added to Cursor skills manifest"
      else
        warn "python3 not found — please add 'transcribe-md' to $CURSOR_MANIFEST manually"
      fi
    else
      ok "Already in Cursor skills manifest"
    fi
  else
    warn "Cursor skills manifest not found (is Cursor installed?)"
  fi
  ok "Copied skill to ~/.cursor/skills-cursor/transcribe-md/"
else
  warn "Cursor skills directory not found — skipping Cursor setup"
  warn "If Cursor is installed, create ~/.cursor/skills-cursor/ and re-run"
fi

# ── Dependencies ────────────────────────────────────────────────────────────

info "Installing dependencies (ffmpeg, whisper.cpp, models, system-audio-tap)"
"$INSTALL_DIR/scripts/transcribe-to-md" --setup
"$INSTALL_DIR/scripts/transcribe-to-md" --setup --language lt

# ── Done ────────────────────────────────────────────────────────────────────

echo ""
info "Done! transcribe-md is ready."
echo ""
echo "  Claude Code:  /transcribe-md"
echo "  Cursor:       /transcribe-md"
echo ""
echo "  Use --language lt for Lithuanian (model already downloaded)."
echo "  To make Lithuanian the default, add to your shell profile:"
echo "    export TRANSCRIBE_MD_LANGUAGE=lt"
echo ""
echo "  System audio requires Screen Recording permission for your terminal."
echo "  If the permission dialog doesn't appear, grant it manually:"
echo "  System Settings → Privacy & Security → Screen Recording → add your terminal"
echo ""
