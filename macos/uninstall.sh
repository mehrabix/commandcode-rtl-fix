#!/usr/bin/env bash
#
# Command Code RTL fix - macOS uninstaller (restores the app bundle).
#
# Usage:  sudo bash uninstall.sh
#
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "Error: $*" >&2; exit 1; }

BUNDLE="${COMMAND_CODE_APP:-}"
if [ -z "$BUNDLE" ]; then
	for c in "/Applications/Command Code.app" "$HOME/Applications/Command Code.app"; do
		if [ -d "$c" ]; then BUNDLE="$c"; break; fi
	done
fi

[ -n "$BUNDLE" ] && [ -d "$BUNDLE" ] || die "Command Code.app not found."
RENDERER="$BUNDLE/Contents/Resources/app/out/renderer"

if [ ! -w "$RENDERER" ] && [ "$(id -u)" -ne 0 ]; then
	die "No write permission to $RENDERER - re-run with: sudo bash \"$SRC/uninstall.sh\""
fi

if [ -f "$RENDERER/.index.html.rtl-fix.bak" ]; then
	cp -a "$RENDERER/.index.html.rtl-fix.bak" "$RENDERER/index.html"
	rm -f "$RENDERER/.index.html.rtl-fix.bak"
fi
rm -f "$RENDERER/rtl-fix.css" "$RENDERER/rtl-fix.js" "$RENDERER/fonts/rtl-fix-font.woff2"
rmdir "$RENDERER/fonts" 2>/dev/null || true

if command -v codesign >/dev/null 2>&1; then
	codesign --force --deep --sign - "$BUNDLE" >/dev/null 2>&1 || true
fi

echo "RTL fix removed from: $RENDERER"
echo "Restart Command Code."
