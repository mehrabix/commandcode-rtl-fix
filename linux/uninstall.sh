#!/usr/bin/env bash
#
# Command Code RTL fix - uninstaller (restores the original renderer).
#
# Usage:  sudo bash uninstall.sh
#
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "Error: $*" >&2; exit 1; }

APP_DIR="${COMMAND_CODE_APP:-}"
if [ -z "$APP_DIR" ]; then
	for c in \
		"/opt/Command Code/resources/app" \
		"/usr/lib/command-code/resources/app" \
		"/usr/share/command-code/resources/app" \
		"/opt/command-code/resources/app"; do
		if [ -f "$c/out/renderer/index.html" ]; then APP_DIR="$c"; break; fi
	done
fi

[ -n "$APP_DIR" ] || die "Could not find the Command Code install."
RENDERER="$APP_DIR/out/renderer"

if [ ! -w "$RENDERER" ] && [ "$(id -u)" -ne 0 ]; then
	die "No write permission to $RENDERER - re-run with: sudo bash \"$SRC/uninstall.sh\""
fi

if [ -f "$RENDERER/.index.html.rtl-fix.bak" ]; then
	cp -a "$RENDERER/.index.html.rtl-fix.bak" "$RENDERER/index.html"
	rm -f "$RENDERER/.index.html.rtl-fix.bak"
fi
rm -f "$RENDERER/rtl-fix.css" "$RENDERER/rtl-fix.js" "$RENDERER/fonts/rtl-fix-font.woff2"
rmdir "$RENDERER/fonts" 2>/dev/null || true

echo "RTL fix removed from: $RENDERER"
echo "Restart Command Code."
