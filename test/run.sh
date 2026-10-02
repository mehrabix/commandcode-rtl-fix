#!/usr/bin/env bash
#
# Runs the standalone RTL fix test page in headless Chrome and prints the
# resolved direction/alignment of each sample element.
#
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHROME="${CHROME:-google-chrome-stable}"
command -v "$CHROME" >/dev/null 2>&1 || CHROME=google-chrome
command -v "$CHROME" >/dev/null 2>&1 || { echo "Chrome not found; set CHROME=/path/to/chrome" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "node is required" >&2; exit 1; }

DOM="$(mktemp)"
trap 'rm -f "$DOM"' EXIT

"$CHROME" --headless=new --disable-gpu --no-sandbox --virtual-time-budget=6000 \
	--dump-dom "file://$DIR/test.html" >"$DOM" 2>/dev/null

node -e '
const fs = require("fs");
const s = fs.readFileSync(process.argv[1], "utf8");
const m = s.match(/<pre id="report">REPORT_JSON=([\s\S]*?)<\/pre>/);
if (!m) { console.error("no report found"); process.exit(1); }
const rows = JSON.parse(m[1]);
let failed = 0;
const expect = {
	p_fa: ["rtl", "rtl", "start"], p_en: [null, "ltr", "left"],
	p_mix: ["rtl", "rtl", "start"], li_fa: ["rtl", "rtl", "start"],
	li_en: [null, "ltr", "left"], pre_fa: [null, "ltr", "left"],
	composer: ["auto", "rtl", "start"], ta: ["auto", "rtl", "start"],
	inp: ["auto", "rtl", "start"], dyn: ["rtl", "rtl", "start"],
	// A Persian-majority sentence that starts with a Latin word must still
	// resolve to RTL; an English-majority line with a Persian phrase stays LTR.
	p_mix_fa_first: ["rtl", "rtl", "start"],
	p_mix_en_first: ["rtl", "rtl", "start"],
	p_en_majority: ["ltr", "ltr", "start"],
	// A long Latin path/identifier must not out-vote the Persian prose.
	p_path: ["rtl", "rtl", "start"],
	// Content that changed from Persian to English must drop the stale dir.
	p_flip: [null, "ltr", "left"],
};
// Elements whose resolved direction is RTL should use Vazirmatn.
const rtlFont = new Set(["p_fa", "p_mix", "p_mix_fa_first", "p_mix_en_first", "p_path", "li_fa", "composer", "ta", "inp", "dyn"]);
let fontLoaded = false;
for (const r of rows) {
	const e = expect[r.id];
	let ok = !e || (String(r.dir) === String(e[0]) && r.dirComputed === e[1] && r.align === e[2]);
	if (rtlFont.has(r.id) && !/Vazirmatn/.test(r.font)) ok = false;
	if (!rtlFont.has(r.id) && e && /Vazirmatn/.test(r.font)) ok = false;
	if (r.fontLoaded) fontLoaded = true;
	if (!ok) failed++;
	console.log(`${ok ? "ok  " : "FAIL"}  ${String(r.id).padEnd(9)} dir=${String(r.dir).padEnd(5)} computed=${r.dirComputed.padEnd(4)} align=${r.align.padEnd(6)} font=${/Vazirmatn/.test(r.font) ? "vazirmatn" : "default"}`);
}
if (!fontLoaded) { console.error("FAIL  Vazirmatn font file did not load"); failed++; }
process.exit(failed ? 1 : 0);
' "$DOM"
