/* ev — Apple-minimal landing · interactions */
(() => {
  "use strict";

  // 스크롤 시 nav 하단 구분선 노출
  const nav = document.getElementById("nav");
  const onScroll = () => {
    if (!nav) return;
    nav.classList.toggle("is-scrolled", window.scrollY > 8);
  };
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // 등장 애니메이션 (IntersectionObserver)
  const revealEls = Array.from(document.querySelectorAll(".reveal"));
  if ("IntersectionObserver" in window && revealEls.length) {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-in");
            io.unobserve(entry.target);
          }
        });
      },
      { rootMargin: "0px 0px -10% 0px", threshold: 0.08 }
    );
    revealEls.forEach((el) => io.observe(el));
  } else {
    revealEls.forEach((el) => el.classList.add("is-in"));
  }

  // 쇼케이스 스크린샷 토글 (텍스트 ↔ 비주얼) — Ctrl-V 동작을 그대로 재현
  const shotImg = document.getElementById("shot-img");
  const shotSrc = { text: "shot-text.png", visual: "shot-visual.png" };
  document.querySelectorAll(".shot__btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const mode = btn.dataset.shot;
      if (!shotImg || !shotSrc[mode]) return;
      shotImg.src = shotSrc[mode];
      document
        .querySelectorAll(".shot__btn")
        .forEach((b) => b.classList.toggle("is-active", b === btn));
    });
  });

  // 코드 복사 버튼
  document.querySelectorAll(".copy").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const target = document.getElementById(btn.dataset.copy);
      if (!target) return;
      const text = target.innerText.trim();
      try {
        await navigator.clipboard.writeText(text);
        const original = btn.textContent;
        btn.textContent = "복사됨";
        btn.classList.add("is-done");
        setTimeout(() => {
          btn.textContent = original;
          btn.classList.remove("is-done");
        }, 1600);
      } catch (error) {
        btn.textContent = "복사 실패";
        setTimeout(() => (btn.textContent = "복사"), 1600);
      }
    });
  });
})();
