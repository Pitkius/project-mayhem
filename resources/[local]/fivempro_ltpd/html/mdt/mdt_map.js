/** LTPD MDT GPS žemėlapis — Leaflet + smooth blip tracking */
window.MdtMap = (function () {
  const LERP_SPEED = 7;
  const CALL_ACTIVE = new Set(['pending', 'accepted', 'enroute', 'arrived']);

  let leafletMap = null;
  let imageLayer = null;
  let mapCfg = null;
  let baseFitZoom = 0;
  let mapBounds = null;
  let animFrame = null;
  let lastFrame = 0;
  let animEnabled = false;
  let selfSource = null;
  let lastCalls = [];
  let onSelectCb = null;

  const unitState = {};
  const callState = {};
  let tooltipEl = null;
  let selectedKey = null;

  const Core = window.GtavMapCore;

  function resourceName() {
    try {
      if (typeof GetParentResourceName === 'function') return GetParentResourceName();
    } catch (e) {}
    return 'fivempro_ltpd';
  }

  function normalizeMapConfig(cfg) {
    if (!Core) return cfg || {};
    return Core.normalizeMapConfig(cfg, resourceName(), 'mdt/asset/gtav_satellite_2048.png');
  }

  /** GTA koordinatės → Leaflet [lat, lng] (CRS.Simple: lat=Y, lng=X). */
  function gameToLatLng(gx, gy, cfg) {
    return [Number(gy) + cfg.offsetY, Number(gx) + cfg.offsetX];
  }

  function latLngToGame(lat, lng, cfg) {
    return { x: Number(lng) - cfg.offsetX, y: Number(lat) - cfg.offsetY };
  }

  function escapeHtml(s) {
    return String(s ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function unitKey(u) {
    return `u:${u.source}`;
  }

  function callKey(c) {
    return `c:${c.id}`;
  }

  function unitBlipClass(u) {
    const parts = ['mdt-blip'];
    if (u.panic) parts.push('panic');
    else if (u.isCrewLeader) parts.push('leader');
    else parts.push('officer');
    if (u.inVeh) parts.push('in-veh');
    return parts.join(' ');
  }

  function callBlipClass(c) {
    const parts = ['mdt-blip', 'call'];
    if (c.panic) parts.push('panic');
    else if (c.status === 'arrived') parts.push('arrived');
    else parts.push('dispatch');
    return parts.join(' ');
  }

  function makeDivIcon(className, heading) {
    const rot = Number(heading) || 0;
    return L.divIcon({
      className: 'mdt-blip-icon',
      html: `<div class="${className}" style="--hdg:${rot}deg"></div>`,
      iconSize: [28, 28],
      iconAnchor: [14, 14],
    });
  }

  function ensureTooltip() {
    if (tooltipEl) return tooltipEl;
    tooltipEl = document.createElement('div');
    tooltipEl.id = 'mdtMapTooltip';
    tooltipEl.className = 'mdt-map-tooltip';
    document.body.appendChild(tooltipEl);
    return tooltipEl;
  }

  function hideTooltip() {
    if (tooltipEl) tooltipEl.classList.remove('is-visible');
  }

  function showTooltip(html, clientX, clientY) {
    const el = ensureTooltip();
    el.innerHTML = html;
    el.style.left = `${Math.min(window.innerWidth - 240, clientX + 16)}px`;
    el.style.top = `${Math.min(window.innerHeight - 120, clientY + 16)}px`;
    el.classList.add('is-visible');
  }

  function unitTooltipHtml(u) {
    return `
      <div class="tt-title">${escapeHtml(u.name || 'Pareigūnas')}</div>
      <div class="tt-row"><span>Pareigūnas</span><strong>${escapeHtml(u.name || '—')}</strong></div>
      <div class="tt-row"><span>Ekipažas</span><strong>${escapeHtml(u.crewLabel || '—')}</strong></div>
      <div class="tt-row"><span>Statusas</span><strong>${escapeHtml(u.statusLabel || 'Patruliuoja')}</strong></div>
      <div class="tt-row"><span>Koordinatės</span><strong>${Number(u.x || 0).toFixed(1)} ${Number(u.y || 0).toFixed(1)} ${Number(u.z || 0).toFixed(1)}</strong></div>
    `;
  }

  function callTooltipHtml(c) {
    return `
      <div class="tt-title">${escapeHtml(c.callTypeLabel || c.callType || 'Iškvietimas')}</div>
      <div class="tt-row"><span>ID</span><strong>${escapeHtml(c.id || '—')}</strong></div>
      <div class="tt-row"><span>Statusas</span><strong>${escapeHtml(c.statusLabel || c.status || '—')}</strong></div>
      <div class="tt-row"><span>Koordinatės</span><strong>${Number(c.x || 0).toFixed(1)} ${Number(c.y || 0).toFixed(1)} ${Number(c.z || 0).toFixed(1)}</strong></div>
    `;
  }

  function bindMarkerEvents(marker, key, kind, dataRef) {
    marker.on('mouseover', (e) => {
      const d = dataRef();
      if (!d) return;
      showTooltip(kind === 'unit' ? unitTooltipHtml(d) : callTooltipHtml(d), e.originalEvent.clientX, e.originalEvent.clientY);
    });
    marker.on('mousemove', (e) => {
      if (!tooltipEl?.classList.contains('is-visible')) return;
      tooltipEl.style.left = `${Math.min(window.innerWidth - 240, e.originalEvent.clientX + 16)}px`;
      tooltipEl.style.top = `${Math.min(window.innerHeight - 120, e.originalEvent.clientY + 16)}px`;
    });
    marker.on('mouseout', hideTooltip);
    marker.on('click', () => {
      selectedKey = key;
      syncSelectionStyles();
      if (onSelectCb) onSelectCb(kind, dataRef());
    });
  }

  function syncSelectionStyles() {
    Object.values(unitState).forEach((s) => {
      const el = s.marker.getElement()?.querySelector('.mdt-blip');
      if (el) el.classList.toggle('selected', selectedKey === s.key);
    });
    Object.values(callState).forEach((s) => {
      const el = s.marker.getElement()?.querySelector('.mdt-blip');
      if (el) el.classList.toggle('selected', selectedKey === s.key);
    });
  }

  function removeStale(stateMap, keepKeys) {
    Object.keys(stateMap).forEach((k) => {
      if (keepKeys.has(k)) return;
      const s = stateMap[k];
      if (s.marker && leafletMap) leafletMap.removeLayer(s.marker);
      delete stateMap[k];
    });
  }

  function applyMarkerPosition(s) {
    s.curLat = s.tgtLat;
    s.curLng = s.tgtLng;
    if (s.marker) s.marker.setLatLng([s.curLat, s.curLng]);
  }

  function upsertUnit(u, cfg) {
    const key = unitKey(u);
    const [lat, lng] = gameToLatLng(u.x, u.y, cfg);
    let s = unitState[key];
    if (!s) {
      const marker = L.marker([lat, lng], {
        icon: makeDivIcon(unitBlipClass(u), u.heading),
        interactive: true,
        zIndexOffset: u.panic ? 900 : u.isCrewLeader ? 600 : 400,
      }).addTo(leafletMap);
      s = {
        key,
        marker,
        curLat: lat,
        curLng: lng,
        tgtLat: lat,
        tgtLng: lng,
        data: { ...u },
      };
      unitState[key] = s;
      bindMarkerEvents(marker, key, 'unit', () => s.data);
    }
    s.tgtLat = lat;
    s.tgtLng = lng;
    s.data = { ...u };
    s.marker.setIcon(makeDivIcon(unitBlipClass(u), u.heading));
    s.marker.setZIndexOffset(u.panic ? 900 : u.isCrewLeader ? 600 : 400);
    if (!animEnabled) applyMarkerPosition(s);
  }

  function upsertCall(c, cfg) {
    const key = callKey(c);
    const [lat, lng] = gameToLatLng(c.x, c.y, cfg);
    let s = callState[key];
    if (!s) {
      const marker = L.marker([lat, lng], {
        icon: makeDivIcon(callBlipClass(c), 0),
        interactive: true,
        zIndexOffset: c.panic ? 950 : 500,
      }).addTo(leafletMap);
      s = {
        key,
        marker,
        curLat: lat,
        curLng: lng,
        tgtLat: lat,
        tgtLng: lng,
        data: { ...c },
      };
      callState[key] = s;
      bindMarkerEvents(marker, key, 'call', () => s.data);
    }
    s.tgtLat = lat;
    s.tgtLng = lng;
    s.data = { ...c };
    s.marker.setIcon(makeDivIcon(callBlipClass(c), 0));
    s.marker.setZIndexOffset(c.panic ? 950 : 500);
    if (!animEnabled) applyMarkerPosition(s);
  }

  function lerp(a, b, t) {
    return a + (b - a) * t;
  }

  function startAnimLoop() {
    if (animFrame || !animEnabled) return;
    lastFrame = performance.now();
    const tick = (now) => {
      if (!animEnabled) {
        animFrame = null;
        return;
      }
      const dt = Math.min(0.12, (now - lastFrame) / 1000);
      lastFrame = now;
      const alpha = 1 - Math.exp(-dt * LERP_SPEED);
      const all = [...Object.values(unitState), ...Object.values(callState)];
      all.forEach((s) => {
        s.curLat = lerp(s.curLat, s.tgtLat, alpha);
        s.curLng = lerp(s.curLng, s.tgtLng, alpha);
        s.marker.setLatLng([s.curLat, s.curLng]);
      });
      animFrame = requestAnimationFrame(tick);
    };
    animFrame = requestAnimationFrame(tick);
  }

  function stopAnimLoop() {
    if (animFrame) cancelAnimationFrame(animFrame);
    animFrame = null;
  }

  function setAnimEnabled(on) {
    animEnabled = on === true;
    if (animEnabled) startAnimLoop();
    else stopAnimLoop();
  }

  function fitMapFill(pad) {
    if (!leafletMap || !mapCfg || !Core) return;
    const r = Core.fitIslandView(leafletMap, mapCfg, { padding: pad || 12, maxZoom: 3 });
    baseFitZoom = r.baseFitZoom;
    mapBounds = Core.gameBoundsLatLng(mapCfg);
  }

  function ensureMap(cfg) {
    mapCfg = normalizeMapConfig(cfg);
    const el = document.getElementById('mdtLeafletMap');
    if (!el || typeof L === 'undefined' || !Core) return;

    mapBounds = Core.gameBoundsLatLng(mapCfg);

    if (!leafletMap) {
      leafletMap = L.map(el, Core.createLeafletOptions());
      leafletMap.on('moveend', () => {
        const vb = Core.viewBoundsLatLng(mapCfg) || mapBounds;
        if (vb) leafletMap.panInsideBounds(vb, { animate: false });
      });
    }

    if (imageLayer) leafletMap.removeLayer(imageLayer);
    imageLayer = Core.addSatelliteLayer(leafletMap, mapCfg, 'mdt-sat-layer');

    Core.scheduleInvalidate(leafletMap, [0, 120, 320]);
    requestAnimationFrame(() => fitMapFill(12));
    setTimeout(() => fitMapFill(12), 150);
  }

  function invalidate() {
    if (leafletMap) leafletMap.invalidateSize({ animate: false });
  }

  function enrichUnits(units, crews) {
    const crewById = {};
    (crews || []).forEach((c) => {
      crewById[c.crewId] = c;
    });
    return (units || []).map((u) => {
      const crew = u.crewId ? crewById[u.crewId] : null;
      const crewLabel = crew
        ? (crew.callsign ? crew.callsign : `Ekipažas #${crew.crewNumber || '—'}`)
        : '—';
      return { ...u, crewLabel };
    });
  }

  function activeCalls(calls) {
    return (calls || []).filter((c) => {
      const st = String(c.status || '').toLowerCase();
      return CALL_ACTIVE.has(st) || c.panic;
    });
  }

  function update(payload) {
    if (!leafletMap || !mapCfg) return;
    const units = enrichUnits(payload.units, payload.crews);
    const calls = activeCalls(payload.calls);
    lastCalls = calls;
    if (payload.selfSource != null) selfSource = payload.selfSource;

    const keepU = new Set();
    units.forEach((u) => {
      const k = unitKey(u);
      keepU.add(k);
      upsertUnit(u, mapCfg);
    });
    removeStale(unitState, keepU);

    const keepC = new Set();
    calls.forEach((c) => {
      const k = callKey(c);
      keepC.add(k);
      upsertCall(c, mapCfg);
    });
    removeStale(callState, keepC);
    syncSelectionStyles();
  }

  function centerOnLatLng(lat, lng, zoomDelta) {
    if (!leafletMap) return;
    leafletMap.flyTo([lat, lng], Math.min(leafletMap.getMaxZoom(), leafletMap.getZoom() + (zoomDelta || 1.2)), {
      animate: true,
      duration: 0.55,
    });
  }

  function centerOnPlayer() {
    if (!selfSource) return false;
    const s = unitState[`u:${selfSource}`];
    if (!s) return false;
    centerOnLatLng(s.curLat, s.curLng, 1.4);
    return true;
  }

  function centerOnActiveCall() {
    const panic = lastCalls.find((c) => c.panic);
    const call = panic || lastCalls[0];
    if (!call) return false;
    const s = callState[callKey(call)];
    if (s) centerOnLatLng(s.curLat, s.curLng, 1.2);
    else {
      const [lat, lng] = gameToLatLng(call.x, call.y, mapCfg);
      centerOnLatLng(lat, lng, 1.2);
    }
    return true;
  }

  function resetView() {
    fitMapFill(6);
  }

  function zoomIn() {
    if (leafletMap) leafletMap.zoomIn(0.45);
  }

  function zoomOut() {
    if (leafletMap) leafletMap.zoomOut(0.45);
  }

  function setOnSelect(cb) {
    onSelectCb = cb;
  }

  function selectByKey(key) {
    selectedKey = key;
    syncSelectionStyles();
  }

  function destroy() {
    animEnabled = false;
    stopAnimLoop();
    hideTooltip();
    Object.values(unitState).forEach((s) => leafletMap?.removeLayer(s.marker));
    Object.values(callState).forEach((s) => leafletMap?.removeLayer(s.marker));
    Object.keys(unitState).forEach((k) => delete unitState[k]);
    Object.keys(callState).forEach((k) => delete callState[k]);
    if (leafletMap) {
      leafletMap.remove();
      leafletMap = null;
    }
    imageLayer = null;
    selectedKey = null;
  }

  return {
    ensureMap,
    update,
    invalidate,
    resetView,
    zoomIn,
    zoomOut,
    centerOnPlayer,
    centerOnActiveCall,
    setOnSelect,
    selectByKey,
    setAnimEnabled,
    destroy,
    gameToLatLng: (x, y) => gameToLatLng(x, y, mapCfg),
  };
})();
