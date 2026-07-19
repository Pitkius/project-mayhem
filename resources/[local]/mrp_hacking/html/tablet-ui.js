/** HackOS planšetės UI (premium NUI) */
window.TabletUI = (function () {
  let data = null;
  let selectedTarget = null;
  let currentView = "network";
  let highlightDriveSlot = null;
  let selectedDriveSlot = null;
  let navBound = false;

  const $ = (id) => document.getElementById(id);

  function osLabel(id) {
    if (!id || !data || !data.osCatalog || !data.osCatalog[id]) return "—";
    return data.osCatalog[id].label || id;
  }

  function exploitLabel(id) {
    if (!data || !data.exploitCatalog || !data.exploitCatalog[id]) return id;
    return data.exploitCatalog[id].label || id;
  }

  function statusClass(status) {
    const s = String(status || "").toLowerCase();
    if (s.includes("protect")) return "protected";
    if (s.includes("lock")) return "locked";
    return "online";
  }

  function renderTopbar() {
    if (!data) return;
    const os = data.installed_os;
    const osName = os ? osLabel(os) : "—";
    $("tabletSubtitle").textContent = data.tabletLabel || "Planšetė";
    $("statOs").textContent = osName;
    const used = (data.exploits || []).length + (os ? 1 : 0);
    $("statStorage").textContent = `${used} / ${data.storage || 12}`;
    $("statExploits").textContent = `${(data.exploits || []).length} / ${data.exploitSlots || 3}`;
  }

  function renderSystem() {
    const card = $("systemCard");
    if (!card || !data) return;
    const os = data.installed_os;
    card.innerHTML = `
      <h3>${data.tabletLabel || "Planšetė"}</h3>
      <div class="sys-row"><span class="muted">Įdiegtas OS</span><strong>${osLabel(os)}</strong></div>
      <div class="sys-row"><span class="muted">Tablet tipas</span><strong>${data.tablet || "—"}</strong></div>
      <div class="sys-row"><span class="muted">Saugykla</span><strong>${(data.exploits || []).length + (os ? 1 : 0)} / ${data.storage}</strong></div>
      <div class="sys-row"><span class="muted">Exploit slotai</span><strong>${(data.exploits || []).length} / ${data.exploitSlots}</strong></div>
      <p class="muted small" style="margin-top:12px">Nusipirk flashdrive su payload → System → Install.</p>
    `;
    renderDriveList();
  }

  function renderDriveList() {
    const list = $("driveList");
    if (!list || !data) return;
    list.innerHTML = "";
    const drives = data.flashDrives || [];
    if (!drives.length) {
      list.innerHTML = '<p class="muted small">Flashdrive nerastas inventoriuje.</p>';
      return;
    }
    drives.forEach((d) => {
      const ready = d.ready === true;
      const div = document.createElement("div");
      div.className =
        "drive-row" + (ready ? "" : " empty") + (selectedDriveSlot === d.slot ? " selected" : "");
      const payloadText = ready
        ? (d.payload_type === "os" ? "OS: " : "Exploit: ") + (d.payloadLabel || d.payload_id)
        : "Tuščias";
      div.innerHTML = `<div><strong>Slot ${d.slot}</strong></div><div class="muted small">${payloadText}</div>`;
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "cyber-btn buy-btn";
      btn.textContent = ready ? "Įdiegti" : "Tuščias";
      btn.disabled = !ready;
      btn.onclick = () => installFromSlot(d.slot);
      div.appendChild(btn);
      list.appendChild(div);
    });
  }

  async function installFromSlot(slot) {
    selectedDriveSlot = slot;
    renderDriveList();
    if (window.HackPost) await window.HackPost("installDrive", { slot });
  }

  function tierRequiresDiscovery(tierId) {
    const tiers = { store: true };
    return tiers[tierId] === true;
  }

  function hasDiscoveredTier(tierId) {
    const d = data.discoveredRobberyLocs || {};
    const prefix = `${tierId}:`;
    return Object.keys(d).some((k) => k.indexOf(prefix) === 0 && d[k]);
  }

  function filterDiscoverableTargets(targets) {
    return (targets || []).filter((t) => {
      const tierId = t.tierId || t.id;
      if (!tierRequiresDiscovery(tierId)) return true;
      return hasDiscoveredTier(tierId);
    });
  }

  function sortTargetsByLevel(targets) {
    return [...(targets || [])].sort((a, b) => (b.security || 0) - (a.security || 0));
  }

  const MAP_BOUNDS = { minX: -4000, minY: -4000, maxX: 4500, maxY: 6625 };

  function gameToMapPercent(gx, gy) {
    const rangeX = MAP_BOUNDS.maxX - MAP_BOUNDS.minX;
    const rangeY = MAP_BOUNDS.maxY - MAP_BOUNDS.minY;
    let tX = (Number(gx) - MAP_BOUNDS.minX) / rangeX;
    let tY = (Number(gy) - MAP_BOUNDS.minY) / rangeY;
    tX = Math.max(0, Math.min(1, tX));
    tY = Math.max(0, Math.min(1, tY));
    tY = 1 - tY;
    return { leftPct: tX * 100, topPct: tY * 100 };
  }

  function showMapTooltip(tooltip, mapEl, html, clientX, clientY) {
    const rect = mapEl.getBoundingClientRect();
    const x = Math.max(16, Math.min(rect.width - 16, clientX - rect.left));
    const y = Math.max(16, Math.min(rect.height - 16, clientY - rect.top));
    tooltip.innerHTML = html;
    tooltip.classList.remove("hidden");
    tooltip.style.left = `${x}px`;
    tooltip.style.top = `${y}px`;
  }

  function hideMapTooltip(tooltip) {
    tooltip?.classList.add("hidden");
  }

  function renderNetworkMap() {
    const mapEl = $("networkGraph");
    const markersEl = $("networkMapMarkers");
    const tooltip = $("networkMapTooltip");
    const atmNote = $("networkMapAtmNote");
    if (!mapEl || !markersEl || !data) return;

    markersEl.innerHTML = "";
    hideMapTooltip(tooltip);

    if (atmNote) {
      const storeHint = hasDiscoveredTier("store")
        ? ""
        : " Parduotuvių taikinius atskleisk planšete būdamas parduotuvėje.";
      atmNote.textContent = (data.atmMapNote || "Galima apiplėšti bet kurį bankomatą mieste (LVL 1).") + storeHint;
    }

    const sites = data.robberyMapSites || [];
    const tiers = data.robberyTiers || {};

    sites.forEach((site) => {
      const pos = gameToMapPercent(site.x, site.y);
      const dot = document.createElement("button");
      dot.type = "button";
      dot.className = `network-map-marker lvl-${site.level || 1}`;
      dot.style.left = `${pos.leftPct}%`;
      dot.style.top = `${pos.topPct}%`;
      dot.setAttribute("aria-label", site.label || site.id);

      const tierLabel = (tiers[site.tierId] && tiers[site.tierId].label) || site.tierId || "";
      const tipHtml = `<strong>${site.label || site.id}</strong>LVL ${site.level || 1} · ${tierLabel}`;

      dot.addEventListener("mouseenter", () => dot.classList.add("is-hover"));
      dot.addEventListener("mouseleave", () => {
        dot.classList.remove("is-hover");
        hideMapTooltip(tooltip);
      });
      dot.addEventListener("mousemove", (e) => {
        showMapTooltip(tooltip, mapEl, tipHtml, e.clientX, e.clientY);
      });

      markersEl.appendChild(dot);
    });
  }

  function tierSecurityLevel(tierId, tierCfg) {
    if (tierCfg && tierCfg.level) return tierCfg.level;
    const os = tierCfg && tierCfg.minOs;
    if (os && data.osCatalog && data.osCatalog[os] && data.osCatalog[os].level) {
      return data.osCatalog[os].level;
    }
    return 1;
  }

  function marketPriceLabel(price) {
    const cur = data.marketCurrency || "cash";
    if (cur === "crypto") return `${price || 0}₿`;
    return `$${price || 0}`;
  }

  function buildTargetCard(t) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "target-card" + (selectedTarget && selectedTarget.id === t.id ? " selected" : "");
    const dotClass = statusClass(t.status);
    btn.innerHTML = `
      <span class="target-dot ${dotClass}"></span>
      <div>
        <strong>${t.label}</strong>
        <div class="target-meta">Apsaugos lygis ${t.security} · Būsena: ${t.status || "Veikia"}</div>
      </div>
      <span class="target-sec">LVL ${t.security}</span>
    `;
    btn.onclick = () => openTargetPanel(t);
    return btn;
  }

  function renderNetwork() {
    renderNetworkMap();
    const list = $("networkList");
    if (!list) return;
    list.innerHTML = "";
    sortTargetsByLevel(filterDiscoverableTargets(data.networkTargets)).forEach((t) => list.appendChild(buildTargetCard(t)));
  }

  function renderTargets() {
    const list = $("targetsList");
    if (!list) return;
    list.innerHTML = "";
    const tiers = data.robberyTiers || {};
    const entries = Object.keys(tiers).map((k) => {
      const t = tiers[k];
      return {
        id: k,
        label: t.label || k,
        security: tierSecurityLevel(k, t),
        status: "Veikia",
        tierId: k,
      };
    });
    sortTargetsByLevel(filterDiscoverableTargets(entries)).forEach((entry) => list.appendChild(buildTargetCard(entry)));
  }

  function renderExploits() {
    const grid = $("exploitList");
    if (!grid) return;
    grid.innerHTML = "";
    const ex = data.exploits || [];
    if (!ex.length) {
      grid.innerHTML = '<p class="muted">Exploit slotai tušti. Market / flashdrive.</p>';
      return;
    }
    ex.forEach((id, i) => {
      const c = (data.exploitCatalog || {})[id] || {};
      const card = document.createElement("article");
      card.className = "exploit-card";
      card.innerHTML = `
        <h4>${c.label || id}</h4>
        <p class="muted">${c.desc || ""}</p>
        <div class="exploit-badges">
          <span class="badge">LVL ${Math.min(5, i + 2)}</span>
          <span class="badge">USES ∞</span>
          <span class="badge">SLOT ${i + 1}/${data.exploitSlots || 3}</span>
        </div>
      `;
      grid.appendChild(card);
    });
  }

  function renderFiles() {
    const grid = $("filesList");
    if (!grid) return;
    grid.innerHTML = "";
    (data.tabletFiles || []).forEach((f) => {
      const card = document.createElement("article");
      card.className = "file-card" + (f.locked ? " locked" : "");
      card.innerHTML = `<strong>${f.label}</strong><p class="muted small">${f.locked ? "Šifruota — reikia įsilaužti" : "Iššifruota"}</p>`;
      grid.appendChild(card);
    });
  }

  function renderMarket() {
    const grid = $("marketList");
    if (!grid) return;
    grid.innerHTML = "";
    const items = data.marketItems || [];
    const cur = data.marketCurrency || "cash";
    const cashBal = data.playerMoney && data.playerMoney.cash != null ? data.playerMoney.cash : 0;
    const cryptoBal = data.playerMoney && data.playerMoney.crypto != null ? data.playerMoney.crypto : 0;
    const shopLabel = data.marketCurrencyLabel || "Lesteris";
    const head = document.createElement("p");
    head.className = "muted small";
    if (cur === "crypto") {
      head.textContent = `${shopLabel} — balansas: ${cryptoBal}₿ crypto`;
    } else {
      head.textContent = `${shopLabel} — grynieji: $${cashBal} (L1 planšetė / BasicOS)`;
    }
    grid.appendChild(head);
    items.forEach((e, i) => {
      const card = document.createElement("article");
      card.className = "market-card";
      let extra = "";
      if (e.payload && e.payload.payload_id) extra = ` [${e.payload.payload_id}]`;
      const label = e.item || "item";
      card.innerHTML = `
        <strong>${label}</strong>
        <span class="muted small">${marketPriceLabel(e.price)}${extra}</span>
      `;
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "cyber-btn buy-btn";
      btn.textContent = "Pirkti";
      btn.onclick = () => window.HackPost && window.HackPost("marketBuy", { index: i + 1 });
      card.appendChild(btn);
      grid.appendChild(card);
    });
    if (!items.length) grid.innerHTML = '<p class="muted">Parduotuvė tuščia.</p>';
  }

  function renderContracts() {
    const list = $("contractsList");
    if (!list) return;
    list.innerHTML = "";
    (data.tabletContracts || []).forEach((c) => {
      const row = document.createElement("article");
      row.className = "contract-card";
      row.innerHTML = `<div><strong>${c.label}</strong><p class="muted small">Tier: ${c.tierId || "—"}</p></div><span class="contract-reward">$${c.reward || 0}</span>`;
      list.appendChild(row);
    });
  }

  function openTargetPanel(t) {
    selectedTarget = t;
    const panel = $("targetPanel");
    const meta = (data.targetMeta || {})[t.tierId || t.id] || {};
    $("targetTitle").textContent = (t.label || "TAIKINYS").toUpperCase();
    const rewards = meta.rewards || ["Grynieji", "Duomenys"];
    $("targetDetails").innerHTML = `
      <div class="target-detail-block"><span class="tdt">Apsauga</span><span>Lygis ${t.security}</span></div>
      <div class="target-detail-block"><span class="tdt">Šifravimas</span><span>${meta.encryption || "AES-128"}</span></div>
      <div class="target-detail-block"><span class="tdt">Užkarda</span><span>${meta.firewall || "Aktyvuota"}</span></div>
      <div class="target-detail-block"><span class="tdt">Atlygis</span><ul>${rewards.map((r) => `<li>${r}</li>`).join("")}</ul></div>
      <div class="target-detail-block"><span class="tdt">Reikalavimai</span><span>${meta.requirements || "—"}</span></div>
      <div class="target-detail-block"><span class="tdt">Būsena</span><span>${t.status || "Veikia"}</span></div>
    `;
    panel.classList.remove("hidden");
    renderNetwork();
    renderTargets();
  }

  function closeTargetPanel() {
    selectedTarget = null;
    $("targetPanel")?.classList.add("hidden");
    renderNetwork();
    renderTargets();
  }

  function runScan() {
    const overlay = $("scanOverlay");
    if (!overlay) return;
    overlay.classList.remove("hidden");
    setTimeout(() => overlay.classList.add("hidden"), 2200);
  }

  function bindNav() {
    if (navBound) return;
    navBound = true;
    document.querySelectorAll(".nav-item").forEach((btn) => {
      btn.onclick = () => setView(btn.dataset.view);
    });
    $("targetClose")?.addEventListener("click", closeTargetPanel);
    document.querySelectorAll(".target-actions .cyber-btn").forEach((btn) => {
      btn.onclick = () => {
        const act = btn.dataset.act;
        if (act === "exit") return closeTargetPanel();
        if (act === "scan") return runScan();
        if (!selectedTarget) return;
        const tierId = selectedTarget.tierId || selectedTarget.id;
        if (act === "breach" || act === "backdoor") {
          window.HackPost && window.HackPost("networkAction", { action: act, tierId });
        }
      };
    });
    $("setAnim")?.addEventListener("change", (e) => {
      document.getElementById("tablet")?.classList.toggle("no-anim", !e.target.checked);
    });
  }

  function setView(view) {
    currentView = view;
    document.querySelectorAll(".nav-item").forEach((b) => b.classList.toggle("active", b.dataset.view === view));
    document.querySelectorAll(".hackos-view").forEach((v) => v.classList.add("hidden"));
    const el = $("view-" + view);
    if (el) el.classList.remove("hidden");
    if (view === "system") renderSystem();
    if (view === "network") renderNetwork();
    if (view === "targets") renderTargets();
    if (view === "exploits") renderExploits();
    if (view === "files") renderFiles();
    if (view === "market") renderMarket();
    if (view === "contracts") renderContracts();
  }

  function open(payload, opts) {
    data = payload;
    highlightDriveSlot = opts && opts.driveSlot ? Number(opts.driveSlot) : null;
    if (highlightDriveSlot) selectedDriveSlot = highlightDriveSlot;
    renderTopbar();
    bindNav();
    const startView = opts && opts.flashTab === true ? "system" : "network";
    setView(startView);
    if (opts && opts.flashTab) renderDriveList();
  }

  function refresh(payload) {
    if (!payload) return;
    data = { ...data, ...payload };
    renderTopbar();
    setView(currentView);
    renderDriveList();
  }

  return { open, refresh, setView, closeTargetPanel };
})();
