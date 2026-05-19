const tablet = document.getElementById("tablet");
const gangTitle = document.getElementById("gangTitle");
const gangMeta = document.getElementById("gangMeta");
const gangPanelEmpty = document.getElementById("gangPanelEmpty");
const gangPanelContent = document.getElementById("gangPanelContent");
const gangName = document.getElementById("gangName");
const gangType = document.getElementById("gangType");
const primaryColor = document.getElementById("primaryColor");
const secondaryColor = document.getElementById("secondaryColor");
const colorWarn = document.getElementById("colorWarn");
const mapTooltip = document.getElementById("mapTooltip");
const primarySwatches = document.getElementById("primarySwatches");
const secondarySwatches = document.getElementById("secondarySwatches");

const tabPanels = {
  register: document.getElementById("tabPanelRegister"),
  gang: document.getElementById("tabPanelGang"),
  map: document.getElementById("tabPanelMap"),
  missions: document.getElementById("tabPanelMissions"),
};
const missionTurfSelect = document.getElementById("missionTurfSelect");
const missionTypeSelect = document.getElementById("missionTypeSelect");
const claimThresholdLbl = document.getElementById("claimThresholdLbl");
const tabMissions = document.getElementById("tabMissions");

let lastState = null;
let mapCfg = null;
const GANG_MAP_IMG_W = 1066;
const GANG_MAP_IMG_H = 861;
let gangsMapPan = { x: 0, y: 0, scale: 1 };
let gangsMapInteractBound = false;
let gangsMapResizeObs = null;
let tabletDocked = false;
let tabletDragBound = false;
const tabletBezel = document.querySelector(".tablet-bezel");
/** @type {'register' | 'gang' | 'map'} */
let activeTab = "register";

function resourceName() {
  try {
    if (typeof GetParentResourceName === "function") return GetParentResourceName();
  } catch (e) {}
  return "fivempro_gangs";
}

function post(endpoint, data) {
  return fetch(`https://${resourceName()}/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data || {}),
  }).then((r) => r.json());
}

function safe(s) {
  const d = document.createElement("div");
  d.textContent = s == null ? "" : String(s);
  return d.innerHTML;
}

/** FiveM NUI: pilnas žemėlapio JPG per `nui://` (CSS background, kaip LTPD MDT). */
function nuiImageUrl(pathFromHtml) {
  const raw = String(pathFromHtml || "").trim();
  if (!raw || /^https?:\/\//i.test(raw) || /^nui:\/\//i.test(raw)) return raw;
  const res = resourceName();
  let p = raw.replace(/^\/+/, "");
  if (!p.startsWith("html/")) p = `html/${p}`;
  return `nui://${res}/${p}`;
}

function normalizeMapConfig(payload) {
  const t = payload.tabletMap || {};
  const file = t.imageFile || "asset/gtav_satellite.jpg";
  return {
    minX: Number(t.gameMin?.x ?? -4000),
    minY: Number(t.gameMin?.y ?? -4000),
    maxX: Number(t.gameMax?.x ?? 4500),
    maxY: Number(t.gameMax?.y ?? 8000),
    imgW: Number(t.imageWidth) || 1066,
    imgH: Number(t.imageHeight) || 861,
    imageUrl: nuiImageUrl(file),
  };
}

function gameToMapPercent(gx, gy, cfg) {
  const px = ((Number(gx) - cfg.minX) / (cfg.maxX - cfg.minX)) * 100;
  const py = (1 - (Number(gy) - cfg.minY) / (cfg.maxY - cfg.minY)) * 100;
  return {
    x: Math.max(0.5, Math.min(99.5, px)),
    y: Math.max(0.5, Math.min(99.5, py)),
  };
}

function gameRadiusToPercent(r, cfg) {
  const rr = Number(r) || 150;
  const w = ((rr * 2) / (cfg.maxX - cfg.minX)) * 100;
  const h = ((rr * 2) / (cfg.maxY - cfg.minY)) * 100;
  return {
    w: Math.max(2.5, Math.min(42, w)),
    h: Math.max(2.5, Math.min(42, h)),
  };
}

function hexToRgba(hex, alpha) {
  const h = String(hex || "").replace("#", "");
  if (h.length !== 6) return `rgba(167, 139, 250, ${alpha})`;
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  if ([r, g, b].some((n) => Number.isNaN(n))) return `rgba(167, 139, 250, ${alpha})`;
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

function destroyTurfMap() {
  const surface = document.getElementById("gangsMapSurface");
  if (surface) surface.remove();
  mapCfg = null;
  gangsMapPan = { x: 0, y: 0, scale: 1 };
  applyGangsMapTransform();
  mapTooltip.classList.add("hidden");
}

function ensureGangsMapDom(imageUrl) {
  const transform = document.getElementById("gangsMapTransform");
  if (!transform || document.getElementById("gangsMapSurface")) return;

  let markers = document.getElementById("gangsMapMarkers");
  const inner = document.getElementById("gangsMapInner");
  const surface = document.createElement("div");
  surface.id = "gangsMapSurface";
  surface.className = "gangs-map-surface";
  const url = imageUrl || (mapCfg && mapCfg.imageUrl) || "";
  if (url) surface.style.backgroundImage = `url("${url}")`;

  if (inner) inner.remove();
  if (!markers) {
    markers = document.createElement("div");
    markers.id = "gangsMapMarkers";
    markers.className = "gangs-map-markers";
  } else {
    markers.remove();
  }

  surface.appendChild(markers);
  transform.appendChild(surface);
}

function layoutGangsMapCanvas() {
  const root = document.getElementById("gangsMap");
  const surface = document.getElementById("gangsMapSurface");
  if (!root || !surface) return;

  const cw = Math.max(320, root.clientWidth || 0);
  const ch = Math.max(240, root.clientHeight || 0);
  const fit = Math.min(cw / GANG_MAP_IMG_W, ch / GANG_MAP_IMG_H);
  const panPad = 1.65;
  const px = Math.max(fit * panPad, 0.35);
  surface.style.width = `${Math.round(GANG_MAP_IMG_W * px)}px`;
  surface.style.height = `${Math.round(GANG_MAP_IMG_H * px)}px`;
}

function fitGangsMapInView() {
  const root = document.getElementById("gangsMap");
  const surface = document.getElementById("gangsMapSurface");
  if (!root || !surface) return;
  layoutGangsMapCanvas();
  const cw = Math.max(1, root.clientWidth);
  const ch = Math.max(1, root.clientHeight);
  const sw = surface.offsetWidth || GANG_MAP_IMG_W;
  const sh = surface.offsetHeight || GANG_MAP_IMG_H;
  gangsMapPan.scale = Math.min(1, cw / sw, ch / sh);
  gangsMapPan.x = 0;
  gangsMapPan.y = 0;
  applyGangsMapTransform();
}

function watchGangsMapResize() {
  const root = document.getElementById("gangsMap");
  if (!root || gangsMapResizeObs) return;
  gangsMapResizeObs = new ResizeObserver(() => {
    if (activeTab !== "map") return;
    layoutGangsMapCanvas();
    applyGangsMapTransform();
  });
  gangsMapResizeObs.observe(root);
}

function applyGangsMapTransform() {
  const layer = document.getElementById("gangsMapTransform");
  if (!layer) return;
  layer.style.transform = `translate(calc(-50% + ${gangsMapPan.x}px), calc(-50% + ${gangsMapPan.y}px)) scale(${gangsMapPan.scale})`;
}

function bindGangsMapInteract() {
  if (gangsMapInteractBound) return;
  const root = document.getElementById("gangsMap");
  if (!root) return;
  gangsMapInteractBound = true;

  root.addEventListener(
    "wheel",
    (e) => {
      e.preventDefault();
      const delta = e.deltaY > 0 ? -0.12 : 0.12;
      gangsMapPan.scale = Math.max(0.45, Math.min(3.4, gangsMapPan.scale + delta));
      applyGangsMapTransform();
    },
    { passive: false },
  );

  let drag = false;
  let lx = 0;
  let ly = 0;
  root.addEventListener("mousedown", (e) => {
    if (e.button !== 0) return;
    drag = true;
    lx = e.clientX;
    ly = e.clientY;
    root.style.cursor = "grabbing";
  });
  window.addEventListener("mouseup", () => {
    if (!drag) return;
    drag = false;
    if (root) root.style.cursor = "grab";
  });
  window.addEventListener("mousemove", (e) => {
    if (!drag) return;
    gangsMapPan.x += e.clientX - lx;
    gangsMapPan.y += e.clientY - ly;
    lx = e.clientX;
    ly = e.clientY;
    applyGangsMapTransform();
  });
}

function resetMapView() {
  fitGangsMapInView();
}

function renderTurfsOnMap(state) {
  mapCfg = normalizeMapConfig(state);
  ensureGangsMapDom(mapCfg.imageUrl);
  watchGangsMapResize();
  layoutGangsMapCanvas();

  const markers = document.getElementById("gangsMapMarkers");
  if (!markers) return;

  markers.innerHTML = "";
  bindGangsMapInteract();
  requestAnimationFrame(() => fitGangsMapInView());

  (state.turfs || []).forEach((t) => {
    const x = Number(t.center_x);
    const y = Number(t.center_y);
    const r = Number(t.radius) || 150;
    if (!Number.isFinite(x) || !Number.isFinite(y)) return;

    const center = gameToMapPercent(x, y, mapCfg);
    const size = gameRadiusToPercent(r, mapCfg);

    const hasOwner = !!(t.owner_name && String(t.owner_name).trim());
    const col = String(t.owner_color_hex || "").trim();
    const label = t.turf_label || t.turf_id;
    const owner = t.owner_name || "Laisva";
    const prog = Math.max(0, Math.min(100, Number(t.progress || 0)));
    const status = String(t.status || (hasOwner ? "užimtas" : "neužimtas"));
    const disputed = /ginč|ginčij/i.test(status);
    const fillHex = col && /^#[0-9A-Fa-f]{6}$/.test(col) ? col : "#a78bfa";

    const zone = document.createElement("button");
    zone.type = "button";
    zone.className = "turf-zone" + (disputed ? " is-disputed" : "") + (hasOwner ? "" : " is-free");
    zone.style.left = `${center.x}%`;
    zone.style.top = `${center.y}%`;
    zone.style.width = `${size.w}%`;
    zone.style.height = `${size.h}%`;
    zone.style.borderColor = disputed ? "rgba(250,204,21,0.9)" : hasOwner ? hexToRgba(fillHex, 0.72) : "rgba(148,163,184,0.55)";
    zone.style.backgroundColor = hasOwner ? hexToRgba(fillHex, 0.38) : "rgba(51, 65, 85, 0.28)";

    zone.addEventListener("click", (e) => {
      e.stopPropagation();
      post("gangs:setWaypoint", { turfId: t.turf_id }).then(() => {
        setTabletDocked(true);
      });
    });
    zone.addEventListener("mousemove", (e) => {
      mapTooltip.classList.remove("hidden");
      const thresh = Number(lastState?.claimThreshold || 100);
      mapTooltip.innerHTML = hasOwner
        ? `<strong>${safe(label)}</strong><br/>${safe(owner)} · ${safe(status)}<br/>Užėmimas: ${prog}/${thresh}`
        : `<strong>${safe(label)}</strong><br/>Laisva · ${safe(status)}<br/>Užėmimas: ${prog}/${thresh}`;
      const stage = document.getElementById("mapStage");
      if (!stage) return;
      const rect = stage.getBoundingClientRect();
      let left = e.clientX - rect.left + 14;
      let top = e.clientY - rect.top + 14;
      if (left + 220 > rect.width) left = rect.width - 230;
      if (top + 56 > rect.height) top = rect.height - 64;
      mapTooltip.style.left = `${Math.max(8, left)}px`;
      mapTooltip.style.top = `${Math.max(8, top)}px`;
    });
    zone.addEventListener("mouseleave", () => mapTooltip.classList.add("hidden"));

    markers.appendChild(zone);
  });

}

/** Žemėlapis kuriamas tik kai skiltis matoma (pilnas panel plotis / aukštis). */
function scheduleRenderMap(state) {
  destroyTurfMap();
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      if (!lastState || activeTab !== "map") return;
      renderTurfsOnMap(state || lastState);
    });
  });
}

function hexKey(hex) {
  return String(hex || "").trim().toUpperCase();
}

function syncSwatchSelection(selectEl, containerEl) {
  if (!containerEl) return;
  const cur = hexKey(selectEl.value);
  containerEl.querySelectorAll(".color-swatch").forEach((b) => {
    b.classList.toggle("active", hexKey(b.dataset.hex) === cur);
  });
}

/** Vizualūs kvadratėliai; `<select>` lieka logikai (value / create). */
function renderColorSwatches(selectEl, containerEl, palette, usage) {
  if (!containerEl || !selectEl) return;
  containerEl.innerHTML = "";
  const opts = palette || [];
  opts.forEach((hex) => {
    const used = Number((usage || {})[String(hex).toUpperCase()] || 0);
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "color-swatch";
    if (used > 0) btn.classList.add("is-used");
    btn.style.backgroundColor = hex;
    btn.dataset.hex = hex;
    btn.title = used > 0 ? `${hex} — jau naudojama` : String(hex);
    btn.addEventListener("click", () => {
      selectEl.value = hex;
      syncSwatchSelection(selectEl, containerEl);
      selectEl.dispatchEvent(new Event("change", { bubbles: true }));
    });
    containerEl.appendChild(btn);
  });

  const valid = opts.some((h) => hexKey(h) === hexKey(selectEl.value));
  if (!valid && opts.length) selectEl.value = opts[0];
  syncSwatchSelection(selectEl, containerEl);
}

function renderPalette(palette, usage) {
  primaryColor.innerHTML = "";
  secondaryColor.innerHTML = "";
  (palette || []).forEach((hex) => {
    const used = Number((usage || {})[String(hex).toUpperCase()] || 0);
    const txt = used > 0 ? `${hex} (used ${used})` : hex;
    const o1 = document.createElement("option");
    o1.value = hex;
    o1.textContent = txt;
    primaryColor.appendChild(o1);
    const o2 = document.createElement("option");
    o2.value = hex;
    o2.textContent = txt;
    secondaryColor.appendChild(o2);
  });
  renderColorSwatches(primaryColor, primarySwatches, palette, usage);
  renderColorSwatches(secondaryColor, secondarySwatches, palette, usage);
}

function mergeTabletMap(res) {
  if (!res || !res.ok) return res;
  if (!res.tabletMap && lastState && lastState.tabletMap) res.tabletMap = lastState.tabletMap;
  return res;
}

function renderMissionsTab(state) {
  if (!missionTurfSelect || !missionTypeSelect) return;
  const myGangId = state.hasGang && state.gang ? Number(state.gang.gang_id) : 0;
  missionTurfSelect.innerHTML = "";
  (state.turfs || []).forEach((t) => {
    const ownerId = Number(t.owner_gang_id || 0);
    if (ownerId === myGangId) return;
    const o = document.createElement("option");
    o.value = t.turf_id;
    const prog = Number(t.progress || 0);
    o.textContent = `${t.turf_label || t.turf_id} (${prog}%)`;
    missionTurfSelect.appendChild(o);
  });
  missionTypeSelect.innerHTML = "";
  (state.missions || []).forEach((m) => {
    const o = document.createElement("option");
    o.value = m.id;
    o.textContent = `${m.label} (+${m.progress})`;
    missionTypeSelect.appendChild(o);
  });
  if (claimThresholdLbl) claimThresholdLbl.textContent = String(state.claimThreshold || 100);
  if (tabMissions) tabMissions.style.display = state.hasGang ? "" : "none";
}

function updateGangTabContent(state) {
  const memberListEl = document.getElementById("gangMemberList");
  if (state.hasGang) {
    gangPanelEmpty.classList.add("hidden");
    gangPanelContent.classList.remove("hidden");
    gangTitle.textContent = `${state.gang.name} (${state.gang.gang_type})`;
    gangMeta.textContent = `Rep: ${state.gang.reputation || 0} · Heat: ${state.gang.heat || 0} · ${state.gang.color_hex || "-"} / ${state.gang.secondary_color_hex || "-"}`;
    const rows = state.members || [];
    memberListEl.innerHTML = rows.length
      ? rows
          .map(
            (m) =>
              `<div class="gang-member-row"><span>${safe(m.name || "Narys")}</span><span>${safe(m.citizenid || "-")}</span><strong>R${safe(m.rank || 0)}</strong></div>`,
          )
          .join("")
      : `<div class="gang-member-row"><span>Narių nėra</span><span>-</span><strong>-</strong></div>`;
  } else {
    gangPanelContent.classList.add("hidden");
    gangPanelEmpty.classList.remove("hidden");
    memberListEl.innerHTML = "";
  }
}

function activateTab(tab) {
  if (tab === "gang" && !lastState?.hasGang) tab = "register";
  activeTab = tab;

  document.querySelectorAll(".tab-btn").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.tab === tab);
  });

  Object.entries(tabPanels).forEach(([k, el]) => {
    el.classList.toggle("hidden", k !== tab);
  });

  if (tab === "map") {
    scheduleRenderMap(lastState);
  } else {
    destroyTurfMap();
  }
}

document.querySelectorAll(".tab-btn").forEach((btn) => {
  btn.addEventListener("click", () => activateTab(btn.dataset.tab));
});

function render(state) {
  lastState = state;
  tablet.classList.remove("hidden");

  gangType.innerHTML = "";
  Object.entries(state.gangTypes || {}).forEach(([k, v]) => {
    const o = document.createElement("option");
    o.value = k;
    o.textContent = `${v}`;
    gangType.appendChild(o);
  });
  renderPalette(state.palette || [], state.colorUsage || {});
  updateGangTabContent(state);
  renderMissionsTab(state);

  if (activeTab === "gang" && !state.hasGang) activeTab = "register";
  if (activeTab === "missions" && !state.hasGang) activeTab = "register";

  activateTab(activeTab);
}

function refreshWarn() {
  if (!lastState) return;
  const usage = lastState.colorUsage || {};
  const used = Number(usage[String(primaryColor.value || "").toUpperCase()] || 0) > 0;
  colorWarn.classList.toggle("hidden", !used);
  colorWarn.textContent = used ? `Spalva ${primaryColor.value} jau naudojama — vis tiek gali rinktis.` : "";
}
primaryColor.addEventListener("change", refreshWarn);

window.addEventListener("message", (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === "open") {
    const payload = d.payload || {};
    activeTab = payload.hasGang ? "map" : "register";
    setTabletDocked(false, true);
    render(payload);
  }
  if (d.action === "dock") {
    setTabletDocked(true, true);
  }
  if (d.action === "undock") {
    setTabletDocked(false, true);
  }
  if (d.action === "close") {
    destroyTurfMap();
    tablet.classList.add("hidden");
    activeTab = "register";
  }
});

function setTabletDocked(docked, skipPost) {
  tabletDocked = !!docked;
  tablet.classList.toggle("is-docked", tabletDocked);
  const btn = document.getElementById("btnDock");
  if (btn) btn.textContent = tabletDocked ? "⊞ Visas" : "⊟ Kampas";
  if (!skipPost) post("gangs:setDocked", { docked: tabletDocked });
  if (!tabletDocked && tabletBezel) {
    tabletBezel.style.left = "";
    tabletBezel.style.top = "";
    tabletBezel.style.right = "";
    tabletBezel.style.bottom = "";
  }
  if (activeTab === "map") {
    requestAnimationFrame(() => fitGangsMapInView());
  }
}

function bindTabletDrag() {
  if (tabletDragBound) return;
  tabletDragBound = true;
  const head = document.querySelector(".tablet-head");
  if (!head || !tabletBezel) return;
  let drag = false;
  let sx = 0;
  let sy = 0;
  let sl = 0;
  let st = 0;
  head.addEventListener("mousedown", (e) => {
    if (!tabletDocked || e.target.closest("button")) return;
    drag = true;
    const r = tabletBezel.getBoundingClientRect();
    sx = e.clientX;
    sy = e.clientY;
    sl = r.left;
    st = r.top;
    e.preventDefault();
  });
  window.addEventListener("mouseup", () => {
    drag = false;
  });
  window.addEventListener("mousemove", (e) => {
    if (!drag || !tabletDocked) return;
    tabletBezel.style.left = `${sl + e.clientX - sx}px`;
    tabletBezel.style.top = `${st + e.clientY - sy}px`;
    tabletBezel.style.right = "auto";
    tabletBezel.style.bottom = "auto";
  });
}

const btnDockGang = document.getElementById("btnDock");
if (btnDockGang) {
  btnDockGang.onclick = () => setTabletDocked(!tabletDocked);
}
bindTabletDrag();

document.getElementById("btnClose").onclick = () => post("gangs:close", {});
document.getElementById("btnRefresh").onclick = () =>
  post("gangs:refresh", {}).then((res) => {
    mergeTabletMap(res);
    if (res && res.ok) render(res);
  });

document.getElementById("btnCreate").onclick = () => {
  const payload = {
    name: gangName.value.trim(),
    gangType: gangType.value,
    colorHex: primaryColor.value,
    secondaryColorHex: secondaryColor.value,
  };
  post("gangs:createGang", payload).then(() =>
    post("gangs:refresh", {}).then((res) => {
      mergeTabletMap(res);
      if (res && res.ok) {
        activeTab = "gang";
        render(res);
      }
    }),
  );
};

document.getElementById("zoomIn").onclick = () => {
  gangsMapPan.scale = Math.min(3.4, gangsMapPan.scale + 0.15);
  applyGangsMapTransform();
};
document.getElementById("zoomOut").onclick = () => {
  gangsMapPan.scale = Math.max(0.45, gangsMapPan.scale - 0.15);
  applyGangsMapTransform();
};
document.getElementById("tabletHomeBtn").onclick = () => resetMapView();
document.getElementById("btnInviteMember").onclick = () => {
  post("gangs:inviteMember", { targetId: Number(document.getElementById("memberTargetId").value) || 0 }).then(() => {
    post("gangs:refresh", {}).then((res) => res && res.ok && render(mergeTabletMap(res)));
  });
};
document.getElementById("btnSetRank").onclick = () => {
  post("gangs:setMemberRank", {
    citizenid: document.getElementById("memberCitizenId").value.trim(),
    rank: Number(document.getElementById("memberRank").value) || 0,
  }).then(() => {
    post("gangs:refresh", {}).then((res) => res && res.ok && render(mergeTabletMap(res)));
  });
};
document.getElementById("btnKickMember").onclick = () => {
  post("gangs:kickMember", { citizenid: document.getElementById("memberCitizenId").value.trim() }).then(() => {
    post("gangs:refresh", {}).then((res) => res && res.ok && render(mergeTabletMap(res)));
  });
};

const btnStartMission = document.getElementById("btnStartMission");
if (btnStartMission) {
  btnStartMission.onclick = () => {
    const turfId = missionTurfSelect?.value;
    const missionType = missionTypeSelect?.value;
    if (!turfId || !missionType) return;
    post("gangs:startMission", { turfId, missionType });
  };
}

window.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !tablet.classList.contains("hidden")) {
    e.preventDefault();
    post("gangs:close", {});
  }
});
