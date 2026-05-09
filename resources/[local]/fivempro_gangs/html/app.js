const tablet = document.getElementById("tablet");
const registerPanel = document.getElementById("registerPanel");
const gangPanel = document.getElementById("gangPanel");
const gangTitle = document.getElementById("gangTitle");
const gangMeta = document.getElementById("gangMeta");
const gangName = document.getElementById("gangName");
const gangType = document.getElementById("gangType");
const primaryColor = document.getElementById("primaryColor");
const secondaryColor = document.getElementById("secondaryColor");
const colorWarn = document.getElementById("colorWarn");
const mapTooltip = document.getElementById("mapTooltip");

let lastState = null;
let turfMap = null;
let mapCfg = null;

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

function normalizeMapConfig(payload) {
  const t = payload.tabletMap || {};
  return {
    minX: Number(t.gameMin?.x ?? -4000),
    minY: Number(t.gameMin?.y ?? -4000),
    maxX: Number(t.gameMax?.x ?? 4500),
    maxY: Number(t.gameMax?.y ?? 8000),
    imgW: Number(t.imageWidth) || 1066,
    imgH: Number(t.imageHeight) || 861,
    imageUrl: String(t.imageFile || "asset/gtav_satellite.jpg"),
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
    minZoom: -2,
    maxZoom: 6,
    zoomControl: false,
    attributionControl: false,
    preferCanvas: true,
  });

  L.imageOverlay(mapCfg.imageUrl, bounds).addTo(turfMap);
  turfMap.setMaxBounds(bounds);

  const group = L.layerGroup().addTo(turfMap);
  const turfs = state.turfs || [];
  const latLngs = [];

  turfs.forEach((t) => {
    const x = Number(t.center_x);
    const y = Number(t.center_y);
    const r = Number(t.radius) || 150;
    if (!Number.isFinite(x) || !Number.isFinite(y)) return;

    const center = gameToLatLng(x, y, mapCfg);
    const rad = gameRadiusToMap(r, mapCfg);
    latLngs.push(center);

    const hasOwner = !!(t.owner_name && String(t.owner_name).trim());
    const col = String(t.owner_color_hex || "").trim();
    const fill = hasOwner && col ? hexToRgba(col, 0.35) : "rgba(167, 139, 250, 0.12)";
    const stroke = hasOwner && col ? hexToRgba(col, 0.8) : "rgba(196, 181, 253, 0.45)";

    const circle = L.circle(center, {
      radius: rad,
      color: stroke,
      weight: 2,
      fillColor: fill,
      fillOpacity: 1,
    }).addTo(group);

    const label = t.turf_label || t.turf_id;
    const owner = t.owner_name || "Laisva";
    const prog = Number(t.progress || 0);

    circle.on("click", (e) => {
      L.DomEvent.stopPropagation(e);
      post("gangs:setWaypoint", { turfId: t.turf_id });
    });

    circle.on("mousemove", (e) => {
      mapTooltip.classList.remove("hidden");
      mapTooltip.innerHTML = `<strong>${safe(label)}</strong>${safe(owner)} · ${prog}% užimta`;
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

  turfMap.fitBounds(bounds);

  turfMap.resetHome = () => {
    if (latLngs.length === 0) {
      turfMap.fitBounds(bounds, { animate: true, padding: [8, 8] });
      return;
    }
    const b = L.latLngBounds(latLngs);
    turfMap.fitBounds(b.pad(0.15), { animate: true, padding: [12, 12] });
  };

  turfMap.whenReady(() => {
    requestAnimationFrame(() => turfMap && turfMap.invalidateSize());
    setTimeout(() => turfMap && turfMap.invalidateSize(), 80);
  });
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
}

function mergeTabletMap(res) {
  if (!res || !res.ok) return res;
  if (!res.tabletMap && lastState && lastState.tabletMap) res.tabletMap = lastState.tabletMap;
  return res;
}

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
  renderTurfsOnMap(state);
  if (!state.hasGang) {
    registerPanel.classList.remove("hidden");
    gangPanel.classList.add("hidden");
  } else {
    registerPanel.classList.add("hidden");
    gangPanel.classList.remove("hidden");
    gangTitle.textContent = `${state.gang.name} (${state.gang.gang_type})`;
    gangMeta.textContent = `Rep: ${state.gang.reputation || 0} · Heat: ${state.gang.heat || 0} · ${state.gang.color_hex || "-"} / ${state.gang.secondary_color_hex || "-"}`;
  }
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
  if (d.action === "open") render(d.payload || {});
  if (d.action === "close") {
    destroyTurfMap();
    tablet.classList.add("hidden");
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
      if (res && res.ok) render(res);
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
