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
};

let lastState = null;
let turfMap = null;
let mapCfg = null;
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

/** FiveM NUI: Leaflet ImageOverlay patikimiau krauna per `https://res/kelias` (ne `nui://`). */
function nuiImageUrl(pathFromHtml) {
  const raw = String(pathFromHtml || "").trim();
  if (!raw || /^https?:\/\//i.test(raw)) return raw;
  const res = resourceName();
  let p = raw.replace(/^\/+/, "");
  if (!p.startsWith("html/")) p = `html/${p}`;
  return `https://${res}/${p}`;
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

function gameToLatLng(gx, gy, cfg) {
  const lng = ((gx - cfg.minX) / (cfg.maxX - cfg.minX)) * cfg.imgW;
  const lat = ((gy - cfg.minY) / (cfg.maxY - cfg.minY)) * cfg.imgH;
  return L.latLng(lat, lng);
}

function gameRadiusToMap(r, cfg) {
  const rr = Number(r) || 150;
  const rx = (rr / (cfg.maxX - cfg.minX)) * cfg.imgW;
  const ry = (rr / (cfg.maxY - cfg.minY)) * cfg.imgH;
  return Math.max(8, (rx + ry) / 2);
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
  if (turfMap) {
    turfMap.remove();
    turfMap = null;
  }
  mapCfg = null;
  mapTooltip.classList.add("hidden");
}

function resetMapView() {
  if (!turfMap || typeof turfMap.resetHome !== "function") return;
  turfMap.resetHome();
}

function scheduleMapInvalidate() {
  [0, 50, 150, 350].forEach((ms) => {
    setTimeout(() => {
      if (turfMap) turfMap.invalidateSize();
    }, ms);
  });
}

function renderTurfsOnMap(state) {
  destroyTurfMap();
  if (typeof L === "undefined") return;

  mapCfg = normalizeMapConfig(state);
  const bounds = [
    [0, 0],
    [mapCfg.imgH, mapCfg.imgW],
  ];
  const el = document.getElementById("leafletMap");
  if (!el) return;

  turfMap = L.map("leafletMap", {
    crs: L.CRS.Simple,
    minZoom: -3,
    maxZoom: 6,
    zoomControl: false,
    attributionControl: false,
    preferCanvas: false,
    worldCopyJump: false,
    dragging: true,
    scrollWheelZoom: true,
    doubleClickZoom: true,
    boxZoom: false,
  });

  L.imageOverlay(mapCfg.imageUrl, bounds, { interactive: true, className: "gangs-satellite-img" }).addTo(turfMap);

  const group = L.layerGroup().addTo(turfMap);
  const turfs = state.turfs || [];

  turfs.forEach((t) => {
    const x = Number(t.center_x);
    const y = Number(t.center_y);
    const r = Number(t.radius) || 150;
    if (!Number.isFinite(x) || !Number.isFinite(y)) return;

    const center = gameToLatLng(x, y, mapCfg);
    const rad = gameRadiusToMap(r, mapCfg);

    const hasOwner = !!(t.owner_name && String(t.owner_name).trim());
    const col = String(t.owner_color_hex || "").trim();
    const label = t.turf_label || t.turf_id;
    const owner = t.owner_name || "Laisva";
    const prog = Math.max(0, Math.min(100, Number(t.progress || 0)));

    const fillHex = col && /^#[0-9A-Fa-f]{6}$/.test(col) ? col : "#a78bfa";
    const circle = L.circle(center, {
      radius: rad,
      stroke: !hasOwner,
      weight: !hasOwner ? 1 : 0,
      color: "rgba(148, 163, 184, 0.5)",
      fillColor: hasOwner ? fillHex : "#1e293b",
      fillOpacity: hasOwner ? 0.38 : 0.1,
      interactive: true,
      bubblingMouseEvents: false,
    }).addTo(group);

    circle.on("click", (e) => {
      L.DomEvent.stopPropagation(e);
      post("gangs:setWaypoint", { turfId: t.turf_id });
    });

    circle.on("mousemove", (e) => {
      mapTooltip.classList.remove("hidden");
      mapTooltip.innerHTML = hasOwner
        ? `<strong>${safe(label)}</strong><br/>${safe(owner)} · ${prog}% užimta`
        : `<strong>${safe(label)}</strong><br/>Laisva · ${prog}% užimta`;
      const stage = document.getElementById("mapStage");
      if (!stage) return;
      const rect = stage.getBoundingClientRect();
      let left = e.originalEvent.clientX - rect.left + 14;
      let top = e.originalEvent.clientY - rect.top + 14;
      if (left + 220 > rect.width) left = rect.width - 230;
      if (top + 56 > rect.height) top = rect.height - 64;
      mapTooltip.style.left = `${Math.max(8, left)}px`;
      mapTooltip.style.top = `${Math.max(8, top)}px`;
    });
    circle.on("mouseout", () => mapTooltip.classList.add("hidden"));
  });

  turfMap.fitBounds(bounds, { padding: [4, 4], animate: false });

  turfMap.resetHome = () => {
    turfMap.fitBounds(bounds, { animate: true, padding: [16, 16] });
  };

  turfMap.whenReady(() => {
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        scheduleMapInvalidate();
      });
    });
  });
}

/** Leaflet kuriamas tik kai skydelis jau matomas (ne 0×0 dėžutė). */
function scheduleRenderMap(state) {
  destroyTurfMap();
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      if (!lastState || activeTab !== "map") return;
      renderTurfsOnMap(state || lastState);
      scheduleMapInvalidate();
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

function updateGangTabContent(state) {
  if (state.hasGang) {
    gangPanelEmpty.classList.add("hidden");
    gangPanelContent.classList.remove("hidden");
    gangTitle.textContent = `${state.gang.name} (${state.gang.gang_type})`;
    gangMeta.textContent = `Rep: ${state.gang.reputation || 0} · Heat: ${state.gang.heat || 0} · ${state.gang.color_hex || "-"} / ${state.gang.secondary_color_hex || "-"}`;
  } else {
    gangPanelContent.classList.add("hidden");
    gangPanelEmpty.classList.remove("hidden");
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

  if (activeTab === "gang" && !state.hasGang) activeTab = "register";

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
    render(payload);
  }
  if (d.action === "close") {
    destroyTurfMap();
    tablet.classList.add("hidden");
    activeTab = "register";
  }
});

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
  if (turfMap) turfMap.zoomIn(0.35);
};
document.getElementById("zoomOut").onclick = () => {
  if (turfMap) turfMap.zoomOut(0.35);
};
document.getElementById("tabletHomeBtn").onclick = () => resetMapView();

window.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !tablet.classList.contains("hidden")) {
    e.preventDefault();
    post("gangs:close", {});
  }
});
