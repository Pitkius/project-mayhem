/** Bendras GTA V satelitinio žemėlapio branduolys (MDT + Gang Tablet). */
window.GtavMapCore = (function () {
  const ISLAND = {
    gameMin: { x: -4000, y: -4000 },
    gameMax: { x: 4500, y: 6625 },
    viewMin: { x: -4000, y: -4000 },
    viewMax: { x: 4500, y: 6625 },
    offsetX: 0,
    offsetY: 0,
    scaleX: 1,
    scaleY: 1,
    flipY: true,
    imageWidth: 2048,
    imageHeight: 2560,
  };

  function nuiImageUrl(pathFromHtml, resourceName) {
    const raw = String(pathFromHtml || "").trim();
    if (!raw || /^https?:\/\//i.test(raw) || /^nui:\/\//i.test(raw)) return raw;
    const res = resourceName || "fivempro_ltpd";
    let p = raw.replace(/^\/+/, "");
    if (!p.startsWith("html/")) p = `html/${p}`;
    return `nui://${res}/${p}`;
  }

  function num(v, fallback) {
    const n = Number(v);
    return Number.isFinite(n) ? n : fallback;
  }

  function normalizeMapConfig(cfg, resourceName, defaultImageFile) {
    const t = cfg || {};
    const minX = num(t.gameMin?.x, ISLAND.gameMin.x);
    const minY = num(t.gameMin?.y, ISLAND.gameMin.y);
    const maxX = num(t.gameMax?.x, ISLAND.gameMax.x);
    const maxY = num(t.gameMax?.y, ISLAND.gameMax.y);
    const coordMinX = num(t.coordMin?.x, minX);
    const coordMinY = num(t.coordMin?.y, minY);
    const coordMaxX = num(t.coordMax?.x, maxX);
    const coordMaxY = num(t.coordMax?.y, maxY);
    const file = t.imageFile || defaultImageFile || "mdt/asset/gtav_satellite_2048.png";
    return {
      minX,
      minY,
      maxX,
      maxY,
      coordMinX,
      coordMinY,
      coordMaxX,
      coordMaxY,
      viewMinX: num(t.viewMin?.x, ISLAND.viewMin.x),
      viewMinY: num(t.viewMin?.y, ISLAND.viewMin.y),
      viewMaxX: num(t.viewMax?.x, ISLAND.viewMax.x),
      viewMaxY: num(t.viewMax?.y, ISLAND.viewMax.y),
      offsetX: num(t.offsetX, 0),
      offsetY: num(t.offsetY, 0),
      scaleX: num(t.scaleX, 1),
      scaleY: num(t.scaleY, 1),
      flipY: t.flipY !== false,
      imgW: num(t.imageWidth, ISLAND.imageWidth),
      imgH: num(t.imageHeight, ISLAND.imageHeight),
      imageUrl: nuiImageUrl(file, resourceName),
    };
  }

  /**
   * GTA (x,y) → Leaflet [lat, lng] — kaip pause map (šiaurė = mažesnis lat).
   * Naudoja tuos pačius GetEntityCoords x/y kaip AddBlipForCoord.
   */
  function gameToLatLng(gx, gy, cfg) {
    if (!cfg) return [Number(gy) || 0, Number(gx) || 0];
    const x = Number(gx);
    const y = Number(gy);
    if (!Number.isFinite(x) || !Number.isFinite(y)) return [cfg.minY, cfg.minX];

    const rangeX = cfg.coordMaxX - cfg.coordMinX || 1;
    const rangeY = cfg.coordMaxY - cfg.coordMinY || 1;
    const mapRangeX = cfg.maxX - cfg.minX || 1;
    const mapRangeY = cfg.maxY - cfg.minY || 1;
    const scaleX = cfg.scaleX || 1;
    const scaleY = cfg.scaleY || 1;
    const ox = cfg.offsetX || 0;
    const oy = cfg.offsetY || 0;
    const flipY = cfg.flipY !== false;

    let tX = (x - cfg.coordMinX) / rangeX;
    let tY = (y - cfg.coordMinY) / rangeY;
    tX = Math.max(0, Math.min(1, tX));
    tY = Math.max(0, Math.min(1, tY));
    if (flipY) tY = 1 - tY;

    const lng = cfg.minX + tX * mapRangeX * scaleX + ox;
    const lat = cfg.minY + tY * mapRangeY * scaleY + oy;
    return [lat, lng];
  }

  function latLngToGame(lat, lng, cfg) {
    if (!cfg) return { x: Number(lng) || 0, y: Number(lat) || 0 };
    const mapRangeX = cfg.maxX - cfg.minX || 1;
    const mapRangeY = cfg.maxY - cfg.minY || 1;
    let tX = (Number(lng) - (cfg.offsetX || 0) - cfg.minX) / (mapRangeX * (cfg.scaleX || 1));
    let tY = (Number(lat) - (cfg.offsetY || 0) - cfg.minY) / (mapRangeY * (cfg.scaleY || 1));
    tX = Math.max(0, Math.min(1, tX));
    tY = Math.max(0, Math.min(1, tY));
    if (cfg.flipY !== false) tY = 1 - tY;
    return {
      x: cfg.coordMinX + tX * (cfg.coordMaxX - cfg.coordMinX),
      y: cfg.coordMinY + tY * (cfg.coordMaxY - cfg.coordMinY),
    };
  }

  function gameBoundsLatLng(cfg) {
    if (!cfg || typeof L === "undefined") return null;
    return L.latLngBounds([cfg.minY, cfg.minX], [cfg.maxY, cfg.maxX]);
  }

  function viewBoundsLatLng(cfg) {
    if (!cfg || typeof L === "undefined") return null;
    return L.latLngBounds(
      [cfg.viewMinY + cfg.offsetY, cfg.viewMinX + cfg.offsetX],
      [cfg.viewMaxY + cfg.offsetY, cfg.viewMaxX + cfg.offsetX],
    );
  }

  function createLeafletOptions(extra) {
    return Object.assign(
      {
        crs: L.CRS.Simple,
        minZoom: -4,
        maxZoom: 6,
        zoomSnap: 0.1,
        zoomDelta: 0.4,
        wheelPxPerZoomLevel: 48,
        zoomControl: false,
        attributionControl: false,
        preferCanvas: true,
        dragging: true,
        scrollWheelZoom: true,
        doubleClickZoom: true,
        boxZoom: false,
        inertia: true,
        inertiaDeceleration: 2800,
        inertiaMaxSpeed: 1400,
        easeLinearity: 0.2,
        fadeAnimation: false,
        zoomAnimation: true,
        markerZoomAnimation: false,
        maxBoundsViscosity: 1.0,
      },
      extra || {},
    );
  }

  /**
   * @returns {{ baseFitZoom: number }}
   */
  function fitIslandView(leafletMap, mapCfg, opts) {
    const o = opts || {};
    const full = gameBoundsLatLng(mapCfg);
    const vb = viewBoundsLatLng(mapCfg) || full;
    if (!leafletMap || !vb) return { baseFitZoom: 0 };

    const pad = o.padding != null ? o.padding : 12;
    leafletMap.fitBounds(vb, {
      padding: [pad, pad],
      animate: !!o.animate,
      maxZoom: o.maxZoom != null ? o.maxZoom : 3,
    });
    const baseFitZoom = leafletMap.getZoom();
    const minZ = o.minZoom != null ? o.minZoom : Math.min(-3, baseFitZoom - 1.25);
    const maxZ = o.maxZoomLimit != null ? o.maxZoomLimit : Math.max(5, baseFitZoom + 3.5);
    leafletMap.setMinZoom(minZ);
    leafletMap.setMaxZoom(maxZ);
    if (full) leafletMap.setMaxBounds(full.pad(o.boundsPad != null ? o.boundsPad : 0.02));
    leafletMap.panInsideBounds(vb, { animate: false });
    return { baseFitZoom };
  }

  function scheduleInvalidate(leafletMap, delays) {
    if (!leafletMap) return;
    const list = delays || [0, 120, 320];
    list.forEach((ms) => {
      if (ms <= 0) {
        leafletMap.invalidateSize({ animate: false });
      } else {
        setTimeout(() => leafletMap.invalidateSize({ animate: false }), ms);
      }
    });
  }

  function addSatelliteLayer(leafletMap, mapCfg, className) {
    const bounds = gameBoundsLatLng(mapCfg);
    if (!leafletMap || !bounds) return null;
    return L.imageOverlay(mapCfg.imageUrl, bounds, {
      interactive: false,
      opacity: 1,
      className: className || "gtav-sat-layer",
    }).addTo(leafletMap);
  }

  return {
    ISLAND,
    nuiImageUrl,
    normalizeMapConfig,
    gameToLatLng,
    latLngToGame,
    gameBoundsLatLng,
    viewBoundsLatLng,
    createLeafletOptions,
    fitIslandView,
    scheduleInvalidate,
    addSatelliteLayer,
  };
})();
