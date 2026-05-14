#!/usr/bin/env bash
set -euo pipefail

# transcribe-md installer
# Installs the transcribe-md skill for Claude Code and Cursor.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/podo/transcribe-md/main/install.sh | bash

REPO="https://github.com/podo/transcribe-md.git"
INSTALL_DIR="$HOME/.local/share/transcribe-md"

CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"
CURSOR_SKILLS_DIR="$HOME/.cursor/skills-cursor"
CURSOR_MANIFEST="$CURSOR_SKILLS_DIR/.cursor-managed-skills-manifest.json"

# ── Helpers ─────────────────────────────────────────────────────────────────

info()  { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
err()   { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

reclone() {
  rm -rf "$INSTALL_DIR"
  git clone --depth 1 "$REPO" "$INSTALL_DIR" --quiet
}

# ── Pre-flight ──────────────────────────────────────────────────────────────

[[ "$(uname -s)" == "Darwin" ]] || err "transcribe-md requires macOS (uses AVFoundation, ScreenCaptureKit, Metal)"
command -v git >/dev/null 2>&1 || err "git is required but not found"

FORCE_RECLONE=false
for arg in "$@"; do
  case "$arg" in
    --reclone) FORCE_RECLONE=true ;;
    *) err "Unknown option: $arg (supported: --reclone)" ;;
  esac
done

# ── Clone / update ──────────────────────────────────────────────────────────
#
# Re-running this installer always lands on the latest version. A clean,
# correctly-tracked checkout is fast-forwarded in place; anything else — a
# different remote, diverged history, or local edits — falls back to a fresh
# re-clone. Local modifications are backed up before they are replaced.

info "Installing transcribe-md"

if [ "$FORCE_RECLONE" = true ]; then
  warn "Forcing a clean re-clone (--reclone)"
  reclone
elif [ -d "$INSTALL_DIR/.git" ]; then
  current_remote="$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || true)"
  if [ "$current_remote" != "$REPO" ]; then
    warn "Existing install tracks a different remote — re-cloning"
    reclone
  elif [ -n "$(git -C "$INSTALL_DIR" status --porcelain)" ]; then
    backup_dir="${TMPDIR:-/tmp}/transcribe-md-backup-$(date +%Y%m%d-%H%M%S)"
    warn "Existing install has local changes — backing up to $backup_dir"
    git -C "$INSTALL_DIR" status --porcelain | cut -c4- | while IFS= read -r f; do
      mkdir -p "$backup_dir/$(dirname "$f")"
      cp -R "$INSTALL_DIR/$f" "$backup_dir/$f" 2>/dev/null || true
    done
    reclone
  else
    info "Updating existing installation..."
    if git -C "$INSTALL_DIR" fetch --quiet origin main \
       && git -C "$INSTALL_DIR" checkout -q -B main origin/main; then
      ok "Updated to $(git -C "$INSTALL_DIR" rev-parse --short HEAD)"
    else
      warn "Could not fast-forward — re-cloning"
      reclone
    fi
  fi
else
  reclone
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
