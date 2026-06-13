(function () {
  const app = document.getElementById("pdCraftApp");
  if (!app) return;

  const productList = document.getElementById("pdcProductList");
  const emptyPick = document.getElementById("pdcEmptyPick");
  const detailPanel = document.getElementById("pdcDetailPanel");
  const btnCraft = document.getElementById("pdcBtnCraft");
  const btnClose = document.getElementById("pdcBtnClose");
  const craftProgress = document.getElementById("pdcCraftProgress");
  const craftProgressLabel = document.getElementById("pdcProgressLabel");
  const craftProgressBar = document.getElementById("pdcProgressBar");
  const craftProgressTime = document.getElementById("pdcProgressTime");
  const levelBar = document.getElementById("pdcLevelBar");
  const stationLabel = document.getElementById("pdcStationLabel");

  let state = { products: [], selectedId: null, stationKey: null };

  function resName() {
    try {
      if (typeof GetParentResourceName === "function") return GetParentResourceName();
    } catch (_) {}
    return "fivempro_ltpd";
  }

  function post(name, data) {
    return fetch(`https://${resName()}/${name}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data || {}),
    }).then((r) => r.json().catch(() => ({})));
  }

  function formatTime(ms) {
    const sec = Math.max(0, Math.ceil((ms || 0) / 1000));
    const m = Math.floor(sec / 60);
    const s = sec % 60;
    return m > 0 ? `${m}:${String(s).padStart(2, "0")}` : `${s} sek.`;
  }

  function canCraft(p) {
    return p && !p.locked && p.ingredients && p.ingredients.every((i) => (i.missing || 0) <= 0);
  }

  function renderList() {
    if (!productList) return;
    productList.innerHTML = "";
    state.products.forEach((p) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "pdc-item" + (state.selectedId === p.id ? " active" : "") + (p.locked ? " locked" : "");
      btn.innerHTML = `<strong>${p.label}</strong><small>${p.levelLabel || ""}${p.locked ? " · užrakinta" : ""}</small>`;
      btn.onclick = () => {
        if (p.locked) return;
        state.selectedId = p.id;
        renderList();
        renderDetail(p);
      };
      productList.appendChild(btn);
    });
  }

  function renderDetail(p) {
    if (!p) {
      emptyPick?.classList.remove("hidden");
      detailPanel?.classList.add("hidden");
      return;
    }
    emptyPick?.classList.add("hidden");
    detailPanel?.classList.remove("hidden");
    document.getElementById("pdcProdTitle").textContent = p.label;
    document.getElementById("pdcProdLevel").textContent = p.levelLabel || `Lygis ${p.craftLevel}`;
    document.getElementById("pdcProdTime").textContent = p.timeLabel || "—";
    const lockPill = document.getElementById("pdcProdLock");
    if (lockPill) {
      lockPill.textContent = p.locked ? "Užrakinta" : "Prieinama";
      lockPill.classList.toggle("warn", !!p.locked);
    }
    document.getElementById("pdcProdOut").textContent =
      p.outputCount > 1 ? `${p.outputLabel} x${p.outputCount}` : p.outputLabel || "—";
    const ul = document.getElementById("pdcIngredientList");
    if (ul) {
      ul.innerHTML = "";
      (p.ingredients || []).forEach((i) => {
        const li = document.createElement("li");
        li.className = (i.missing || 0) <= 0 ? "ok" : "bad";
        li.innerHTML = `<span>${i.label}</span><span>${i.have}/${i.need}</span>`;
        ul.appendChild(li);
      });
    }
    if (btnCraft) btnCraft.disabled = !canCraft(p);
  }

  function showProgress(data) {
    if (!craftProgress) return;
    if (craftProgressLabel) craftProgressLabel.textContent = data.label || "Gaminama…";
    if (craftProgressBar) craftProgressBar.style.width = "0%";
    if (craftProgressTime) craftProgressTime.textContent = `Liko: ${formatTime(data.totalMs || 0)}`;
    craftProgress.classList.remove("hidden");
  }

  function updateProgress(data) {
    if (!craftProgress || craftProgress.classList.contains("hidden")) return;
    if (craftProgressBar && typeof data.pct === "number") {
      craftProgressBar.style.width = `${Math.min(100, Math.max(0, data.pct))}%`;
    }
    if (craftProgressTime && typeof data.remainingMs === "number") {
      craftProgressTime.textContent = `Liko: ${formatTime(data.remainingMs)}`;
    }
  }

  function hideProgress() {
    craftProgress?.classList.add("hidden");
    if (craftProgressBar) craftProgressBar.style.width = "0%";
  }

  window.addEventListener("message", (e) => {
    const msg = e.data || {};
    if (msg.action === "pdCraftOpen") {
      const d = msg.data || {};
      state.products = d.products || [];
      state.stationKey = d.stationKey;
      state.selectedId = state.products.find((x) => !x.locked)?.id || (state.products[0] && state.products[0].id) || null;
      if (stationLabel) stationLabel.textContent = d.stationLabel || "MRPD ginklinė";
      if (levelBar) {
        let txt = `Gamybos lygis ${d.craftLevel || 1} / ${d.maxLevel || 3}`;
        if (d.craftsNeeded && (d.craftLevel || 1) < (d.maxLevel || 3)) {
          txt += ` · ${d.craftsAtLevel || 0}/${d.craftsNeeded} iki kito lygio`;
        }
        levelBar.textContent = txt;
      }
      app.classList.remove("hidden");
      renderList();
      renderDetail(state.products.find((x) => x.id === state.selectedId));
    }
    if (msg.action === "pdCraftClose") {
      app.classList.add("hidden");
      hideProgress();
    }
    if (msg.action === "pdCraftProgress") showProgress(msg.data || {});
    if (msg.action === "pdCraftProgressUpdate") updateProgress(msg.data || {});
    if (msg.action === "pdCraftProgressHide") hideProgress();
    if (msg.action === "pdCraftRefresh") {
      const d = msg.data || {};
      state.products = d.products || state.products;
      if (levelBar && d.craftLevel != null) {
        let txt = `Gamybos lygis ${d.craftLevel || 1} / ${d.maxLevel || 3}`;
        if (d.craftsNeeded && (d.craftLevel || 1) < (d.maxLevel || 3)) {
          txt += ` · ${d.craftsAtLevel || 0}/${d.craftsNeeded} iki kito lygio`;
        }
        levelBar.textContent = txt;
      }
      renderList();
      renderDetail(state.products.find((x) => x.id === state.selectedId));
    }
  });

  btnClose?.addEventListener("click", () => post("pdCraftClose"));
  btnCraft?.addEventListener("click", () => {
    if (!state.selectedId || !state.stationKey) return;
    post("pdCraftStart", { stationKey: state.stationKey, recipeId: state.selectedId });
  });

  document.addEventListener("keydown", (ev) => {
    if (ev.key === "Escape" && !app.classList.contains("hidden")) {
      ev.preventDefault();
      post("pdCraftClose");
    }
  });
})();
