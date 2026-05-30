/* ev — Terminal CLI landing · interactions */
(() => {
  "use strict";
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  /* ---- typewriter ---- */
  async function type(el, text, cps = 28) {
    if (reduce) { el.textContent = text; return; }
    el.textContent = "";
    for (const ch of text) { el.textContent += ch; await sleep(1000 / cps); }
  }

  /* ---- hero command ---- */
  const typed = document.getElementById("typed");
  if (typed) type(typed, "ev ~/work", 16);

  /* ---- progress bars: [||||||||||.....] ---- */
  function fillBar(el) {
    const pct = Math.max(0, Math.min(100, +el.dataset.fill || 0));
    const width = 16;
    const target = Math.round((pct / 100) * width);
    let n = 0;
    const render = (k) => "[" + "|".repeat(k) + ".".repeat(width - k) + "]";
    if (reduce) { el.textContent = render(target); return; }
    const step = () => {
      el.textContent = render(n);
      if (n < target) { n++; setTimeout(step, 45); }
    };
    step();
  }

  /* ---- copy buttons ---- */
  document.querySelectorAll(".copy").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const src = document.getElementById(btn.dataset.copy);
      if (!src) return;
      try {
        await navigator.clipboard.writeText(src.textContent.trim());
        const old = btn.textContent;
        btn.textContent = "[ COPIED ]";
        btn.classList.add("copied");
        setTimeout(() => { btn.textContent = old; btn.classList.remove("copied"); }, 1400);
      } catch (_) { /* clipboard blocked — ignore */ }
    });
  });

  /* ---- live demo ---- */
  const demoQuery = document.getElementById("demo-query");
  const demoList = document.getElementById("demo-list");
  const demoPreview = document.getElementById("demo-preview");

  const HWPX = "규정변경예고_금융투자업규정_개정고시안.hwpx";
  const results = [
    { f: HWPX,            ln: "20", txt: "증권사의 유동성 리스크 관리 역량 및 위기 대응력 제고…" },
    { f: HWPX,            ln: "21", txt: "유동성 규제체계를 개선하는 한편, 외국인 투자자의…" },
    { f: "회의록_2026Q2.docx", ln: "14", txt: "유동성 점검 안건 — 분기 자금운용 리뷰 결과…" },
    { f: "README.md",     ln: "8",  txt: "타이핑하는 순간 파일명과 내용을 동시에 뒤진다…" },
    { f: "lib/search.sh", ln: "12", txt: "ev_rg_cmd \"$EV_ROOT\" \"$hidden\" \"$q\" \"$EV_EXTRACTOR\"" },
  ];

  const preview = [
    "│ 1. 개정이유",
    "│",
    "│ 증권사의 유동성 리스크 관리 역량 및 위기",
    "│ 대응력 제고를 위해 증권사 유동성 규제",
    "│ 체계를 개선하는 한편, 외국인 투자자의",
    "│ 국내시장 접근성 제고를 위해…",
  ];

  function renderResults() {
    demoList.innerHTML = "";
    results.forEach((r, i) => {
      const li = document.createElement("li");
      if (i === 0) li.classList.add("sel");
      li.style.animationDelay = (reduce ? 0 : i * 0.08) + "s";
      li.innerHTML = `${escapeHtml(r.f)}<span class="ln">:${r.ln}:</span>${escapeHtml(r.txt)}`;
      demoList.appendChild(li);
    });
  }
  function renderPreview() {
    demoPreview.innerHTML = preview
      .map((l, i) => (i === 2 ? `<span class="hl">${escapeHtml(l)}</span>` : escapeHtml(l)))
      .join("\n");
  }
  function escapeHtml(s) {
    return s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  }

  async function runDemo() {
    renderPreview();
    if (reduce) { if (demoQuery) demoQuery.textContent = "유동성"; renderResults(); return; }
    await sleep(600);
    await type(demoQuery, "유동성", 6);
    await sleep(180);
    renderResults();
  }

  /* ---- kick off when visible ---- */
  const io = new IntersectionObserver((entries, obs) => {
    entries.forEach((e) => {
      if (!e.isIntersecting) return;
      if (e.target.id === "demo-list") { runDemo(); obs.unobserve(e.target); }
      if (e.target.classList.contains("stat__bar")) { fillBar(e.target); obs.unobserve(e.target); }
    });
  }, { threshold: 0.4 });

  if (demoList) io.observe(demoList);
  document.querySelectorAll(".stat__bar").forEach((el) => io.observe(el));
})();
