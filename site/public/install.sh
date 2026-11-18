#!/bin/bash
# Tentakit installer — https://tentakit.com
# Usage: curl -fsSL https://tentakit.com/install.sh | bash
set -euo pipefail

URL="${TENTAKIT_URL:-https://tentakit.com/download/Tentakit.zip}"
APP="Tentakit.app"

say() { printf "\033[1;35m🐙 %s\033[0m\n" "$*"; }
fail() { printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "Tentakit runs on macOS only."
major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$major" -ge 13 ] || fail "Tentakit needs macOS 13 or newer (you have $(sw_vers -productVersion))."

# Install to /Applications if we can write there, otherwise to ~/Applications.
DEST="${TENTAKIT_DEST:-/Applications}"
if [ ! -w "$DEST" ]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "Downloading Tentakit…"
curl -fL --progress-bar "$URL" -o "$TMP/Tentakit.zip" || fail "Download failed. Check your internet connection and try again."

say "Installing to $DEST…"
ditto -x -k "$TMP/Tentakit.zip" "$TMP/unpacked"
[ -d "$TMP/unpacked/$APP" ] || fail "The download looks broken. Please try again."

# Quit a running copy before replacing it.
if pgrep -xq Tentakit; then
  osascript -e 'quit app "Tentakit"' >/dev/null 2>&1 || true
  sleep 1
  pkill -x Tentakit 2>/dev/null || true
fi

rm -rf "$DEST/$APP"
ditto "$TMP/unpacked/$APP" "$DEST/$APP"
xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true

if [ -z "${TENTAKIT_NO_OPEN:-}" ]; then
  say "Starting Tentakit…"
  open "$DEST/$APP"
fi

echo
say "Done! Tentakit lives in your menu bar."
echo "   macOS will ask for Accessibility access — turn Tentakit on in"
echo "   System Settings → Privacy & Security → Accessibility."
