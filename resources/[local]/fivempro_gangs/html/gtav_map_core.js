/** Bendras GTA V satelitinio žemėlapio branduolys (MDT + Gang Tablet). */
window.GtavMapCore = (function () {
  const ISLAND = {
    gameMin: { x: -4000, y: -4000 },
    gameMax: { x: 4500, y: 6625 },
    viewMin: { x: -4000, y: -4000 },
    viewMax: { x: 4500, y: 6625 },
    offsetX: 0,
    offsetY: 0,
    imageWidth: 2048,
    imageHeight: 2560,
  };

  function nuiImageUrl(pathFromHtml, resourceName) {
    const raw = String(pathFromHtml || "").trim();
    if (!raw || /^https?:\/\//i.test(raw) || /^nui:\/\//i.test(raw)) return raw;
    const res = resourceName || "fivempro_gangs";
    let p = raw.replace(/^\/+/, "");
    if (!p.startsWith("html/")) p = `html/${p}`;
    return `nui://${res}/${p}`;
  }

  function normalizeMapConfig(cfg, resourceName, defaultImageFile) {
    const t = cfg || {};
    const minX = Number(t.gameMin?.x ?? ISLAND.gameMin.x);
    const minY = Number(t.gameMin?.y ?? ISLAND.gameMin.y);
    const maxX = Number(t.gameMax?.x ?? ISLAND.gameMax.x);
    const maxY = Number(t.gameMax?.y ?? ISLAND.gameMax.y);
    const file = t.imageFile || defaultImageFile || "asset/gtav_satellite_2048.png";
    return {
      minX,
      minY,
      maxX,
      maxY,
      viewMinX: Number(t.viewMin?.x ?? ISLAND.viewMin.x),
      viewMinY: Number(t.viewMin?.y ?? ISLAND.viewMin.y),
      viewMaxX: Number(t.viewMax?.x ?? ISLAND.viewMax.x),
      viewMaxY: Number(t.viewMax?.y ?? ISLAND.viewMax.y),
      offsetX: Number(t.offsetX) || 0,
      offsetY: Number(t.offsetY) || 0,
      imgW: Number(t.imageWidth) || ISLAND.imageWidth,
      imgH: Number(t.imageHeight) || ISLAND.imageHeight,
      imageUrl: nuiImageUrl(file, resourceName),
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
    gameBoundsLatLng,
    viewBoundsLatLng,
    createLeafletOptions,
    fitIslandView,
    scheduleInvalidate,
    addSatelliteLayer,
  };
})();
