const RICH_STYLES = ".richMarkdown{white-space:normal;line-height:1.72;overflow-wrap:anywhere}.richMarkdown>*:first-child{margin-top:0!important}.richMarkdown>*:last-child{margin-bottom:0!important}.richMarkdown p{margin:0 0 1em}.richMarkdown h1,.richMarkdown h2,.richMarkdown h3,.richMarkdown h4,.richMarkdown h5,.richMarkdown h6{margin:1.35em 0 .55em;line-height:1.25;letter-spacing:-.02em}.richMarkdown h1{font-size:1.55em}.richMarkdown h2{font-size:1.35em}.richMarkdown h3{font-size:1.18em}.richMarkdown ul,.richMarkdown ol{margin:.55em 0 1em;padding-left:1.55em}.richMarkdown li{margin:.28em 0}.richMarkdown blockquote{margin:1em 0;padding:.1em 0 .1em 1em;border-left:3px solid color-mix(in srgb,var(--text) 18%,transparent);color:color-mix(in srgb,var(--text) 76%,var(--muted))}.richMarkdown hr{height:1px;border:0;background:var(--line);margin:1.4em 0}.richMarkdown a{color:inherit;text-decoration:underline;text-decoration-color:color-mix(in srgb,currentColor 35%,transparent);text-underline-offset:3px}.richMarkdown strong{font-weight:720}.richMarkdown code.inlineCode{padding:.15em .38em;border:1px solid var(--line);border-radius:6px;background:var(--panel2);font:500 .9em ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}.codeBlock{margin:1em 0;border:1px solid var(--line);border-radius:14px;overflow:hidden;background:color-mix(in srgb,var(--panel2) 74%,var(--panel))}.codeBlockHead{height:38px;display:flex;align-items:center;justify-content:space-between;padding:0 10px 0 13px;border-bottom:1px solid var(--line);color:var(--muted);font-size:12px}.codeBlockLang{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.codeCopy{height:28px;padding:0 9px;border:0;border-radius:8px;background:transparent;color:var(--muted);font:inherit;cursor:pointer}.codeCopy:hover{background:var(--panel);color:var(--text)}.codeBlock pre{margin:0;padding:14px 16px;overflow:auto;overscroll-behavior-x:contain;-webkit-overflow-scrolling:touch}.codeBlock pre code{display:block;min-width:max-content;color:var(--text);font:500 13px/1.65 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;tab-size:2}.tableScroll{max-width:100%;overflow-x:auto;margin:1em 0;border:1px solid var(--line);border-radius:12px;-webkit-overflow-scrolling:touch}.richMarkdown table{width:100%;min-width:440px;border-collapse:collapse;font-size:.94em}.richMarkdown th,.richMarkdown td{padding:9px 11px;border-bottom:1px solid var(--line);border-right:1px solid var(--line);vertical-align:top}.richMarkdown th:last-child,.richMarkdown td:last-child{border-right:0}.richMarkdown tr:last-child td{border-bottom:0}.richMarkdown th{background:var(--panel2);font-weight:680;text-align:left}.mathInline{display:inline-block;max-width:100%;vertical-align:-.08em}.mathBlock{display:block;max-width:100%;margin:1em 0;padding:.2em 0;overflow-x:auto;overflow-y:hidden;-webkit-overflow-scrolling:touch;text-align:center}.mathFallback{font-family:ui-serif,Georgia,serif}.hljs-keyword,.hljs-selector-tag,.hljs-literal,.hljs-section,.hljs-link{color:#9b4dca}.hljs-string,.hljs-title,.hljs-name,.hljs-type,.hljs-attribute,.hljs-symbol,.hljs-bullet,.hljs-addition,.hljs-variable,.hljs-template-tag,.hljs-template-variable{color:#087f5b}.hljs-comment,.hljs-quote,.hljs-deletion,.hljs-meta{color:#7b7b7b}.hljs-number,.hljs-regexp,.hljs-built_in,.hljs-builtin-name,.hljs-params{color:#b35c00}@media(prefers-color-scheme:dark){:root:not([data-theme]) .hljs-keyword,:root:not([data-theme]) .hljs-selector-tag,:root:not([data-theme]) .hljs-literal{color:#c792ea}:root:not([data-theme]) .hljs-string,:root:not([data-theme]) .hljs-title,:root:not([data-theme]) .hljs-name{color:#addb67}:root:not([data-theme]) .hljs-number,:root:not([data-theme]) .hljs-built_in{color:#f78c6c}}:root[data-theme=dark] .hljs-keyword,:root[data-theme=dark] .hljs-selector-tag,:root[data-theme=dark] .hljs-literal{color:#c792ea}:root[data-theme=dark] .hljs-string,:root[data-theme=dark] .hljs-title,:root[data-theme=dark] .hljs-name{color:#addb67}:root[data-theme=dark] .hljs-number,:root[data-theme=dark] .hljs-built_in{color:#f78c6c}";

function richMessageStyles() {
  return RICH_STYLES;
}

function richMessageRuntime(copy) {
  copy = Object.assign({ copy: "Copy", copied: "Copied", code: "Code" }, copy || {});
  const assetState = window.__aertexRichAssets || (window.__aertexRichAssets = {});
  const KATEX_JS = "https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js";
  const KATEX_CSS = "https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css";
  const HLJS_JS = "https://cdn.jsdelivr.net/npm/highlight.js@11.10.0/lib/common.min.js";
  const FENCE = String.fromCharCode(96).repeat(3);

  function loadCss(key, href) {
    if (assetState[key]) return assetState[key];
    assetState[key] = new Promise((resolve, reject) => {
      const existing = document.querySelector('link[data-aertex-rich="' + key + '"]');
      if (existing) { resolve(); return; }
      const link = document.createElement("link");
      link.rel = "stylesheet";
      link.href = href;
      link.dataset.aertexRich = key;
      link.onload = () => resolve();
      link.onerror = () => reject(new Error("stylesheet unavailable"));
      document.head.appendChild(link);
    });
    return assetState[key];
  }

  function loadScript(key, src) {
    if (assetState[key]) return assetState[key];
    assetState[key] = new Promise((resolve, reject) => {
      const existing = document.querySelector('script[data-aertex-rich="' + key + '"]');
      if (existing) {
        if ((key === "katex-js" && window.katex) || (key === "hljs-js" && window.hljs)) resolve();
        else existing.addEventListener("load", resolve, { once: true });
        return;
      }
      const script = document.createElement("script");
      script.src = src;
      script.async = true;
      script.dataset.aertexRich = key;
      script.onload = () => resolve();
      script.onerror = () => reject(new Error("script unavailable"));
      document.head.appendChild(script);
    });
    return assetState[key];
  }

  async function ensureKatex() {
    if (window.katex) return window.katex;
    try {
      await Promise.all([loadCss("katex-css", KATEX_CSS), loadScript("katex-js", KATEX_JS)]);
      return window.katex || null;
    } catch {
      return null;
    }
  }

  async function ensureHighlight() {
    if (window.hljs) return window.hljs;
    try {
      await loadScript("hljs-js", HLJS_JS);
      return window.hljs || null;
    } catch {
      return null;
    }
  }

  function appendPlain(parent, value) {
    const parts = String(value || "").split("\n");
    parts.forEach((part, index) => {
      if (index) parent.appendChild(document.createElement("br"));
      if (part) parent.appendChild(document.createTextNode(part));
    });
  }

  const BARE_MATH_COMMAND = /\\(?:frac|dfrac|tfrac|binom|sqrt|sum|prod|int|iint|iiint|oint|lim|log|ln|sin|cos|tan|arcsin|arccos|arctan|exp|cdot|times|div|pm|mp|leq|geq|neq|approx|sim|equiv|propto|infty|partial|nabla|alpha|beta|gamma|delta|epsilon|varepsilon|zeta|eta|theta|vartheta|kappa|lambda|mu|nu|xi|pi|rho|sigma|tau|phi|varphi|chi|psi|omega|mid|cap|cup|subset|supset|subseteq|supseteq|in|notin|to|mapsto|rightarrow|leftarrow|leftrightarrow|Rightarrow|Leftarrow|Leftrightarrow|overline|underline|vec|hat|bar|mathbf|mathrm|mathbb|mathcal|operatorname|text|begin|end|left|right|displaystyle)\b/;
  const MATH_SAFE_PUNCT = "\\\\{}[]_^=+-*/().,:<>|!%'";

  function isMathSafeChar(ch) {
    return /[A-Za-z0-9]/.test(ch) || /\s/.test(ch) || MATH_SAFE_PUNCT.includes(ch);
  }

  function isMathPrefixChar(ch) {
    return /[0-9]/.test(ch) || /\s/.test(ch) || "\\\\{}[]_^=+-*/().,".includes(ch);
  }

  function hasBareLatexMath(value) {
    return BARE_MATH_COMMAND.test(String(value || ""));
  }

  function isRecoverableMathOnlyLine(value) {
    const text = String(value || "").trim();
    if (!text || !hasBareLatexMath(text)) return false;
    if (/[^\x00-\x7F]/.test(text)) return false;
    if (![...text].some(ch => "\\\\{}[]_^=+-*/()".includes(ch))) return false;
    const proseProbe = text
      .replace(/\\[A-Za-z]+/g, " ")
      .replace(/\{[^{}]*\}/g, " ")
      .replace(/[A-Za-z](?:_[A-Za-z0-9{}]+)?/g, " ")
      .replace(/[0-9\s_=+\-*\/().,:<>|!%'\[\]{}]/g, "");
    return !/[A-Za-z]/.test(proseProbe);
  }

  function findBareMathToken(source) {
    const text = String(source || "");
    const command = text.match(BARE_MATH_COMMAND);
    if (!command) return null;
    const markerStart = command.index || 0;
    let start = markerStart;
    let end = markerStart + command[0].length;
    while (start > 0 && isMathSafeChar(text[start - 1])) start--;

    const before = text.slice(start, markerStart);
    const equalIndex = before.lastIndexOf("=");
    if (equalIndex >= 0) {
      const lhs = before.slice(0, equalIndex);
      const lhsMatch = lhs.match(/([A-Za-z][A-Za-z0-9_{}^]*(?:\s*\([^)]*\))?)\s*$/);
      if (lhsMatch) start += lhs.length - lhsMatch[0].length;
    } else {
      start = markerStart;
      while (start > 0 && isMathPrefixChar(text[start - 1])) start--;
    }

    let depth = 0;
    let sawBrace = false;
    let cursor = markerStart;
    while (cursor < text.length) {
      const ch = text[cursor];
      if (!isMathSafeChar(ch)) break;
      if (ch === "{") { depth++; sawBrace = true; }
      if (ch === "}" && depth > 0) depth--;
      if (depth === 0 && sawBrace && /\s/.test(ch)) {
        const tail = text.slice(cursor).match(/^\s+([A-Za-z]{3,})\b/);
        const previous = text.slice(start, cursor).trim().slice(-1);
        if (tail && previous && !/[=+\-*\/^(,_\\]/.test(previous)) break;
      }
      cursor++;
    }
    end = cursor;

    let expression = text.slice(start, end).trim();
    expression = expression.replace(/[,:;]+$/, "").trim();
    if (!expression || !hasBareLatexMath(expression)) return null;
    if (expression.length > 600) return null;
    return { index: start, full: text.slice(start, end), expression };
  }

  function appendRecoveredPlain(parent, value) {
    let rest = String(value || "");
    while (rest) {
      const token = findBareMathToken(rest);
      if (!token) { appendPlain(parent, rest); break; }
      if (token.index > 0) appendPlain(parent, rest.slice(0, token.index));
      addMath(parent, token.expression, false);
      rest = rest.slice(token.index + token.full.length);
    }
  }

  function safeHref(value) {
    const raw = String(value || "").trim();
    if (!raw) return "";
    try {
      const url = new URL(raw, location.origin);
      if (!["http:", "https:", "mailto:"].includes(url.protocol)) return "";
      return url.href;
    } catch {
      return "";
    }
  }

  function findToken(source) {
    const rules = [
      { type: "code", re: /\x60([^\x60\n]+)\x60/ },
      { type: "mathDisplay", re: /\$\$([\s\S]+?)\$\$/ },
      { type: "mathBracket", re: /\\\[([\s\S]+?)\\\]/ },
      { type: "mathParen", re: /\\\(([\s\S]+?)\\\)/ },
      { type: "math", re: /\$([^$\n]+?)\$/ },
      { type: "strong", re: /\*\*([\s\S]+?)\*\*/ },
      { type: "strong", re: /__([\s\S]+?)__/ },
      { type: "strike", re: /~~([\s\S]+?)~~/ },
      { type: "em", re: /\*([^*\n]+?)\*/ },
      { type: "link", re: /\[([^\]\n]+)\]\(([^)\s]+)\)/ },
      { type: "url", re: /https?:\/\/[^\s<>()]+/ }
    ];
    let best = null;
    rules.forEach((rule, priority) => {
      const match = source.match(rule.re);
      if (!match) return;
      if (!best || match.index < best.match.index || (match.index === best.match.index && priority < best.priority)) {
        best = { rule, match, priority };
      }
    });
    return best;
  }

  function prettyMathFallback(expression) {
    let value = String(expression || "").trim();
    const simple = part => /^[A-Za-z0-9_.+-]+$/.test(part) ? part : "(" + part + ")";
    for (let pass = 0; pass < 5; pass++) {
      const next = value.replace(/\\(?:dfrac|tfrac|frac)\{([^{}]+)\}\{([^{}]+)\}/g, (_, numerator, denominator) => simple(numerator) + "⁄" + simple(denominator));
      if (next === value) break;
      value = next;
    }
    value = value
      .replace(/\\sqrt\{([^{}]+)\}/g, "√($1)")
      .replace(/\\(?:cdot|times)\b/g, match => match.includes("times") ? "×" : "·")
      .replace(/\\div\b/g, "÷")
      .replace(/\\pm\b/g, "±")
      .replace(/\\mp\b/g, "∓")
      .replace(/\\leq\b/g, "≤")
      .replace(/\\geq\b/g, "≥")
      .replace(/\\neq\b/g, "≠")
      .replace(/\\approx\b/g, "≈")
      .replace(/\\equiv\b/g, "≡")
      .replace(/\\infty\b/g, "∞")
      .replace(/\\partial\b/g, "∂")
      .replace(/\\nabla\b/g, "∇")
      .replace(/\\sum\b/g, "∑")
      .replace(/\\prod\b/g, "∏")
      .replace(/\\(?:iiint|iint|int)\b/g, match => match.includes("iiint") ? "∭" : match.includes("iint") ? "∬" : "∫")
      .replace(/\\to\b|\\rightarrow\b/g, "→")
      .replace(/\\leftarrow\b/g, "←")
      .replace(/\\leftrightarrow\b/g, "↔")
      .replace(/\\Rightarrow\b/g, "⇒")
      .replace(/\\Leftarrow\b/g, "⇐")
      .replace(/\\Leftrightarrow\b/g, "⇔")
      .replace(/\\alpha\b/g, "α").replace(/\\beta\b/g, "β").replace(/\\gamma\b/g, "γ")
      .replace(/\\delta\b/g, "δ").replace(/\\epsilon\b|\\varepsilon\b/g, "ε")
      .replace(/\\theta\b|\\vartheta\b/g, "θ").replace(/\\lambda\b/g, "λ").replace(/\\mu\b/g, "μ")
      .replace(/\\pi\b/g, "π").replace(/\\rho\b/g, "ρ").replace(/\\sigma\b/g, "σ")
      .replace(/\\phi\b|\\varphi\b/g, "φ").replace(/\\psi\b/g, "ψ").replace(/\\omega\b/g, "ω");
    const subs = { "0":"₀","1":"₁","2":"₂","3":"₃","4":"₄","5":"₅","6":"₆","7":"₇","8":"₈","9":"₉","+":"₊","-":"₋" };
    const sups = { "0":"⁰","1":"¹","2":"²","3":"³","4":"⁴","5":"⁵","6":"⁶","7":"⁷","8":"⁸","9":"⁹","+":"⁺","-":"⁻" };
    value = value
      .replace(/_\{?([0-9+-]+)\}?/g, (_, digits) => [...digits].map(ch => subs[ch] || ch).join(""))
      .replace(/\^\{?([0-9+-]+)\}?/g, (_, digits) => [...digits].map(ch => sups[ch] || ch).join(""));
    return value.replace(/\\(?:left|right|displaystyle)\b/g, "").replace(/[{}]/g, "");
  }

  function addMath(parent, expression, display) {
    const node = document.createElement(display ? "div" : "span");
    node.className = (display ? "mathBlock " : "mathInline ") + "mathFallback";
    node.dataset.math = expression;
    node.dataset.display = display ? "1" : "0";
    node.textContent = prettyMathFallback(expression);
    parent.appendChild(node);
  }

  function appendInline(parent, source) {
    let rest = String(source || "");
    while (rest) {
      const token = findToken(rest);
      if (!token) { appendRecoveredPlain(parent, rest); break; }
      const index = token.match.index || 0;
      if (index) appendRecoveredPlain(parent, rest.slice(0, index));
      const full = token.match[0];
      const type = token.rule.type;
      if (type === "code") {
        const code = document.createElement("code");
        code.className = "inlineCode";
        code.textContent = token.match[1];
        parent.appendChild(code);
      } else if (type === "math" || type === "mathParen" || type === "mathBracket" || type === "mathDisplay") {
        addMath(parent, token.match[1], type === "mathDisplay" || type === "mathBracket");
      } else if (type === "strong" || type === "em" || type === "strike") {
        const el = document.createElement(type === "strong" ? "strong" : type === "em" ? "em" : "s");
        appendInline(el, token.match[1]);
        parent.appendChild(el);
      } else if (type === "link") {
        const href = safeHref(token.match[2]);
        if (href) {
          const link = document.createElement("a");
          link.href = href;
          link.target = "_blank";
          link.rel = "noopener noreferrer nofollow";
          appendInline(link, token.match[1]);
          parent.appendChild(link);
        } else {
          appendRecoveredPlain(parent, full);
        }
      } else if (type === "url") {
        const href = safeHref(full);
        if (href) {
          const link = document.createElement("a");
          link.href = href;
          link.target = "_blank";
          link.rel = "noopener noreferrer nofollow";
          link.textContent = full;
          parent.appendChild(link);
        } else appendRecoveredPlain(parent, full);
      }
      rest = rest.slice(index + full.length);
    }
  }

  function splitTableRow(line) {
    let value = String(line || "").trim();
    if (value.startsWith("|")) value = value.slice(1);
    if (value.endsWith("|")) value = value.slice(0, -1);
    return value.split("|").map(cell => cell.trim());
  }

  function tableDivider(line) {
    const cells = splitTableRow(line);
    return cells.length > 1 && cells.every(cell => /^:?-{3,}:?$/.test(cell.replace(/\s+/g, "")));
  }

  function copyText(value) {
    if (navigator.clipboard && window.isSecureContext) return navigator.clipboard.writeText(value);
    return new Promise((resolve, reject) => {
      const input = document.createElement("textarea");
      input.value = value;
      input.setAttribute("readonly", "");
      input.style.position = "fixed";
      input.style.opacity = "0";
      document.body.appendChild(input);
      input.select();
      try {
        if (!document.execCommand("copy")) throw new Error("copy failed");
        resolve();
      } catch (error) {
        reject(error);
      } finally {
        input.remove();
      }
    });
  }

  function codeBlock(language, source) {
    const shell = document.createElement("div");
    shell.className = "codeBlock";
    const head = document.createElement("div");
    head.className = "codeBlockHead";
    const label = document.createElement("span");
    label.className = "codeBlockLang";
    const normalized = /^[a-z0-9_+#.-]{1,32}$/i.test(String(language || "")) ? String(language).toLowerCase() : "";
    label.textContent = normalized || copy.code;
    const button = document.createElement("button");
    button.type = "button";
    button.className = "codeCopy";
    button.textContent = copy.copy;
    button.addEventListener("click", async () => {
      try {
        await copyText(source);
        button.textContent = copy.copied;
        window.setTimeout(() => { button.textContent = copy.copy; }, 1500);
      } catch {}
    });
    head.append(label, button);
    const pre = document.createElement("pre");
    const code = document.createElement("code");
    code.textContent = source;
    if (normalized) {
      code.dataset.language = normalized;
      code.className = "language-" + normalized.replace(/[^a-z0-9_-]/g, "");
    }
    pre.appendChild(code);
    shell.append(head, pre);
    return shell;
  }

  function blockStart(lines, index) {
    const trimmed = String(lines[index] || "").trim();
    if (!trimmed) return true;
    if (trimmed.startsWith(FENCE) || /^#{1,6}\s+/.test(trimmed) || /^>\s?/.test(trimmed) || /^([-*_])(?:\s*\1){2,}$/.test(trimmed)) return true;
    if (/^\s*[-+*]\s+/.test(lines[index]) || /^\s*\d+\.\s+/.test(lines[index])) return true;
    if (trimmed.startsWith("$$") || trimmed.startsWith("\\[")) return true;
    if (index + 1 < lines.length && String(lines[index]).includes("|") && tableDivider(lines[index + 1])) return true;
    return false;
  }

  function parseBlocks(source) {
    const fragment = document.createDocumentFragment();
    const lines = String(source || "").replace(/\r\n?/g, "\n").split("\n");
    let i = 0;
    while (i < lines.length) {
      const raw = lines[i];
      const trimmed = raw.trim();
      if (!trimmed) { i++; continue; }

      if (trimmed.startsWith(FENCE)) {
        const language = trimmed.slice(FENCE.length).trim().split(/\s+/)[0] || "";
        i++;
        const body = [];
        while (i < lines.length && !lines[i].trim().startsWith(FENCE)) { body.push(lines[i]); i++; }
        if (i < lines.length) i++;
        fragment.appendChild(codeBlock(language, body.join("\n")));
        continue;
      }

      if (trimmed.startsWith("$") || trimmed.startsWith("\\[")) {
        const dollar = trimmed.startsWith("$");
        const opener = dollar ? "$$" : "\\[";
        const closer = dollar ? "$$" : "\\]";
        let expr = trimmed.slice(opener.length);
        if (expr.endsWith(closer) && expr.length > closer.length) {
          expr = expr.slice(0, -closer.length);
          i++;
        } else {
          i++;
          const rows = [expr];
          while (i < lines.length && !lines[i].trim().endsWith(closer)) { rows.push(lines[i]); i++; }
          if (i < lines.length) {
            rows.push(lines[i].trim().slice(0, -closer.length));
            i++;
          }
          expr = rows.join("\n");
        }
        addMath(fragment, expr.trim(), true);
        continue;
      }

      if (isRecoverableMathOnlyLine(trimmed)) {
        addMath(fragment, trimmed, true);
        i++;
        continue;
      }

      const heading = trimmed.match(/^(#{1,6})\s+(.+)$/);
      if (heading) {
        const h = document.createElement("h" + heading[1].length);
        appendInline(h, heading[2]);
        fragment.appendChild(h);
        i++;
        continue;
      }

      if (/^([-*_])(?:\s*\1){2,}$/.test(trimmed)) {
        fragment.appendChild(document.createElement("hr"));
        i++;
        continue;
      }

      if (/^>\s?/.test(trimmed)) {
        const quote = document.createElement("blockquote");
        const rows = [];
        while (i < lines.length && /^>\s?/.test(lines[i].trim())) {
          rows.push(lines[i].trim().replace(/^>\s?/, ""));
          i++;
        }
        appendInline(quote, rows.join("\n"));
        fragment.appendChild(quote);
        continue;
      }

      const unordered = /^\s*[-+*]\s+/.test(raw);
      const ordered = /^\s*\d+\.\s+/.test(raw);
      if (unordered || ordered) {
        const list = document.createElement(ordered ? "ol" : "ul");
        const pattern = ordered ? /^\s*\d+\.\s+(.+)$/ : /^\s*[-+*]\s+(.+)$/;
        while (i < lines.length) {
          const match = lines[i].match(pattern);
          if (!match) break;
          const li = document.createElement("li");
          appendInline(li, match[1]);
          list.appendChild(li);
          i++;
        }
        fragment.appendChild(list);
        continue;
      }

      if (i + 1 < lines.length && raw.includes("|") && tableDivider(lines[i + 1])) {
        const headers = splitTableRow(raw);
        const dividers = splitTableRow(lines[i + 1]);
        const alignments = dividers.map(cell => cell.startsWith(":") && cell.endsWith(":") ? "center" : cell.endsWith(":") ? "right" : "left");
        i += 2;
        const table = document.createElement("table");
        const thead = document.createElement("thead");
        const hrow = document.createElement("tr");
        headers.forEach((cell, index) => {
          const th = document.createElement("th");
          th.style.textAlign = alignments[index] || "left";
          appendInline(th, cell);
          hrow.appendChild(th);
        });
        thead.appendChild(hrow);
        table.appendChild(thead);
        const tbody = document.createElement("tbody");
        while (i < lines.length && lines[i].includes("|") && lines[i].trim()) {
          const cells = splitTableRow(lines[i]);
          const tr = document.createElement("tr");
          headers.forEach((_, index) => {
            const td = document.createElement("td");
            td.style.textAlign = alignments[index] || "left";
            appendInline(td, cells[index] || "");
            tr.appendChild(td);
          });
          tbody.appendChild(tr);
          i++;
        }
        table.appendChild(tbody);
        const scroll = document.createElement("div");
        scroll.className = "tableScroll";
        scroll.appendChild(table);
        fragment.appendChild(scroll);
        continue;
      }

      const rows = [raw];
      i++;
      while (i < lines.length && lines[i].trim() && !blockStart(lines, i)) {
        rows.push(lines[i]);
        i++;
      }
      const paragraph = document.createElement("p");
      appendInline(paragraph, rows.join("\n"));
      fragment.appendChild(paragraph);
    }
    return fragment;
  }

  async function enhanceMath(root) {
    const nodes = [...root.querySelectorAll("[data-math]")];
    if (!nodes.length) return;
    const katex = await ensureKatex();
    if (!katex) return;
    nodes.forEach(node => {
      try {
        katex.render(node.dataset.math || "", node, {
          displayMode: node.dataset.display === "1",
          throwOnError: false,
          trust: false,
          strict: "ignore",
          output: "htmlAndMathml"
        });
        node.classList.remove("mathFallback");
      } catch {}
    });
  }

  async function enhanceCode(root) {
    const nodes = [...root.querySelectorAll("pre code[data-language]")];
    if (!nodes.length) return;
    const hljs = await ensureHighlight();
    if (!hljs) return;
    nodes.forEach(node => {
      try { if (!node.dataset.highlighted) hljs.highlightElement(node); } catch {}
    });
  }

  function render(target, source, options) {
    if (!target) return;
    const final = options && options.final === false ? false : true;
    target.classList.add("richMarkdown");
    target.replaceChildren(parseBlocks(source));
    if (final) {
      void enhanceMath(target);
      void enhanceCode(target);
    }
  }

  function stream(target, source) {
    if (!target) return;
    target.__aertexRichPending = source;
    target.classList.add("isStreaming");
    if (target.__aertexRichFrame) return;
    target.__aertexRichFrame = requestAnimationFrame(() => {
      target.__aertexRichFrame = 0;
      render(target, target.__aertexRichPending || "", { final: false });
    });
  }

  function finalize(target, source) {
    if (!target) return;
    if (target.__aertexRichFrame) cancelAnimationFrame(target.__aertexRichFrame);
    target.__aertexRichFrame = 0;
    target.classList.remove("isStreaming");
    render(target, source, { final: true });
  }

  function enhance(root) {
    (root || document).querySelectorAll("[data-rich-message]").forEach(node => {
      const source = node.textContent || "";
      node.removeAttribute("data-rich-message");
      render(node, source, { final: true });
    });
  }

  window.AERTEXRich = { render, stream, finalize, enhance };
}

/* Exact AERTEX Intelligence website Markdown + KaTeX/highlight.js renderer,
 * sourced from studio/gpt-rich-renderer.js on 2026-10-08.
 * WKWebView is used ONLY as a sandboxed rich message canvas.
 */
{
  const stylesheet = document.createElement("style");
  stylesheet.textContent = richMessageStyles();
  document.head.appendChild(stylesheet);
  richMessageRuntime({copy:"复制",copied:"已复制",code:"代码"});

  window.__aertexRenderMessage = (b64, completed) => {
    try {
      const text = new TextDecoder("utf-8").decode(Uint8Array.from(atob(b64), c => c.charCodeAt(0)));
      const target = document.getElementById("aertex-message");
      if (completed) window.AERTEXRich.finalize(target, text);
      else window.AERTEXRich.stream(target, text);
      window.__aertexReportHeight();
    } catch (error) { /* Never evaluate user-generated source as code. */ }
  };
  let pendingHeight = false;
  window.__aertexReportHeight = () => {
    if (pendingHeight) return;
    pendingHeight = true;
    requestAnimationFrame(() => {
      pendingHeight = false;
      const height = Math.max(20, Math.ceil(document.documentElement.scrollHeight));
      window.webkit?.messageHandlers?.contentHeight?.postMessage(height);
    });
  };
  new ResizeObserver(window.__aertexReportHeight).observe(document.documentElement);
  window.addEventListener("load", window.__aertexReportHeight);
  document.fonts?.addEventListener("loadingdone", window.__aertexReportHeight);
  window.__aertexReportHeight();
}
