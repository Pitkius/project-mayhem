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
    const res = resourceName || "mrp_ltpd";
    let p = raw.replace(/^\/+/, "");
    if (!p.startsWith("html/")) p = `html/${p}`;
    return `nui://${res}/${p}`;
  }

  function num(v, fallback) {
    const n = Number(v);
    return Number.isFinite(n) ? n : fallback;
  }

  function solveLinear(A, b) {
    const M = A.map((row) => row.slice());
    const x = b.slice();
    const n = M.length;
    for (let i = 0; i < n; i += 1) {
      let piv = i;
      for (let r = i + 1; r < n; r += 1) {
        if (Math.abs(M[r][i]) > Math.abs(M[piv][i])) piv = r;
      }
      [M[i], M[piv]] = [M[piv], M[i]];
      [x[i], x[piv]] = [x[piv], x[i]];
      const d = M[i][i];
      if (Math.abs(d) < 1e-12) return null;
      for (let j = i; j < n; j += 1) M[i][j] /= d;
      x[i] /= d;
      for (let r = 0; r < n; r += 1) {
        if (r === i) continue;
        const f = M[r][i];
        for (let j = i; j < n; j += 1) M[r][j] -= f * M[i][j];
        x[r] -= f * x[i];
      }
    }
    return x;
  }

  function solve3x3(A, b) {
    return solveLinear(A, b);
  }

  function fitAffineGameToNorm(points, targetKey) {
    const ata = [
      [0, 0, 0],
      [0, 0, 0],
      [0, 0, 0],
    ];
    const atb = [0, 0, 0];
    points.forEach((p) => {
      const row = [p.gx, p.gy, 1];
      const t = p[targetKey];
      for (let i = 0; i < 3; i += 1) {
        atb[i] += row[i] * t;
        for (let j = 0; j < 3; j += 1) ata[i][j] += row[i] * row[j];
      }
    });
    return solve3x3(ata, atb);
  }

  function solveLs(rows, target) {
    const m = rows[0].length;
    const ata = Array.from({ length: m }, () => Array(m).fill(0));
    const atb = Array(m).fill(0);
    rows.forEach((row, i) => {
      const y = target[i];
      for (let j = 0; j < m; j += 1) {
        atb[j] += row[j] * y;
        for (let k = 0; k < m; k += 1) ata[j][k] += row[j] * row[k];
      }
    });
    return solveLinear(ata, atb);
  }

  /** IDW (inverse distance weighting) — tikslu ant kalibracijos taškų, sklandu tarp jų. */
  function idwGameToNorm(gx, gy, points, power) {
    const pwr = Number.isFinite(power) && power > 0 ? power : 2;
    let wSum = 0;
    let uSum = 0;
    let vSum = 0;
    for (let i = 0; i < points.length; i += 1) {
      const p = points[i];
      const dx = gx - p.gx;
      const dy = gy - p.gy;
      const d2 = dx * dx + dy * dy;
      if (d2 < 0.25) return [p.u, p.v];
      const w = 1 / Math.pow(d2, pwr / 2);
      wSum += w;
      uSum += w * p.u;
      vSum += w * p.v;
    }
    if (wSum <= 0) return [0, 0];
    return [uSum / wSum, vSum / wSum];
  }

  function latLngToGameIdw(lat, lng, cfg) {
    const mapRangeX = cfg.maxX - cfg.minX || 1;
    const mapRangeY = cfg.maxY - cfg.minY || 1;
    const ox = cfg.offsetX || 0;
    const oy = cfg.offsetY || 0;
    const scaleX = cfg.scaleX || 1;
    const scaleY = cfg.scaleY || 1;
    const targetU = (Number(lng) - ox - cfg.minX) / (mapRangeX * scaleX);
    const targetV = (cfg.maxY - (Number(lat) - oy)) / (mapRangeY * scaleY);
    const pts = cfg.idwPoints;
    const power = cfg.idwPower || 2;
    const rangeX = cfg.coordMaxX - cfg.coordMinX || 1;
    const rangeY = cfg.coordMaxY - cfg.coordMinY || 1;
    let x = cfg.coordMinX + targetU * rangeX;
    let y = cfg.maxY - targetV * rangeY;
    for (let i = 0; i < 28; i += 1) {
      const uv = idwGameToNorm(x, y, pts, power);
      const du = targetU - uv[0];
      const dv = targetV - uv[1];
      if (Math.abs(du) < 1e-6 && Math.abs(dv) < 1e-6) break;
      const eps = 18;
      const uvx = idwGameToNorm(x + eps, y, pts, power);
      const uvy = idwGameToNorm(x, y + eps, pts, power);
      const duDx = (uvx[0] - uv[0]) / eps;
      const duDy = (uvy[0] - uv[0]) / eps;
      const dvDx = (uvx[1] - uv[1]) / eps;
      const dvDy = (uvy[1] - uv[1]) / eps;
      const det = duDx * dvDy - duDy * dvDx;
      if (Math.abs(det) < 1e-14) break;
      x += (du * dvDy - dv * duDy) / det;
      y += (dv * duDx - du * dvDx) / det;
    }
    return { x, y };
  }

  /** Projekcinė transformacija (gx,gy) → (u,v) — tiksliau nei afini ant kvadratinio PNG. */
  function fitHomographyGameToNorm(points) {
    const rows = [];
    const rhs = [];
    points.forEach((p) => {
      const { gx, gy, u, v } = p;
      rows.push([gx, gy, 1, 0, 0, 0, -u * gx, -u * gy]);
      rhs.push(u);
      rows.push([0, 0, 0, gx, gy, 1, -v * gx, -v * gy]);
      rhs.push(v);
    });
    if (rows.length < 8) return null;
    return solveLs(rows, rhs);
  }

  /**
   * Kalibracija: žinomos vietos ant PNG (u,v ∈ [0,1], v=0 šiaurė).
   * Afini transformacija (gx,gy) → (u,v) — tiksliau nei atskiri X/Y linijiniai fit'ai.
   */
  function calibrationTargets(points, cfg) {
    const mapRangeX = cfg.maxX - cfg.minX || 1;
    const mapRangeY = cfg.maxY - cfg.minY || 1;
    const clean = [];
    points.forEach((p) => {
      const px = num(p.gx, NaN);
      const py = num(p.gy, NaN);
      const pu = num(p.u, NaN);
      const pv = num(p.v, NaN);
      if (!Number.isFinite(px) || !Number.isFinite(py) || !Number.isFinite(pu) || !Number.isFinite(pv)) return;
      clean.push({
        gx: px,
        gy: py,
        lng: cfg.minX + pu * mapRangeX,
        lat: cfg.maxY - pv * mapRangeY,
      });
    });
    return clean;
  }

  function applyCalibration(cfg, points) {
    if (!Array.isArray(points) || points.length < 3) return cfg;

    const clean = [];
    points.forEach((p) => {
      const px = num(p.gx, NaN);
      const py = num(p.gy, NaN);
      const pu = num(p.u, NaN);
      const pv = num(p.v, NaN);
      if (!Number.isFinite(px) || !Number.isFinite(py) || !Number.isFinite(pu) || !Number.isFinite(pv)) return;
      clean.push({ gx: px, gy: py, u: pu, v: pv });
    });

    if (clean.length < 3) return cfg;

    const projection = String(cfg.projection || "identity").toLowerCase();
    if (projection === "idw" && clean.length >= 3) {
      cfg.idwPoints = clean;
      cfg.idwPower = num(cfg.idwPower, 2);
      return cfg;
    }

    if (projection === "homography" && clean.length >= 4) {
      const homographyH = fitHomographyGameToNorm(clean);
      if (homographyH) {
        cfg.homographyH = homographyH;
        return cfg;
      }
    }

    const coeffsU = fitAffineGameToNorm(clean, "u");
    const coeffsV = fitAffineGameToNorm(clean, "v");
    if (!coeffsU || !coeffsV) return cfg;

    cfg.affineU = coeffsU;
    cfg.affineV = coeffsV;
    return cfg;
  }

  function gameToNormUV(gx, gy, cfg) {
    if (cfg.idwPoints && cfg.idwPoints.length >= 3) {
      return idwGameToNorm(gx, gy, cfg.idwPoints, cfg.idwPower);
    }

    if (cfg.homographyH && cfg.homographyH.length >= 8) {
      const h = cfg.homographyH;
      const den = h[6] * gx + h[7] * gy + 1;
      if (Math.abs(den) < 1e-12) return [0, 0];
      return [
        (h[0] * gx + h[1] * gy + h[2]) / den,
        (h[3] * gx + h[4] * gy + h[5]) / den,
      ];
    }

    if (cfg.affineU && cfg.affineV) {
      const u = cfg.affineU[0] * gx + cfg.affineU[1] * gy + cfg.affineU[2];
      const v = cfg.affineV[0] * gx + cfg.affineV[1] * gy + cfg.affineV[2];
      return [u, v];
    }

    const rangeX = cfg.coordMaxX - cfg.coordMinX || 1;
    const rangeY = cfg.coordMaxY - cfg.coordMinY || 1;
    let u = (gx - cfg.coordMinX) / rangeX;
    let v = (gy - cfg.coordMinY) / rangeY;
    if (cfg.flipY === true) v = 1 - v;
    return [Math.max(0, Math.min(1, u)), Math.max(0, Math.min(1, v))];
  }

  function normUVToGame(u, v, cfg) {
    if (cfg.affineU && cfg.affineV) {
      const rhsU = u - cfg.affineU[2];
      const rhsV = v - cfg.affineV[2];
      const a = cfg.affineU[0];
      const b = cfg.affineU[1];
      const c = cfg.affineV[0];
      const d = cfg.affineV[1];
      const det = a * d - b * c;
      if (Math.abs(det) < 1e-12) return { x: 0, y: 0 };
      return {
        x: (d * rhsU - b * rhsV) / det,
        y: (-c * rhsU + a * rhsV) / det,
      };
    }

    let tY = v;
    if (cfg.flipY === true) tY = 1 - tY;
    const rangeX = cfg.coordMaxX - cfg.coordMinX || 1;
    const rangeY = cfg.coordMaxY - cfg.coordMinY || 1;
    return {
      x: cfg.coordMinX + u * rangeX,
      y: cfg.coordMinY + tY * rangeY,
    };
  }

  function normalizeMapConfig(cfg, resourceName, defaultImageFile) {
    const t = cfg || {};
    const minX = num(t.gameMin?.x, ISLAND.gameMin.x);
    const minY = num(t.gameMin?.y, ISLAND.gameMin.y);
    const maxX = num(t.gameMax?.x, ISLAND.gameMax.x);
    const maxY = num(t.gameMax?.y, ISLAND.gameMax.y);
    const file = t.imageFile || defaultImageFile || "mdt/asset/gtav_satellite_2048.png";

    let projection = String(t.projection || "linear").toLowerCase();
    const hasCalibration = Array.isArray(t.calibration) && t.calibration.length >= 3;
    if (hasCalibration && (projection === "identity" || projection === "linear")) {
      projection = t.calibration.length >= 3 ? "idw" : "affine";
    }
    if (Array.isArray(t.homographyH) && t.homographyH.length >= 8) {
      projection = "homography";
    }

    const out = {
      projection,
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
      idwPower: num(t.idwPower, 2),
      imgW: num(t.imageWidth, ISLAND.imageWidth),
      imgH: num(t.imageHeight, ISLAND.imageHeight),
      imageUrl: nuiImageUrl(file, resourceName),
    };

    if (Array.isArray(t.homographyH) && t.homographyH.length >= 8) {
      out.homographyH = t.homographyH.map((v) => num(v, 0));
    }

    if (hasCalibration) {
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

  /** GTA (x,y) → Leaflet [lat, lng] — lat=Y, lng=X. */
  function gameToLatLng(gx, gy, cfg) {
    if (!cfg) return [Number(gy) || 0, Number(gx) || 0];
    const x = Number(gx);
    const y = Number(gy);
    if (!Number.isFinite(x) || !Number.isFinite(y)) {
      return [cfg.minY + (cfg.offsetY || 0), cfg.minX + (cfg.offsetX || 0)];
    }

    const ox = cfg.offsetX || 0;
    const oy = cfg.offsetY || 0;
    const projection = String(cfg.projection || "identity").toLowerCase();

    if (projection === "identity") {
      return [y + oy, x + ox];
    }

    const scaleX = cfg.scaleX || 1;
    const scaleY = cfg.scaleY || 1;
    const mapRangeX = cfg.maxX - cfg.minX || 1;
    const mapRangeY = cfg.maxY - cfg.minY || 1;

    if (
      (projection === "affine" || projection === "homography" || projection === "idw") &&
      (cfg.affineU || cfg.homographyH || cfg.idwPoints)
    ) {
      const uv = gameToNormUV(x, y, cfg);
      const lng = cfg.minX + uv[0] * mapRangeX * scaleX + ox;
      const lat = cfg.maxY - uv[1] * mapRangeY * scaleY + oy;
      return [lat, lng];
    }

    const uv = gameToNormUV(x, y, cfg);
    const lng = cfg.minX + uv[0] * mapRangeX * scaleX + ox;
    const lat = cfg.maxY - uv[1] * mapRangeY * scaleY + oy;
    return [lat, lng];
  }

  function latLngToGame(lat, lng, cfg) {
    if (!cfg) return { x: Number(lng) || 0, y: Number(lat) || 0 };
    const ox = cfg.offsetX || 0;
    const oy = cfg.offsetY || 0;
    const projection = String(cfg.projection || "identity").toLowerCase();

    if (projection === "identity") {
      return { x: Number(lng) - ox, y: Number(lat) - oy };
    }

    const mapRangeX = cfg.maxX - cfg.minX || 1;
    const mapRangeY = cfg.maxY - cfg.minY || 1;
    const scaleX = cfg.scaleX || 1;
    const scaleY = cfg.scaleY || 1;
    if (cfg.idwPoints && cfg.idwPoints.length >= 3) {
      return latLngToGameIdw(lat, lng, cfg);
    }

    let u = (Number(lng) - ox - cfg.minX) / (mapRangeX * scaleX);
    let v = (cfg.maxY - (Number(lat) - oy)) / (mapRangeY * scaleY);
    return normUVToGame(u, v, cfg);
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
