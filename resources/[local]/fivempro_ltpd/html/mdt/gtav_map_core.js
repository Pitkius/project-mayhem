/** Bendras GTA V satelitinio žemėlapio branduolys (MDT). Afini kalibracija + suvienodintos ribos. */
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
    flipY: false,
    imageWidth: 2048,
    imageHeight: 2048,
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

  /** gy = intercept + slope * v  (mažiausios kvadratų) */
  function linearFit(xs, ys) {
    const n = xs.length;
    if (n < 1) return { intercept: 0, slope: 1 };
    if (n === 1) return { intercept: ys[0] - xs[0], slope: 1 };
    let sumX = 0;
    let sumY = 0;
    let sumXX = 0;
    let sumXY = 0;
    for (let i = 0; i < n; i += 1) {
      const x = xs[i];
      const y = ys[i];
      sumX += x;
      sumY += y;
      sumXX += x * x;
      sumXY += x * y;
    }
    const denom = n * sumXX - sumX * sumX;
    if (Math.abs(denom) < 1e-9) return { intercept: sumY / n, slope: 0 };
    const slope = (n * sumXY - sumX * sumY) / denom;
    const intercept = (sumY - slope * sumX) / n;
    return { intercept, slope };
  }

  /**
   * Kalibracija: žinomos vietos ant PNG (u,v ∈ [0,1], v=0 šiaurė).
   * Iš jų apskaičiuojami coordMin/coordMax — tiksliau nei rankinis offsetY.
   */
  function applyCalibration(cfg, points) {
    if (!Array.isArray(points) || points.length < 2) return cfg;

    const u = [];
    const v = [];
    const gx = [];
    const gy = [];

    points.forEach((p) => {
      const px = num(p.gx, NaN);
      const py = num(p.gy, NaN);
      const pu = num(p.u, NaN);
      const pv = num(p.v, NaN);
      if (!Number.isFinite(px) || !Number.isFinite(py) || !Number.isFinite(pu) || !Number.isFinite(pv)) return;
      gx.push(px);
      gy.push(py);
      u.push(Math.max(0, Math.min(1, pu)));
      v.push(Math.max(0, Math.min(1, pv)));
    });

    if (gx.length < 2) return cfg;

    const fitX = linearFit(u, gx);
    const fitY = linearFit(v, gy);

    const coordMinX = fitX.intercept;
    const coordMaxX = fitX.intercept + fitX.slope;
    const coordMaxY = fitY.intercept;
    const coordMinY = fitY.intercept + fitY.slope;

    if (coordMaxX - coordMinX > 100 && coordMaxY - coordMinY > 100) {
      cfg.coordMinX = coordMinX;
      cfg.coordMaxX = coordMaxX;
      cfg.coordMinY = coordMinY;
      cfg.coordMaxY = coordMaxY;
    }

    return cfg;
  }

  function normalizeMapConfig(cfg, resourceName, defaultImageFile) {
    const t = cfg || {};
    const minX = num(t.gameMin?.x, ISLAND.gameMin.x);
    const minY = num(t.gameMin?.y, ISLAND.gameMin.y);
    const maxX = num(t.gameMax?.x, ISLAND.gameMax.x);
    const maxY = num(t.gameMax?.y, ISLAND.gameMax.y);
    const file = t.imageFile || defaultImageFile || "mdt/asset/gtav_satellite_2048.png";

    const out = {
      minX,
      minY,
      maxX,
      maxY,
      coordMinX: num(t.coordMin?.x, minX),
      coordMinY: num(t.coordMin?.y, minY),
      coordMaxX: num(t.coordMax?.x, maxX),
      coordMaxY: num(t.coordMax?.y, maxY),
      viewMinX: num(t.viewMin?.x, ISLAND.viewMin.x),
      viewMinY: num(t.viewMin?.y, ISLAND.viewMin.y),
      viewMaxX: num(t.viewMax?.x, ISLAND.viewMax.x),
      viewMaxY: num(t.viewMax?.y, ISLAND.viewMax.y),
      offsetX: num(t.offsetX, 0),
      offsetY: num(t.offsetY, 0),
      scaleX: num(t.scaleX, 1),
      scaleY: num(t.scaleY, 1),
      flipY: t.flipY === true,
      imgW: num(t.imageWidth, ISLAND.imageWidth),
      imgH: num(t.imageHeight, ISLAND.imageHeight),
      imageUrl: nuiImageUrl(file, resourceName),
    };

    if (Array.isArray(t.calibration) && t.calibration.length >= 2) {
      applyCalibration(out, t.calibration);
    }

    return out;
  }

  function mapBoundsLatLng(cfg, kind) {
    if (!cfg || typeof L === "undefined") return null;
    const ox = cfg.offsetX || 0;
    const oy = cfg.offsetY || 0;
    if (kind === "view") {
      return L.latLngBounds(
        [cfg.viewMinY + oy, cfg.viewMinX + ox],
        [cfg.viewMaxY + oy, cfg.viewMaxX + ox],
      );
    }
    return L.latLngBounds([cfg.minY + oy, cfg.minX + ox], [cfg.maxY + oy, cfg.maxX + ox]);
  }

  /** GTA (x,y) → Leaflet [lat, lng] — lat=gameY, lng=gameX (standartinis GTA Leaflet). */
  function gameToLatLng(gx, gy, cfg) {
    if (!cfg) return [Number(gy) || 0, Number(gx) || 0];
    const x = Number(gx);
    const y = Number(gy);
    if (!Number.isFinite(x) || !Number.isFinite(y)) {
      return [cfg.minY + (cfg.offsetY || 0), cfg.minX + (cfg.offsetX || 0)];
    }

    const ox = cfg.offsetX || 0;
    const oy = cfg.offsetY || 0;
    const scaleX = cfg.scaleX || 1;
    const scaleY = cfg.scaleY || 1;

    if (cfg.flipY !== true && scaleX === 1 && scaleY === 1) {
      return [y + oy, x + ox];
    }

    const rangeX = cfg.coordMaxX - cfg.coordMinX || 1;
    const rangeY = cfg.coordMaxY - cfg.coordMinY || 1;
    const mapRangeX = cfg.maxX - cfg.minX || 1;
    const mapRangeY = cfg.maxY - cfg.minY || 1;

    let tX = (x - cfg.coordMinX) / rangeX;
    let tY = (y - cfg.coordMinY) / rangeY;
    tX = Math.max(0, Math.min(1, tX));
    tY = Math.max(0, Math.min(1, tY));
    if (cfg.flipY === true) tY = 1 - tY;

    const lng = cfg.minX + tX * mapRangeX * scaleX + ox;
    const lat = cfg.minY + tY * mapRangeY * scaleY + oy;
    return [lat, lng];
  }

  function latLngToGame(lat, lng, cfg) {
    if (!cfg) return { x: Number(lng) || 0, y: Number(lat) || 0 };
    const rangeX = cfg.coordMaxX - cfg.coordMinX || 1;
    const rangeY = cfg.coordMaxY - cfg.coordMinY || 1;
    const mapRangeX = cfg.maxX - cfg.minX || 1;
    const mapRangeY = cfg.maxY - cfg.minY || 1;
    const scaleX = cfg.scaleX || 1;
    const scaleY = cfg.scaleY || 1;
    let tX = (Number(lng) - (cfg.offsetX || 0) - cfg.minX) / (mapRangeX * scaleX);
    let tY = (Number(lat) - (cfg.offsetY || 0) - cfg.minY) / (mapRangeY * scaleY);
    tX = Math.max(0, Math.min(1, tX));
    tY = Math.max(0, Math.min(1, tY));
    if (cfg.flipY === true) tY = 1 - tY;
    return {
      x: cfg.coordMinX + tX * rangeX,
      y: cfg.coordMinY + tY * rangeY,
    };
  }

  function gameBoundsLatLng(cfg) {
    return mapBoundsLatLng(cfg, "game");
  }

  function viewBoundsLatLng(cfg) {
    return mapBoundsLatLng(cfg, "view");
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
        maxBoundsViscosity: 0.35,
        touchZoom: true,
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
