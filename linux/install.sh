#!/usr/bin/env bash
#
# Command Code RTL fix - installer (unpacked install).
# Default target: /opt/Command Code/resources/app
#
# Usage:  sudo bash install.sh
#         COMMAND_CODE_APP=/path/to/resources/app bash install.sh
#
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="$SRC/../assets"

die() { echo "Error: $*" >&2; exit 1; }

command -v perl >/dev/null 2>&1 || die "perl is required (apt: sudo apt install perl)."

# --- locate the app ---------------------------------------------------------
APP_DIR=""
if [ -n "${COMMAND_CODE_APP:-}" ]; then
	APP_DIR="$COMMAND_CODE_APP"
else
	for c in \
		"/opt/Command Code/resources/app" \
		"/usr/lib/command-code/resources/app" \
		"/usr/share/command-code/resources/app" \
		"/opt/command-code/resources/app"; do
		if [ -f "$c/out/renderer/index.html" ]; then APP_DIR="$c"; break; fi
	done
fi

if [ -z "$APP_DIR" ] || [ ! -f "$APP_DIR/out/renderer/index.html" ]; then
	echo "Could not find an unpacked Command Code install." >&2
	echo "AppImage and snap builds are read-only and are not supported by this script" >&2
	echo "(see the README for those). Set COMMAND_CODE_APP=/path/to/resources/app to override." >&2
	exit 1
fi

if [ -f "$APP_DIR/app.asar" ]; then
	die "This install is packaged as app.asar. Extract it first (see README) or use an unpacked build."
fi

RENDERER="$APP_DIR/out/renderer"

if [ ! -w "$RENDERER" ] && [ "$(id -u)" -ne 0 ]; then
	die "No write permission to $RENDERER - re-run with: sudo bash \"$SRC/install.sh\""
fi

# --- back up, copy, inject --------------------------------------------------
[ -f "$RENDERER/.index.html.rtl-fix.bak" ] || cp -a "$RENDERER/index.html" "$RENDERER/.index.html.rtl-fix.bak"
cp -a "$ASSETS/rtl-fix.css" "$RENDERER/rtl-fix.css"
cp -a "$ASSETS/rtl-fix.js" "$RENDERER/rtl-fix.js"
perl "$ASSETS/inject.pl" "$RENDERER/index.html"

echo
echo "RTL fix installed into: $RENDERER"
echo "Fully quit Command Code and open it again."
echo "An update replaces the renderer, so re-run this script after updating."
