/*
 * Command Code desktop - RTL content fix.
 *
 * The app only ships English and Chinese locales and never sets a `dir`
 * attribute, so Persian/Arabic/Hebrew text is laid out left-to-right and mixed
 * content breaks bidirectional ordering. This script sets each RTL-containing
 * text block's base direction (RTL/LTR) from its dominant script, so the
 * browser applies correct bidirectional ordering (and start alignment) per
 * block. Code surfaces stay LTR (see rtl-fix.css). UI chrome written in Latin
 * is left untouched.
 */
(function () {
	"use strict";
	if (window.__commandCodeRtlFix) return;
	window.__commandCodeRtlFix = true;

	// Hebrew, Arabic, Syriac, Thaana, NKo, Samaritan, Arabic Supplement,
	// Arabic Extended-A, Arabic Presentation Forms.
	var RTL = /[\u0591-\u05FF\u0600-\u06FF\u0700-\u074F\u0750-\u077F\u0780-\u07BF\u0800-\u083F\u0840-\u085F\u0860-\u086F\u08A0-\u08FF\uFB1D-\uFDFD\uFE70-\uFEFC]/;
	// Strong left-to-right letters: Latin (+ Latin-1/Extended), Greek, Cyrillic,
	// Armenian, Indic and CJK. Used to weigh a block's dominant script - see
	// directionOf().
	var LTR = /[\u0041-\u005A\u0061-\u007A\u00AA\u00B5\u00BA\u00C0-\u024F\u0370-\u058F\u0900-\u1FFF\u2C00-\uD7FF\uF900-\uFAFF\uFB00-\uFB4F]/;
	// Elements that never receive a direction from this fix. Text fields are
	// handled separately (see isEditable) so they are intentionally not listed.
	var SKIP = { PRE: 1, CODE: 1, KBD: 1, SAMP: 1, SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, SVG: 1, MATH: 1 };
	// Marks a dir attribute this script set, so re-scans can recompute it when
	// the element's content changes (React streaming/re-rendering) instead of
	// keeping a stale direction.
	var MARK = "data-cc-rtl";
	// Inline elements that must not count as "block children" when deciding
	// whether a container is a leaf block.
	var INLINE = { CODE: 1, KBD: 1, SAMP: 1, SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, SVG: 1, MATH: 1 };
	var BLOCKY = { block: 1, flex: 1, grid: 1, "list-item": 1, "table-cell": 1, "table-caption": 1, "flow-root": 1, "inline-block": 1 };

	function isEditable(el) {
		return (
			el.isContentEditable ||
			el.tagName === "TEXTAREA" ||
			(el.tagName === "INPUT" && (!el.type || /^(text|search|url|email|tel)$/i.test(el.type)))
		);
	}

	function hasBlockChild(el) {
		for (var c = el.firstElementChild; c; c = c.nextElementSibling) {
			if (INLINE[c.tagName]) continue;
			if (SKIP[c.tagName]) return true;
			var d = getComputedStyle(c).display;
			if (BLOCKY[d] || d === "block") return true;
		}
		return false;
	}

	// Pick a block's base direction from its *dominant* script instead of the
	// browser's dir="auto" rule (first strong character). That rule lays a
	// Persian-dominant sentence out left-to-right whenever it starts with a
	// Latin word ("Error: ..." / "Failed: ..."), which is the mixed-content bug
	// this fixes. Words are weighed one each - not characters - so a long Latin
	// path/identifier (e.g. /home/user/app.ts) cannot out-vote the surrounding
	// Persian prose. Text inside <pre>/<code>/… is ignored for the same reason.
	// Returns null when the block has no RTL text at all (leave the app alone).
	function directionOf(el) {
		var rtlWords = 0;
		var ltrWords = 0;
		var wordRtl = 0;
		var wordLtr = 0;

		function flush() {
			if (wordRtl) rtlWords++;
			else if (wordLtr) ltrWords++;
			wordRtl = 0;
			wordLtr = 0;
		}

		var walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null);
		var node = walker.nextNode();
		while (node) {
			var parent = node.parentElement;
			if (!parent || !SKIP[parent.tagName]) {
				var text = node.nodeValue || "";
				for (var i = 0; i < text.length; i++) {
					var ch = text.charAt(i);
					if (ch === " " || ch === "\t" || ch === "\n" || ch === "\r" || ch === "\f") {
						flush();
					} else if (RTL.test(ch)) {
						wordRtl++;
					} else if (LTR.test(ch)) {
						wordLtr++;
					}
				}
				flush();
			}
			node = walker.nextNode();
		}

		if (rtlWords === 0) return null;
		// Ties fall to RTL, so Persian punctuation stays on the correct side.
		return ltrWords > rtlWords ? "ltr" : "rtl";
	}

	function apply(el) {
		if (!el || el.nodeType !== 1) return;

		// Text fields (incl. the composer) always resolve their own direction.
		if (isEditable(el)) {
			if (!el.hasAttribute("dir")) el.setAttribute("dir", "auto");
			return;
		}
		if (SKIP[el.tagName]) return;
		if (el.hasAttribute("dir") && !el.hasAttribute(MARK)) return;
		if (el.closest && el.closest("pre, code, [contenteditable]")) return;

		var d = getComputedStyle(el).display;
		if (d === "inline") return;
		// Only leaf blocks: containers with block-level children are recursed into.
		if (hasBlockChild(el)) return;

		var dir = directionOf(el);
		if (!dir) {
			// Content no longer has any RTL text - undo our earlier decision.
			if (el.hasAttribute(MARK)) {
				el.removeAttribute("dir");
				el.removeAttribute(MARK);
			}
			return;
		}

		el.setAttribute("dir", dir);
		el.setAttribute(MARK, "");
	}

	function scan(root) {
		if (!root) return;
		try {
			if (root.nodeType === 1) apply(root);
			var walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT, null);
			var el = walker.nextNode();
			while (el) {
				apply(el);
				el = walker.nextNode();
			}
		} catch (e) {
			/* never break the app because of the fix */
		}
	}

	var pending = [];
	var scheduled = false;

	function schedule(node) {
		if (node) pending.push(node);
		if (scheduled) return;
		scheduled = true;
		requestAnimationFrame(function () {
			scheduled = false;
			var batch = pending;
			pending = [];
			if (!batch.length) {
				scan(document.body || document.documentElement);
				return;
			}
			for (var i = 0; i < batch.length; i++) scan(batch[i]);
		});
	}

	function start() {
		scan(document.body || document.documentElement);
		var observer = new MutationObserver(function (records) {
			for (var i = 0; i < records.length; i++) {
				var r = records[i];
				if (r.type === "characterData") {
					schedule(r.target.parentElement || r.target.parentNode);
				} else {
					for (var j = 0; j < r.addedNodes.length; j++) {
						var n = r.addedNodes[j];
						// Added text nodes have no children to walk; scan their host.
						schedule(n.nodeType === 1 ? n : n.parentElement || n.parentNode);
					}
				}
			}
		});
		observer.observe(document.documentElement, { childList: true, subtree: true, characterData: true });
	}

	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", start, { once: true });
	} else {
		start();
	}
})();
