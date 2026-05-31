/** Gang Turf žemėlapis — Leaflet, permatomas overlay, pan/zoom, maži turfai. */
window.GangMap = (function () {
  const NEUTRAL_COLOR = "#64748B";

  const OP = {
    neutral: { fill: 0.08, stroke: 0.12, weight: 0.35 },
    owned: { fill: 0.24, stroke: 0.28, weight: 0.4 },
    contested: { fill: 0.3, stroke: 0.4, weight: 0.55 },
    hover: { fill: 0.4, stroke: 0.7, weight: 0.85 },
    selected: { fill: 0.35, stroke: 0.85, weight: 1.15 },
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
    const file = t.imageFile || "asset/gtav_satellite_2048.png";
    return {
      minX: Number(t.gameMin?.x ?? -4000),
      minY: Number(t.gameMin?.y ?? -4000),
      maxX: Number(t.gameMax?.x ?? 4500),
      maxY: Number(t.gameMax?.y ?? 6625),
      imgW: Number(t.imageWidth) || 2048,
      imgH: Number(t.imageHeight) || 2048,
      imageUrl: nuiImageUrl(file),
    };
  }

  function gameToMap(gx, gy, cfg) {
    const x = ((gx - cfg.minX) / (cfg.maxX - cfg.minX)) * cfg.imgW;
    const y = cfg.imgH - ((gy - cfg.minY) / (cfg.maxY - cfg.minY)) * cfg.imgH;
    return { x, y };
  }

  function gameBoundsToLeaflet(turf, cfg, padRatio) {
    let minX = Number(turf.min_x);
    let minY = Number(turf.min_y);
    let maxX = Number(turf.max_x);
    let maxY = Number(turf.max_y);
    if (!Number.isFinite(minX) || !Number.isFinite(minY)) {
      const cx = Number(turf.center_x) || 0;
      const cy = Number(turf.center_y) || 0;
      const r = Number(turf.radius) || 80;
      const p1 = gameToMap(cx - r, cy - r, cfg);
      const p2 = gameToMap(cx + r, cy + r, cfg);
      return [
        [p1.y, p1.x],
        [p2.y, p2.x],
      ];
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
    const sw = gameToMap(minX, minY, cfg);
    const ne = gameToMap(maxX, maxY, cfg);
    return [
      [sw.y, sw.x],
      [ne.y, ne.x],
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
    if (mode === "selected") return "#fbbf24";
    if (mode === "hover") return "#f8fafc";
    if (turf.is_war) return "#f87171";
    if (turfBaseKind(turf) === "owned") return turfFillColor(turf);
    return "#64748b";
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
      dashArray: mode === "base" && turf.is_war ? "3 4" : null,
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
    const owner = turf.owner_display || turf.owner_name || "Neutralu";
    const inf = Math.max(0, Math.min(100, Number(turf.influence ?? turf.progress ?? 0)));
    const graffiti = turf.graffiti_pct != null ? turf.graffiti_pct : Math.min(100, Math.floor(inf / 5));
    const sales = Number(turf.sales_count || 0);
    const members = Number(turf.active_members || 0);
    el.innerHTML = `
      <strong>TURF #${cellNum || turf.cell_num || "—"}</strong>
      <span class="tt-line"><em>Rajonas</em> ${turf.district || turf.turf_label || "—"}</span>
      <span class="tt-line"><em>Savininkas</em> <b style="color:${turf.map_color || NEUTRAL_COLOR}">${owner}</b></span>
      <span class="tt-line"><em>Kontrolė</em> ${inf}%</span>
      <span class="tt-line"><em>Grafiti</em> ${graffiti}%</span>
      <span class="tt-line"><em>Nark. pardavimai</em> ${sales}</span>
      <span class="tt-line"><em>Aktyvūs nariai</em> ${members}</span>
    `;
    el.style.left = `${clientX + 14}px`;
    el.style.top = `${clientY + 14}px`;
    el.classList.add("is-visible");
  }

  function renderSidePanels(state) {
    const gang = state.gang || {};
    const nameEl = document.getElementById("networkGangName");
    const statsEl = document.getElementById("networkStats");
    if (nameEl) nameEl.textContent = state.hasGang ? gang.name || "Gauja" : "Nepriklausai gaujai";

    const gid = Number(gang.gang_id || gang.id || 0);
    const owned = (state.turfs || []).filter((t) => gid > 0 && Number(t.owner_gang_id) === gid).length;
    const members = (state.members || []).length;
    if (statsEl) {
      statsEl.innerHTML = state.hasGang
        ? `
        <li><span>Reputacija</span><strong>${Number(gang.reputation || 0).toLocaleString()}</strong></li>
        <li><span>Turtai</span><strong>${owned}</strong></li>
        <li><span>Nariai</span><strong>${members}</strong></li>
      `
        : `<li class="muted">Sukurk gaują skiltyje Registracija</li>`;
    }

    const legend = document.getElementById("gangLegend");
    if (legend) {
      const colors = state.gangColors || [];
      const swatches = colors
        .map((g) => {
          const hex = g.color_hex || g.color || "#64748B";
          return `<li class="legend-swatch-only" title="${hex}"><span class="dot" style="background:${hex}"></span></li>`;
        })
        .join("");
      legend.innerHTML =
        swatches +
        `<li class="legend-swatch-only legend-neutral" title="Neutralu"><span class="dot dot-free"></span></li>`;
    }

    const topList = document.getElementById("topGangsList");
    if (topList) {
      topList.innerHTML = (state.topGangs || [])
        .map(
          (g, i) =>
            `<li><span class="rank">#${i + 1}</span> <span style="color:${g.color_hex || "#fff"}">${g.name}</span> <em>${g.turf_count || 0} turf.</em></li>`,
        )
        .join("") || "<li class='muted'>—</li>";
    }

    const wars = document.getElementById("activeWarsList");
    if (wars) {
      wars.innerHTML = (state.activeWars || [])
        .map((w) => `<li><strong>${w.label}</strong> · ${w.owner} (${w.influence}%)</li>`)
        .join("") || "<li class='muted'>Šiuo metu ramu</li>";
    }

    const acts = document.getElementById("recentActsList");
    if (acts) {
      acts.innerHTML = (state.recentActivities || [])
        .map((a) => `<li><span style="color:${a.colorHex || "#a78bfa"}">${a.gangName}</span> · ${a.label} (+$${a.profit})</li>`)
        .join("") || "<li class='muted'>Veiklų nėra</li>";
    }
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
    const graffiti = turf.graffiti_pct != null ? turf.graffiti_pct : Math.min(100, Math.floor(inf / 5));
    const sales = Number(turf.sales_count || 0);
    const war = turf.is_war ? "Taip" : "Nėra";
    title.textContent = `TURF #${cellNum}`;
    title.style.color = turf.map_color || "#e5e7eb";
    body.innerHTML = `
      <div class="turf-row"><span>Rajonas</span><strong>${turf.district || turf.turf_label || "—"}</strong></div>
      <div class="turf-row"><span>Savininkas</span><strong style="color:${turf.map_color || NEUTRAL_COLOR}">${owner}</strong></div>
      <div class="turf-row"><span>Kontrolė</span><strong>${inf}%</strong><div class="bar"><i style="width:${inf}%;background:${turf.map_color || "#a78bfa"}"></i></div></div>
      <div class="turf-row"><span>Grafiti</span><strong>${graffiti}%</strong></div>
      <div class="turf-row"><span>Narkotikų veikla</span><strong>${sales}</strong></div>
      <div class="turf-row"><span>Aktyvūs konfliktai</span><strong class="${turf.is_war ? "warn-txt" : ""}">${war}</strong></div>
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

    const turfs = (state.turfs || []).slice().sort((a, b) => turfArea(b) - turfArea(a));

    turfs.forEach((turf) => {
      if (turf.min_x == null && turf.center_x == null) return;
      const bounds = gameBoundsToLeaflet(turf, cfg, 0.08);
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
    return L.latLngBounds([
      [0, 0],
      [mapCfg.imgH, mapCfg.imgW],
    ]);
  }

  function fitMapFill(padding) {
    if (!leafletMap || !mapCfg) return;
    const bounds = mapBoundsLatLng();
    const pad = padding != null ? padding : 2;
    leafletMap.fitBounds(bounds, { padding: [pad, pad], animate: false });
    const z = leafletMap.getZoom();
    const size = leafletMap.getSize();
    const nw = leafletMap.latLngToContainerPoint(bounds.getNorthWest());
    const se = leafletMap.latLngToContainerPoint(bounds.getSouthEast());
    const bw = Math.abs(se.x - nw.x);
    const bh = Math.abs(se.y - nw.y);
    if (bw > 1 && bh > 1 && size.x > 0 && size.y > 0) {
      const cover = Math.max(size.x / bw, size.y / bh);
      if (cover > 1.06) {
        leafletMap.setZoom(Math.min(z + Math.log2(cover * 0.98), z + 3.5));
      }
    }
    baseFitZoom = leafletMap.getZoom();
    leafletMap.setMinZoom(Math.max(-2, baseFitZoom - 0.75));
    leafletMap.setMaxZoom(baseFitZoom + 6);
    leafletMap.setMaxBounds(bounds.pad(0.03));
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
        zoomSnap: 0.15,
        zoomDelta: 0.35,
        wheelPxPerZoomLevel: 70,
        zoomControl: false,
        attributionControl: false,
        preferCanvas: false,
        dragging: true,
        scrollWheelZoom: true,
        doubleClickZoom: true,
        boxZoom: true,
        inertia: true,
        inertiaDeceleration: 3000,
        easeLinearity: 0.2,
      });
      bindMapEvents();
    }

    const bounds = [
      [0, 0],
      [mapCfg.imgH, mapCfg.imgW],
    ];
    if (imageLayer) leafletMap.removeLayer(imageLayer);
    imageLayer = L.imageOverlay(mapCfg.imageUrl, bounds, { interactive: false }).addTo(leafletMap);
    buildTurfs(state);

    requestAnimationFrame(() => {
      invalidate();
      fitMapFill(8);
      if (!selectedTurf) selectTurf(null);
    });
    setTimeout(() => {
      invalidate();
      fitMapFill(8);
    }, 120);
    setTimeout(() => {
      invalidate();
      fitMapFill(8);
    }, 320);
  }

  function zoomIn() {
    if (leafletMap) leafletMap.zoomIn(0.45);
  }

  function zoomOut() {
    if (leafletMap) leafletMap.zoomOut(0.45);
  }

  function resetView() {
    fitMapFill(8);
  }

  function toggleFullscreen(on) {
    const panel = document.getElementById("tabPanelMap");
    const bezel = document.querySelector(".tablet-bezel");
    if (!panel) return;
    const enable =
      on === true || (on !== false && !panel.classList.contains("map-fullscreen"));
    panel.classList.toggle("map-fullscreen", enable);
    if (bezel) bezel.classList.toggle("tablet-map-fullscreen", enable);
    setTimeout(() => {
      invalidate();
      fitMapFill(enable ? 4 : 8);
    }, 80);
    setTimeout(() => {
      invalidate();
      fitMapFill(enable ? 4 : 8);
    }, 280);
  }

  function invalidate() {
    if (leafletMap) leafletMap.invalidateSize({ animate: false });
  }

  function getSelectedTurf() {
    return selectedTurf;
  }

  return {
    open: ensureMap,
    destroy,
    zoomIn,
    zoomOut,
    resetView,
    toggleFullscreen,
    invalidate,
    getSelectedTurf,
  };
})();
