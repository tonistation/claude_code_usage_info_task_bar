#!/bin/bash
set -euo pipefail

# ClaudeUsageBar Installer
# Installs the hook script, configures Claude Code settings, builds and installs the app.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SRC="$SCRIPT_DIR/hooks/usage-cache-hook.sh"
HOOK_DEST="$HOME/.claude/usage-cache-hook.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"
APP_NAME="ClaudeUsageBar"
INSTALL_DIR="$HOME/Applications"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Prerequisites ──────────────────────────────────────────────

info "Checking prerequisites..."

# macOS version check
macos_version=$(sw_vers -productVersion 2>/dev/null || echo "0")
major=$(echo "$macos_version" | cut -d. -f1)
if [ "$major" -lt 13 ]; then
  error "macOS 13 (Ventura) or later is required. You have $macos_version."
fi
info "macOS $macos_version — OK"

# Swift check
if ! command -v swift &>/dev/null; then
  error "Swift is not installed. Install Xcode Command Line Tools: xcode-select --install"
fi
info "Swift $(swift --version 2>&1 | head -1 | sed 's/.*version //' | cut -d' ' -f1) — OK"

# jq check
if ! command -v jq &>/dev/null; then
  error "jq is not installed. Install with: brew install jq"
fi
info "jq — OK"

# Check that hook source exists
if [ ! -f "$HOOK_SRC" ]; then
  error "Hook script not found at $HOOK_SRC. Are you running this from the repo root?"
fi

# ── Install hook script ───────────────────────────────────────

info "Installing hook script..."

mkdir -p "$HOME/.claude"

if [ -f "$HOOK_DEST" ]; then
  warn "Hook script already exists at $HOOK_DEST"
  # Check if it's the same
  if diff -q "$HOOK_SRC" "$HOOK_DEST" &>/dev/null; then
    info "Hook script is already up to date."
  else
    cp "$HOOK_DEST" "$HOOK_DEST.backup.$(date +%s)"
    warn "Existing hook backed up with timestamp."
    cp "$HOOK_SRC" "$HOOK_DEST"
    info "Hook script updated."
  fi
else
  cp "$HOOK_SRC" "$HOOK_DEST"
  info "Hook script installed."
fi

chmod +x "$HOOK_DEST"

# ── Configure Claude Code settings ────────────────────────────

info "Configuring Claude Code settings..."

STATUS_LINE_CMD="bash $HOME/.claude/usage-cache-hook.sh"

if [ -f "$SETTINGS_FILE" ]; then
  # Check if statusLine is already configured
  existing_cmd=$(jq -r '.hooks.statusLine[0].command // empty' "$SETTINGS_FILE" 2>/dev/null)

  if [ "$existing_cmd" = "$STATUS_LINE_CMD" ]; then
    info "Claude Code settings already configured."
  else
    # Backup existing settings
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.$(date +%s)"
    warn "Existing settings backed up with timestamp."

    # Merge statusLine hook into existing settings using jq
    jq --arg cmd "$STATUS_LINE_CMD" '
      .hooks //= {} |
      .hooks.statusLine //= [] |
      if (.hooks.statusLine | map(select(.command == $cmd)) | length) == 0 then
        .hooks.statusLine += [{"command": $cmd}]
      else
        .
      end
    ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    info "Claude Code settings updated with statusLine hook."
  fi
else
  # Create new settings file
  jq -n --arg cmd "$STATUS_LINE_CMD" '{
    hooks: {
      statusLine: [
        { command: $cmd }
      ]
    }
  }' > "$SETTINGS_FILE"
  info "Claude Code settings created."
fi

# ── Build the app ─────────────────────────────────────────────

info "Building $APP_NAME (this may take a moment)..."

cd "$SCRIPT_DIR"
bash build.sh

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "  The app is installed at: $INSTALL_DIR/$APP_NAME.app"
echo "  The hook is at:          $HOOK_DEST"
echo ""
echo "  To launch:  open $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "  Usage data will appear after Claude Code processes its next message."
echo "  Click the menu bar icon (chart icon with percentage) to see your usage."
