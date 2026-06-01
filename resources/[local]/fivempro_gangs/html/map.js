/** Gang Turf žemėlapis — premium territory overlay (Leaflet). */
window.GangMap = (function () {
  const NEUTRAL_COLOR = "#64748B";

  const OP = {
    neutral: { fill: 0.18, stroke: 0.14, weight: 0.45 },
    owned: { fill: 0.22, stroke: 0.16, weight: 0.5 },
    contested: { fill: 0.24, stroke: 0.2, weight: 0.55 },
    hover: { fill: 0.5, stroke: 0.45, weight: 0.75 },
    selected: { fill: 0.7, stroke: 0.55, weight: 0.9 },
  };

  let leafletMap = null;
  let turfLayer = null;
  let imageLayer = null;
  let mapCfg = null;
  let lastState = null;
  let selectedTurf = null;
  let hoveredId = null;
  let tooltipEl = null;
  let turfById = {};
  let layerById = {};
  let mapEventsBound = false;
  let baseFitZoom = 0;
  let turfBoundsLatLng = null;

  function resourceName() {
    try {
      if (typeof GetParentResourceName === "function") return GetParentResourceName();
    } catch (e) {}
    return "fivempro_gangs";
  }

  function nuiImageUrl(pathFromHtml) {
    const raw = String(pathFromHtml || "").trim();
    if (!raw || /^https?:\/\//i.test(raw) || /^nui:\/\//i.test(raw)) return raw;
    const res = resourceName();
    let p = raw.replace(/^\/+/, "");
    if (!p.startsWith("html/")) p = `html/${p}`;
    return `nui://${res}/${p}`;
  }

  function normalizeMapConfig(payload) {
    const t = (payload && payload.tabletMap) || payload || {};
    const file = t.imageFile || "asset/gtav_satellite.jpg";
    const minX = Number(t.gameMin?.x ?? -4000);
    const minY = Number(t.gameMin?.y ?? -4000);
    const maxX = Number(t.gameMax?.x ?? 4500);
    const maxY = Number(t.gameMax?.y ?? 6625);
    return {
      minX,
      minY,
      maxX,
      maxY,
      viewMinX: Number(t.viewMin?.x ?? minX),
      viewMinY: Number(t.viewMin?.y ?? minY),
      viewMaxX: Number(t.viewMax?.x ?? maxX),
      viewMaxY: Number(t.viewMax?.y ?? maxY),
      offsetX: Number(t.offsetX) || 0,
      offsetY: Number(t.offsetY) || 0,
      imgW: Number(t.imageWidth) || 1024,
      imgH: Number(t.imageHeight) || 1280,
      imageUrl: nuiImageUrl(file),
    };
  }

  function viewBoundsLatLng(cfg) {
    if (!cfg) return null;
    return L.latLngBounds(
      [cfg.viewMinY + cfg.offsetY, cfg.viewMinX + cfg.offsetX],
      [cfg.viewMaxY + cfg.offsetY, cfg.viewMaxX + cfg.offsetX]
    );
  }

  /** GTA bounding box → Leaflet [[minY,minX],[maxY,maxX]] */
  function gameBoundsToLeaflet(turf, cfg, padRatio) {
    let minX = Number(turf.min_x);
    let minY = Number(turf.min_y);
    let maxX = Number(turf.max_x);
    let maxY = Number(turf.max_y);
    if (!Number.isFinite(minX) || !Number.isFinite(minY)) {
      const cx = Number(turf.center_x) || 0;
      const cy = Number(turf.center_y) || 0;
      const r = Number(turf.radius) || 80;
      minX = cx - r;
      minY = cy - r;
      maxX = cx + r;
      maxY = cy + r;
    }
    if (padRatio && padRatio > 0) {
      const w = maxX - minX;
      const h = maxY - minY;
      const px = w * padRatio;
      const py = h * padRatio;
      minX -= px;
      minY -= py;
      maxX += px;
      maxY += py;
    }
    const ox = cfg.offsetX || 0;
    const oy = cfg.offsetY || 0;
    return [
      [minY + oy, minX + ox],
      [maxY + oy, maxX + ox],
    ];
  }

  function turfArea(turf) {
    const minX = Number(turf.min_x);
    const minY = Number(turf.min_y);
    const maxX = Number(turf.max_x);
    const maxY = Number(turf.max_y);
    if (!Number.isFinite(minX)) {
      const r = Number(turf.radius) || 80;
      return r * r * 4;
    }
    return Math.max(1, (maxX - minX) * (maxY - minY));
  }

  function turfBaseKind(turf) {
    const ownerId = Number(turf.owner_gang_id) || 0;
    if (turf.is_war) return "contested";
    if (ownerId > 0) return "owned";
    return "neutral";
  }

  function turfFillColor(turf) {
    return turf.map_color || NEUTRAL_COLOR;
  }

  function turfStrokeColor(turf, mode) {
    if (mode === "selected") return "rgba(196, 181, 253, 0.85)";
    if (mode === "hover") return "rgba(248, 250, 252, 0.75)";
    if (turf.is_war) return "rgba(248, 113, 113, 0.65)";
    if (turfBaseKind(turf) === "owned") return turfFillColor(turf);
    return "rgba(100, 116, 139, 0.55)";
  }

  function layerVisualMode(turfId) {
    if (selectedTurf && selectedTurf.turf_id === turfId) return "selected";
    if (hoveredId === turfId) return "hover";
    return "base";
  }

  function buildLayerStyle(turf, mode) {
    const kind = turfBaseKind(turf);
    const baseOp = OP[kind] || OP.neutral;
    const fillColor = turfFillColor(turf);
    let fillOpacity = baseOp.fill;
    let strokeOpacity = baseOp.stroke;
    let weight = baseOp.weight;

    if (mode === "hover") {
      fillOpacity = OP.hover.fill;
      strokeOpacity = OP.hover.stroke;
      weight = OP.hover.weight;
    } else if (mode === "selected") {
      fillOpacity = OP.selected.fill;
      strokeOpacity = OP.selected.stroke;
      weight = OP.selected.weight;
    }

    return {
      color: turfStrokeColor(turf, mode),
      weight,
      opacity: strokeOpacity,
      fillColor,
      fillOpacity,
      dashArray: mode === "base" && turf.is_war ? "4 5" : null,
      className:
        mode === "base" && turf.is_war
          ? "turf-cell-war"
          : mode === "selected"
            ? "turf-cell-selected"
            : "",
    };
  }

  function applyLayerStyle(turfId) {
    const layer = layerById[turfId];
    const turf = turfById[turfId];
    if (!layer || !turf) return;
    layer.setStyle(buildLayerStyle(turf, layerVisualMode(turfId)));
  }

  function refreshAllLayerStyles() {
    Object.keys(layerById).forEach((id) => applyLayerStyle(id));
  }

  function destroy() {
    hideTooltip();
    if (leafletMap) {
      leafletMap.remove();
      leafletMap = null;
    }
    turfLayer = null;
    imageLayer = null;
    selectedTurf = null;
    hoveredId = null;
    turfById = {};
    layerById = {};
    mapEventsBound = false;
    turfBoundsLatLng = null;
  }

  function ensureTooltip() {
    if (tooltipEl) return tooltipEl;
    tooltipEl = document.createElement("div");
    tooltipEl.className = "turf-map-tooltip";
    tooltipEl.setAttribute("role", "tooltip");
    document.body.appendChild(tooltipEl);
    return tooltipEl;
  }

  function hideTooltip() {
    if (tooltipEl) tooltipEl.classList.remove("is-visible");
  }

  function showTooltip(turf, cellNum, clientX, clientY) {
    const el = ensureTooltip();
    const inf = Math.max(0, Math.min(100, Number(turf.influence ?? turf.progress ?? 0)));
    const graffitiCount = Number(turf.graffiti_count ?? Math.floor(inf / 5));
    const graffitiMax = Number(turf.graffiti_max ?? 20);
    el.innerHTML = `
      <strong>TURF #${cellNum || turf.cell_num || "—"}</strong>
      <span class="tt-line"><em>Rajonas</em> ${turf.district || turf.turf_label || "—"}</span>
      <span class="tt-line"><em>Kontrolė</em> ${inf}%</span>
      <span class="tt-line"><em>Grafiti</em> ${graffitiCount}/${graffitiMax}</span>
    `;
    el.style.left = `${clientX + 14}px`;
    el.style.top = `${clientY + 14}px`;
    el.classList.add("is-visible");
  }

  function renderSidePanels(state) {
    const gang = state.gang || {};
    const nameEl = document.getElementById("networkGangName");
    const logoEl = document.getElementById("gangStatLogo");
    const statsEl = document.getElementById("networkStats");
    const gangColor = gang.color_hex || "#a78bfa";

    if (nameEl) nameEl.textContent = state.hasGang ? (gang.name || "Gauja").toUpperCase() : "NEPRIKLAUSAI";
    if (logoEl) {
      logoEl.style.background = `linear-gradient(135deg, ${gangColor}, ${gang.secondary_color_hex || gangColor})`;
      logoEl.style.boxShadow = `0 0 24px ${gangColor}55`;
    }

    const gid = Number(gang.gang_id || gang.id || 0);
    const owned = (state.turfs || []).filter((t) => gid > 0 && Number(t.owner_gang_id) === gid).length;
    const members = (state.members || []).length;
    const rep = Number(gang.reputation || 0);

    if (statsEl) {
      statsEl.innerHTML = state.hasGang
        ? `
        <div class="stat-card"><span class="stat-k">Nariai</span><strong class="stat-v">${members}</strong></div>
        <div class="stat-card"><span class="stat-k">Turfai</span><strong class="stat-v">${owned}</strong></div>
        <div class="stat-card stat-card-accent"><span class="stat-k">Reputacija</span><strong class="stat-v">${rep.toLocaleString()}</strong></div>
      `
        : `<p class="muted small">Sukurk gaują skiltyje Registracija</p>`;
    }

    const legend = document.getElementById("gangLegend");
    if (legend) {
      legend.innerHTML = `
        <li><span class="legend-swatch legend-neutral"></span><span>Neutrali</span></li>
        <li><span class="legend-swatch legend-owned"></span><span>Užimta</span></li>
        <li><span class="legend-swatch legend-conflict"></span><span>Konfliktas</span></li>
      `;
    }

    const strip = document.getElementById("gangColorStrip");
    if (strip) {
      const colors = state.gangColors || [];
      strip.innerHTML = colors
        .map((g) => {
          const hex = g.color_hex || g.color || "#64748B";
          return `<span class="color-chip" style="background:${hex}" title="${hex}"></span>`;
        })
        .join("");
    }

    const warsCount = (state.activeWars || []).length;
    const bannerText = document.getElementById("warsBannerText");
    if (bannerText) bannerText.textContent = `Aktyvūs turf karai: ${warsCount}`;
    const banner = document.getElementById("warsBanner");
    if (banner) banner.classList.toggle("has-wars", warsCount > 0);
  }

  function renderWarsPopover(state) {
    const pop = document.getElementById("warsPopover");
    if (!pop) return;
    const wars = state.activeWars || [];
    if (!wars.length) {
      pop.innerHTML = `<p class="muted small">Konfliktų nėra</p>`;
      return;
    }
    pop.innerHTML = wars
      .map(
        (w) =>
          `<button type="button" class="war-pop-item" data-turf="${w.turfId || ""}">
            <span class="war-pop-dot" style="background:${w.color_hex || "#f87171"}"></span>
            <span class="war-pop-id">#${w.turfId || w.cell_num || "—"}</span>
            <span class="war-pop-meta">${w.label || "—"} · ${w.influence || 0}%</span>
            <span class="war-pop-time">${w.timeLabel || "Aktyvus"}</span>
          </button>`,
      )
      .join("");

    pop.querySelectorAll(".war-pop-item").forEach((btn) => {
      btn.addEventListener("click", () => {
        const tid = btn.dataset.turf;
        const turf = turfById[tid] || (state.turfs || []).find((t) => String(t.turf_id) === String(tid));
        if (turf) {
          selectTurf(turf);
          focusTurf(turf);
        }
        pop.classList.add("hidden");
      });
    });
  }

  function graffitiLabel(turf) {
    const count = Number(turf.graffiti_count ?? Math.floor(Number(turf.influence ?? 0) / 5));
    const max = Number(turf.graffiti_max ?? 20);
    return `${count}/${max}`;
  }

  function drugActivityLabel(turf) {
    const sales = Number(turf.sales_count || 0);
    const members = Number(turf.active_members || 0);
    if (sales > 0 || members > 0) return "Aktyvi";
    return "Rami";
  }

  function renderTurfInfo(turf) {
    const title = document.getElementById("turfInfoTitle");
    const body = document.getElementById("turfInfoBody");
    const btnGps = document.getElementById("btnTurfRoute");
    if (!title || !body) return;
    if (!turf) {
      title.textContent = "TURF —";
      body.innerHTML = "<p class='muted small'>Pasirink teritoriją žemėlapyje.</p>";
      if (btnGps) btnGps.disabled = true;
      return;
    }
    const cellNum = turf.cell_num || turf.turf_id;
    const owner = turf.owner_display || turf.owner_name || "Neutralu";
    const inf = Math.max(0, Math.min(100, Number(turf.influence ?? turf.progress ?? 0)));
    const war = turf.is_war ? "Taip" : "Ne";
    title.textContent = `TURF #${cellNum}`;
    title.style.color = turf.map_color || "#c4b5fd";
    body.innerHTML = `
      <div class="turf-row"><span>Rajonas</span><strong>${turf.district || turf.turf_label || "—"}</strong></div>
      <div class="turf-row"><span>Savininkas</span><strong style="color:${turf.map_color || NEUTRAL_COLOR}">${owner}</strong></div>
      <div class="turf-row"><span>Kontrolė</span><strong>${inf}%</strong><div class="bar"><i style="width:${inf}%;background:${turf.map_color || "#a78bfa"}"></i></div></div>
      <div class="turf-row"><span>Grafiti</span><strong>${graffitiLabel(turf)}</strong></div>
      <div class="turf-row"><span>Narkotikų veikla</span><strong>${drugActivityLabel(turf)}</strong></div>
      <div class="turf-row"><span>Konfliktas</span><strong class="${turf.is_war ? "warn-txt" : "ok"}">${war}</strong></div>
    `;
    if (btnGps) {
      btnGps.disabled = false;
      btnGps.dataset.turfId = turf.turf_id;
    }
  }

  function selectTurf(turf) {
    selectedTurf = turf;
    renderTurfInfo(turf);
    refreshAllLayerStyles();
    if (turf && layerById[turf.turf_id]?.bringToFront) {
      layerById[turf.turf_id].bringToFront();
    }
  }

  function focusTurf(turf) {
    if (!leafletMap || !mapCfg || !turf) return;
    const bounds = gameBoundsToLeaflet(turf, mapCfg, 0.08);
    leafletMap.fitBounds(bounds, { padding: [36, 36], animate: true, maxZoom: baseFitZoom + 1.5 });
  }

  function buildTurfs(state) {
    if (!leafletMap || !mapCfg) return;
    if (turfLayer) {
      leafletMap.removeLayer(turfLayer);
      turfLayer = null;
    }
    turfLayer = L.layerGroup().addTo(leafletMap);
    turfById = {};
    layerById = {};
    const cfg = mapCfg;
    const allBounds = [];

    const turfs = (state.turfs || []).slice().sort((a, b) => turfArea(b) - turfArea(a));

    turfs.forEach((turf) => {
      if (turf.min_x == null && turf.center_x == null) return;
      const bounds = gameBoundsToLeaflet(turf, cfg, 0.01);
      allBounds.push(bounds);
      const cellNum = turf.cell_num || turf.turf_id;
      turfById[turf.turf_id] = turf;

      const rect = L.rectangle(bounds, {
        ...buildLayerStyle(turf, "base"),
        interactive: true,
        bubblingMouseEvents: false,
      });
      rect._turfId = turf.turf_id;
      rect._turfData = turf;
      layerById[turf.turf_id] = rect;

      rect.on("mouseover", (e) => {
        hoveredId = turf.turf_id;
        const ev = e.originalEvent;
        showTooltip(turf, cellNum, ev.clientX, ev.clientY);
        applyLayerStyle(turf.turf_id);
      });
      rect.on("mousemove", (e) => {
        const ev = e.originalEvent;
        showTooltip(turf, cellNum, ev.clientX, ev.clientY);
      });
      rect.on("mouseout", () => {
        hideTooltip();
        if (hoveredId === turf.turf_id) hoveredId = null;
        applyLayerStyle(turf.turf_id);
      });
      rect.on("click", (e) => {
        L.DomEvent.stopPropagation(e);
        selectTurf(turf);
      });
      rect.on("mousedown", (e) => {
        L.DomEvent.stopPropagation(e);
      });

      rect.addTo(turfLayer);
    });

    if (allBounds.length) {
      turfBoundsLatLng = L.latLngBounds(allBounds);
    }

    if (selectedTurf) {
      const updated = turfById[selectedTurf.turf_id];
      selectTurf(updated || null);
    }
  }

  function bindMapEvents() {
    if (mapEventsBound || !leafletMap) return;
    mapEventsBound = true;
    leafletMap.on("movestart zoomstart", hideTooltip);
    leafletMap.on("click", () => {
      hideTooltip();
      hoveredId = null;
      refreshAllLayerStyles();
    });
  }

  function mapBoundsLatLng() {
    if (!mapCfg) return null;
    return L.latLngBounds([
      [mapCfg.minY, mapCfg.minX],
      [mapCfg.maxY, mapCfg.maxX],
    ]);
  }

  function fitMapFill(padding) {
    if (!leafletMap || !mapCfg) return;
    const bounds = viewBoundsLatLng(mapCfg) || mapBoundsLatLng();
    const pad = padding != null ? padding : 8;
    leafletMap.fitBounds(bounds, { padding: [pad, pad], animate: false, maxZoom: 1 });
    leafletMap.panInsideBounds(bounds, { animate: false });
    baseFitZoom = leafletMap.getZoom();
    leafletMap.setMinZoom(Math.max(-1, baseFitZoom - 0.75));
    leafletMap.setMaxZoom(baseFitZoom + 2.5);
    const full = mapBoundsLatLng();
    if (full) leafletMap.setMaxBounds(full.pad(0.03));
  }

  function fitAllTurfs() {
    if (!leafletMap || !turfBoundsLatLng) return fitMapFill(8);
    leafletMap.fitBounds(turfBoundsLatLng, { padding: [24, 24], animate: true });
  }

  function ensureMap(state) {
    lastState = state;
    mapCfg = normalizeMapConfig(state);
    renderSidePanels(state);

    const el = document.getElementById("gangsLeafletMap");
    if (!el || typeof L === "undefined") return;

    if (!leafletMap) {
      leafletMap = L.map(el, {
        crs: L.CRS.Simple,
        minZoom: -3,
        maxZoom: 8,
        zoomSnap: 0.12,
        zoomDelta: 0.35,
        wheelPxPerZoomLevel: 55,
        zoomControl: false,
        attributionControl: false,
        preferCanvas: true,
        dragging: true,
        scrollWheelZoom: true,
        doubleClickZoom: true,
        boxZoom: false,
        inertia: true,
        inertiaDeceleration: 3200,
        easeLinearity: 0.18,
      });
      bindMapEvents();
    }

    const bounds = [
      [mapCfg.minY, mapCfg.minX],
      [mapCfg.maxY, mapCfg.maxX],
    ];
    if (imageLayer) leafletMap.removeLayer(imageLayer);
    imageLayer = L.imageOverlay(mapCfg.imageUrl, bounds, { interactive: false, opacity: 0.92 }).addTo(leafletMap);
    buildTurfs(state);

    requestAnimationFrame(() => {
      invalidate();
      fitMapFill(4);
      if (!selectedTurf) selectTurf(null);
    });
    setTimeout(() => {
      invalidate();
      fitMapFill(4);
    }, 120);
    setTimeout(() => {
      invalidate();
      fitMapFill(4);
    }, 320);
  }

  function zoomIn() {
    if (leafletMap) leafletMap.zoomIn(0.45);
  }

  function zoomOut() {
    if (leafletMap) leafletMap.zoomOut(0.45);
  }

  function resetView() {
    fitMapFill(4);
  }

  function invalidate() {
    if (leafletMap) leafletMap.invalidateSize({ animate: false });
  }

  function getSelectedTurf() {
    return selectedTurf;
  }

  return {
    open: ensureMap,
    renderPanels: renderSidePanels,
    renderWarsPopover,
    destroy,
    zoomIn,
    zoomOut,
    resetView,
    fitAllTurfs,
    invalidate,
    getSelectedTurf,
  };
})();
