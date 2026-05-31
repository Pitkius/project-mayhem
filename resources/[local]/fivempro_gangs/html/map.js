/** Gang Network žemėlapis — Leaflet + vektorinis turf tinklelis (aiškus zoom). */
window.GangMap = (function () {
  let leafletMap = null;
  let gridLayer = null;
  let imageLayer = null;
  let mapCfg = null;
  let gridCfg = { cols: 28, rows: 20 };
  let lastState = null;
  let selectedTurf = null;
  let selectedCellId = null;

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
    return {
      minX: Number(t.gameMin?.x ?? -4000),
      minY: Number(t.gameMin?.y ?? -4000),
      maxX: Number(t.gameMax?.x ?? 4500),
      maxY: Number(t.gameMax?.y ?? 6625),
      imgW: Number(t.imageWidth) || 1024,
      imgH: Number(t.imageHeight) || 1280,
      imageUrl: nuiImageUrl(file),
    };
  }

  function turfAtGame(gx, gy, turfs) {
    let inZone = null;
    let inDist = Infinity;
    let nearest = null;
    let nearDist = Infinity;
    for (const t of turfs || []) {
      const dx = gx - Number(t.center_x);
      const dy = gy - Number(t.center_y);
      const d = Math.sqrt(dx * dx + dy * dy);
      const r = Number(t.radius) || 150;
      if (d <= r && d < inDist) {
        inZone = t;
        inDist = d;
      }
      if (d < nearDist) {
        nearest = t;
        nearDist = d;
      }
    }
    return inZone || nearest;
  }

  function cellGameCenter(col, row, cfg, grid) {
    const cols = grid.cols;
    const rows = grid.rows;
    const gx = cfg.minX + ((col + 0.5) / cols) * (cfg.maxX - cfg.minX);
    const gy = cfg.minY + ((rows - row - 0.5) / rows) * (cfg.maxY - cfg.minY);
    return { gx, gy };
  }

  function destroy() {
    if (leafletMap) {
      leafletMap.remove();
      leafletMap = null;
    }
    gridLayer = null;
    imageLayer = null;
    selectedTurf = null;
    selectedCellId = null;
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
        <li><span>Turfai</span><strong>${owned}</strong></li>
        <li><span>Nariai</span><strong>${members}</strong></li>
        <li><span>Heat</span><strong>${Number(gang.heat || 0)}%</strong></li>
      `
        : `<li class="muted">Sukurk gaują skiltyje Registracija</li>`;
    }

    const legend = document.getElementById("gangLegend");
    if (legend) {
      const seen = {};
      const items = [];
      (state.turfs || []).forEach((t) => {
        const owner = t.owner_name && String(t.owner_name).trim();
        if (!owner || seen[owner]) return;
        seen[owner] = true;
        const col = t.owner_color_hex || "#94a3b8";
        items.push(`<li><span class="dot" style="background:${col}"></span>${owner}</li>`);
      });
      items.push(`<li><span class="dot dot-free"></span>Neužimta / ginčas</li>`);
      legend.innerHTML = items.join("");
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

  function renderTurfInfo(turf, cellId) {
    const title = document.getElementById("turfInfoTitle");
    const body = document.getElementById("turfInfoBody");
    if (!title || !body) return;
    if (!turf) {
      title.textContent = "TURF —";
      body.innerHTML = "<p class='muted small'>Pasirink teritoriją žemėlapyje.</p>";
      return;
    }
    const label = turf.turf_label || turf.turf_id;
    const owner = turf.owner_name || "Laisva";
    const inf = Math.max(0, Math.min(100, Number(turf.influence ?? turf.progress ?? 0)));
    const heat = Number(turf.heat || 0);
    const sales = Number(turf.sales_count || 0);
    const graffiti = Math.min(20, Math.floor(inf / 5));
    const drugActive = heat > 20 || sales > 0;
    title.textContent = `TURF #${cellId || "—"}`;
    title.style.color = turf.owner_color_hex || "#e5e7eb";
    body.innerHTML = `
      <div class="turf-row"><span>Rajonas</span><strong>${label}</strong></div>
      <div class="turf-row"><span>Savininkas</span><strong style="color:${turf.owner_color_hex || "#94a3b8"}">${owner}</strong></div>
      <div class="turf-row"><span>Kontrolė</span><strong>${inf}%</strong><div class="bar"><i style="width:${inf}%;background:${turf.owner_color_hex || "#a78bfa"}"></i></div></div>
      <div class="turf-row"><span>Heat</span><strong>${heat}%</strong><div class="bar bar-heat"><i style="width:${heat}%"></i></div></div>
      <div class="turf-row"><span>Pardavimai</span><strong>${sales}</strong></div>
      <div class="turf-row"><span>Nark. prekyba</span><strong class="${drugActive ? "ok" : ""}">${drugActive ? "Aktyvi" : "Neaktyvi"}</strong></div>
      <div class="turf-row"><span>Grafiti</span><strong>${graffiti}/20</strong></div>
    `;
  }

  function selectTurf(turf, cellId) {
    selectedTurf = turf;
    selectedCellId = cellId;
    renderTurfInfo(turf, cellId);
    if (gridLayer) {
      gridLayer.eachLayer((layer) => {
        if (!layer._turfId) return;
        const on = turf && layer._turfId === turf.turf_id;
        layer.setStyle({
          weight: on ? 2.4 : 0.65,
          color: on ? "#fbbf24" : "rgba(15,23,42,0.55)",
        });
      });
    }
  }

  function buildGrid(state) {
    if (!leafletMap || !mapCfg) return;
    if (gridLayer) {
      leafletMap.removeLayer(gridLayer);
      gridLayer = null;
    }
    gridLayer = L.layerGroup().addTo(leafletMap);
    const cfg = mapCfg;
    const grid = gridCfg;
    const cols = grid.cols;
    const rows = grid.rows;
    const cellW = cfg.imgW / cols;
    const cellH = cfg.imgH / rows;
    let cellIndex = 0;

    for (let row = 0; row < rows; row++) {
      for (let col = 0; col < cols; col++) {
        cellIndex += 1;
        const { gx, gy } = cellGameCenter(col, row, cfg, grid);
        const turf = turfAtGame(gx, gy, state.turfs);
        const hasOwner = !!(turf && turf.owner_name);
        const fill = hasOwner && turf.owner_color_hex ? turf.owner_color_hex : "#334155";
        const y1 = row * cellH;
        const x1 = col * cellW;
        const bounds = [
          [y1, x1],
          [y1 + cellH, x1 + cellW],
        ];
        const rect = L.rectangle(bounds, {
          color: "rgba(15,23,42,0.55)",
          weight: 0.65,
          fillColor: fill,
          fillOpacity: hasOwner ? 0.58 : 0.22,
          interactive: true,
        });
        rect._turfId = turf ? turf.turf_id : null;
        rect._cellId = cellIndex;
        rect._turfData = turf;
        rect.on("click", () => {
          selectTurf(turf, cellIndex);
          if (turf && window.GangMapPost) {
            window.GangMapPost("gangs:setWaypoint", { turfId: turf.turf_id });
          }
        });
        rect.addTo(gridLayer);
      }
    }
  }

  function ensureMap(state) {
    lastState = state;
    mapCfg = normalizeMapConfig(state);
    gridCfg = state.mapGrid || { cols: 28, rows: 20 };
    renderSidePanels(state);

    const el = document.getElementById("gangsLeafletMap");
    if (!el || typeof L === "undefined") return;

    if (!leafletMap) {
      leafletMap = L.map(el, {
        crs: L.CRS.Simple,
        minZoom: -2,
        maxZoom: 4,
        zoomSnap: 0.25,
        zoomControl: false,
        attributionControl: false,
        preferCanvas: true,
      });
    }

    const bounds = [
      [0, 0],
      [mapCfg.imgH, mapCfg.imgW],
    ];
    if (imageLayer) {
      leafletMap.removeLayer(imageLayer);
    }
    imageLayer = L.imageOverlay(mapCfg.imageUrl, bounds, {
      interactive: false,
    }).addTo(leafletMap);
    buildGrid(state);
    leafletMap.fitBounds(bounds, { padding: [4, 4] });
    const first = (state.turfs || [])[0];
    if (first) selectTurf(first, 1);
    else selectTurf(null, null);

    setTimeout(() => leafletMap && leafletMap.invalidateSize(), 80);
  }

  function zoomIn() {
    if (leafletMap) leafletMap.zoomIn(0.35);
  }

  function zoomOut() {
    if (leafletMap) leafletMap.zoomOut(0.35);
  }

  function resetView() {
    if (!leafletMap || !mapCfg) return;
    leafletMap.fitBounds(
      [
        [0, 0],
        [mapCfg.imgH, mapCfg.imgW],
      ],
      { padding: [4, 4] },
    );
  }

  function invalidate() {
    if (leafletMap) leafletMap.invalidateSize();
  }

  return {
    open: ensureMap,
    destroy,
    zoomIn,
    zoomOut,
    resetView,
    invalidate,
    getSelectedTurf: () => selectedTurf,
  };
})();
