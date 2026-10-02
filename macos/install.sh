#!/usr/bin/env bash
#
# Command Code RTL fix - macOS installer.
# Modifies the app bundle in place and re-signs it ad-hoc so Gatekeeper still
# launches it.
#
# Usage:  sudo bash install.sh
#         COMMAND_CODE_APP="/Applications/Command Code.app" bash install.sh
#
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="$SRC/../assets"

die() { echo "Error: $*" >&2; exit 1; }

command -v perl >/dev/null 2>&1 || die "perl is required (ships with macOS)."

# --- locate the app bundle --------------------------------------------------
BUNDLE="${COMMAND_CODE_APP:-}"
if [ -z "$BUNDLE" ]; then
	for c in "/Applications/Command Code.app" "$HOME/Applications/Command Code.app"; do
		if [ -d "$c" ]; then BUNDLE="$c"; break; fi
	done
fi

if [ -z "$BUNDLE" ] || [ ! -d "$BUNDLE" ]; then
	die "Command Code.app not found. Set COMMAND_CODE_APP=\"/path/to/Command Code.app\"."
fi

RES="$BUNDLE/Contents/Resources"
if [ -f "$RES/app.asar" ]; then
	die "This build is packaged as app.asar. Extract it first (see README)."
fi

RENDERER="$RES/app/out/renderer"
[ -f "$RENDERER/index.html" ] || die "renderer index.html not found under $RENDERER"

if [ ! -w "$RENDERER" ] && [ "$(id -u)" -ne 0 ]; then
	die "No write permission to $RENDERER - re-run with: sudo bash \"$SRC/install.sh\""
fi

# --- back up, copy, inject --------------------------------------------------
[ -f "$RENDERER/.index.html.rtl-fix.bak" ] || cp -a "$RENDERER/index.html" "$RENDERER/.index.html.rtl-fix.bak"
cp -a "$ASSETS/rtl-fix.css" "$RENDERER/rtl-fix.css"
cp -a "$ASSETS/rtl-fix.js" "$RENDERER/rtl-fix.js"
perl "$ASSETS/inject.pl" "$RENDERER/index.html"

# --- re-sign ad-hoc ---------------------------------------------------------
# Editing the bundle invalidates its signature; an ad-hoc signature keeps it
# launchable locally. Do not do this on a copy you intend to distribute.
if command -v codesign >/dev/null 2>&1; then
	echo "Re-signing app bundle (ad-hoc)..."
	codesign --force --deep --sign - "$BUNDLE" >/dev/null 2>&1 \
		|| echo "warning: ad-hoc codesign failed; the app may refuse to launch." >&2
fi

echo
echo "RTL fix installed into: $RENDERER"
echo "Fully quit Command Code and open it again."
echo "An update replaces the renderer, so re-run this script after updating."
