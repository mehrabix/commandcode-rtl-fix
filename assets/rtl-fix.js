/*
 * Command Code desktop - RTL content fix.
 *
 * The app only ships English and Chinese locales and never sets a `dir`
 * attribute, so Persian/Arabic/Hebrew text is laid out left-to-right and mixed
 * content breaks bidirectional ordering. This script marks text-bearing blocks
 * that contain RTL characters with dir="auto" so the browser applies the
 * correct base direction (and start alignment) per block. Code surfaces stay
 * LTR (see rtl-fix.css). UI chrome written in Latin is left untouched.
 */
(function () {
	"use strict";
	if (window.__commandCodeRtlFix) return;
	window.__commandCodeRtlFix = true;

	// Hebrew, Arabic, Syriac, Thaana, NKo, Samaritan, Arabic Supplement,
	// Arabic Extended-A, Arabic Presentation Forms.
	var RTL = /[\u0591-\u05FF\u0600-\u06FF\u0700-\u074F\u0750-\u077F\u0780-\u07BF\u0800-\u083F\u0840-\u085F\u0860-\u086F\u08A0-\u08FF\uFB1D-\uFDFD\uFE70-\uFEFC]/;
	// Elements that never receive dir="auto" themselves. Text fields are handled
	// separately (see isEditable) so they are intentionally not listed here.
	var SKIP = { PRE: 1, CODE: 1, KBD: 1, SAMP: 1, SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, SVG: 1, MATH: 1 };
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

	function apply(el) {
		if (!el || el.nodeType !== 1) return;

		// Text fields (incl. the composer) always resolve their own direction.
		if (isEditable(el)) {
			if (!el.hasAttribute("dir")) el.setAttribute("dir", "auto");
			return;
		}
		if (SKIP[el.tagName]) return;
		if (el.hasAttribute("dir")) return;
		if (el.closest && el.closest("pre, code, [contenteditable]")) return;

		var d = getComputedStyle(el).display;
		if (d === "inline") return;
		// Only leaf blocks: containers with block-level children are recursed into.
		if (hasBlockChild(el)) return;
		if (!RTL.test(el.textContent || "")) return;

		el.setAttribute("dir", "auto");
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
					for (var j = 0; j < r.addedNodes.length; j++) schedule(r.addedNodes[j]);
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
