/** LTPD MDT GPS žemėlapis — Leaflet + IDW kalibracija. */
window.MdtMap = (function () {
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
  let localPlayerPos = null;
  let lastCalls = [];
  let onSelectCb = null;

  const unitState = {};
  const callState = {};
  let tooltipEl = null;
  let selectedKey = null;
  let selfMarker = null;
  let selfHeading = 0;
  let routeLayer = null;
  let routeDest = null;
  let crewsVisible = true;

  const Core = window.GtavMapCore;

  function resourceName() {
    try {
      if (typeof GetParentResourceName === 'function') return GetParentResourceName();
    } catch (e) {}
    return 'fivempro_service_mdt';
  }

  function normalizeMapConfig(cfg) {
    if (!Core) return cfg || {};
    return Core.normalizeMapConfig(cfg, resourceName(), 'mdt/asset/gtav_satellite_2048.png');
  }

  function gameToLatLng(gx, gy, cfg) {
    if (Core && Core.gameToLatLng) return Core.gameToLatLng(gx, gy, cfg);
    return [Number(gy) + (cfg.offsetY || 0), Number(gx) + (cfg.offsetX || 0)];
  }

  function latLngToGame(lat, lng, cfg) {
    if (Core && Core.latLngToGame) return Core.latLngToGame(lat, lng, cfg);
    return { x: Number(lng) - (cfg.offsetX || 0), y: Number(lat) - (cfg.offsetY || 0) };
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
    else if (crewsVisible && u.isCrewLeader) parts.push('leader');
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
    const crewRow = crewsVisible
      ? `<div class="tt-row"><span>Ekipažas</span><strong>${escapeHtml(u.crewLabel || '—')}</strong></div>`
      : '';
    return `
      <div class="tt-title">${escapeHtml(u.name || 'Pareigūnas')}</div>
      <div class="tt-row"><span>Pareigūnas</span><strong>${escapeHtml(u.name || '—')}</strong></div>
      ${crewRow}
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

  function clearRoute() {
    if (routeLayer && leafletMap) {
      leafletMap.removeLayer(routeLayer);
    }
    routeLayer = null;
    routeDest = null;
  }

  function drawRouteTo(destX, destY) {
    clearRoute();
    if (!leafletMap || !mapCfg || !localPlayerPos) return false;
    const dx = Number(destX);
    const dy = Number(destY);
    if (!Number.isFinite(dx) || !Number.isFinite(dy)) return false;
    const from = gameToLatLng(localPlayerPos.x, localPlayerPos.y, mapCfg);
    const to = gameToLatLng(dx, dy, mapCfg);
    routeDest = { x: dx, y: dy };
    routeLayer = L.polyline([from, to], {
      color: '#60a5fa',
      weight: 3,
      opacity: 0.9,
      dashArray: '10 8',
      lineCap: 'round',
      lineJoin: 'round',
      interactive: false,
    }).addTo(leafletMap);
    return true;
  }

  function refreshRoute() {
    if (!routeDest || !localPlayerPos) return;
    drawRouteTo(routeDest.x, routeDest.y);
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

  function removeSelfUnitMarker() {
    if (selfSource == null) return;
    const key = `u:${selfSource}`;
    const s = unitState[key];
    if (!s) return;
    if (leafletMap) leafletMap.removeLayer(s.marker);
    delete unitState[key];
  }

  function upsertUnit(u, cfg) {
    if (selfSource != null && Number(u.source) === Number(selfSource)) {
      removeSelfUnitMarker();
      return;
    }
    const key = unitKey(u);
    const [lat, lng] = gameToLatLng(u.x, u.y, cfg);
    let s = unitState[key];
    if (!s) {
      const marker = L.marker([lat, lng], {
        icon: makeDivIcon(unitBlipClass(u), u.heading),
        interactive: true,
        zIndexOffset: u.panic ? 900 : (crewsVisible && u.isCrewLeader) ? 600 : 400,
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
    s.marker.setZIndexOffset(u.panic ? 900 : (crewsVisible && u.isCrewLeader) ? 600 : 400);
    applyMarkerPosition(s);
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
    applyMarkerPosition(s);
  }

  function stopAnimLoop() {
    if (animFrame) cancelAnimationFrame(animFrame);
    animFrame = null;
  }

  function setAnimEnabled(_on) {
    animEnabled = false;
    stopAnimLoop();
  }

  function fitMapFill(pad) {
    if (!leafletMap || !mapCfg || !Core) return;
    const r = Core.fitIslandView(leafletMap, mapCfg, { padding: pad || 12, maxZoom: 3 });
    baseFitZoom = r.baseFitZoom;
    mapBounds = Core.gameBoundsLatLng(mapCfg);
  }

  function reprojectMarkers() {
    if (!mapCfg) return;
    Object.values(unitState).forEach((s) => {
      if (!s.data || s.data.x == null || s.data.y == null) return;
      const [lat, lng] = gameToLatLng(s.data.x, s.data.y, mapCfg);
      s.tgtLat = lat;
      s.tgtLng = lng;
      applyMarkerPosition(s);
    });
    Object.values(callState).forEach((s) => {
      if (!s.data || s.data.x == null || s.data.y == null) return;
      const [lat, lng] = gameToLatLng(s.data.x, s.data.y, mapCfg);
      s.tgtLat = lat;
      s.tgtLng = lng;
      applyMarkerPosition(s);
    });
    if (localPlayerPos && selfSource != null) {
      syncSelfMarker();
    }
    refreshRoute();
  }

  function ensureMap(cfg) {
    mapCfg = normalizeMapConfig(cfg);
    const el = document.getElementById('mdtLeafletMap');
    if (!el || typeof L === 'undefined' || !Core) return;

    mapBounds = Core.gameBoundsLatLng(mapCfg);

    if (!leafletMap) {
      leafletMap = L.map(el, Core.createLeafletOptions());
    }

    if (imageLayer) leafletMap.removeLayer(imageLayer);
    imageLayer = Core.addSatelliteLayer(leafletMap, mapCfg, 'mdt-sat-layer');

    Core.scheduleInvalidate(leafletMap, [0, 120, 320]);
    requestAnimationFrame(() => {
      fitMapFill(12);
      reprojectMarkers();
      syncSelfMarker();
    });
    setTimeout(() => {
      fitMapFill(12);
      reprojectMarkers();
      syncSelfMarker();
    }, 150);
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

  function applyLocalPlayerToUnits(units) {
    if (!selfSource || !localPlayerPos) return units;
    const sid = Number(selfSource);
    let found = false;
    const merged = (units || []).map((u) => {
      if (Number(u.source) !== sid) return u;
      found = true;
      return {
        ...u,
        x: localPlayerPos.x,
        y: localPlayerPos.y,
        z: localPlayerPos.z != null ? localPlayerPos.z : u.z,
        heading: localPlayerPos.heading != null ? localPlayerPos.heading : u.heading,
      };
    });
    if (!found) {
      merged.push({
        source: sid,
        name: 'Tu',
        callsign: '',
        x: localPlayerPos.x,
        y: localPlayerPos.y,
        z: localPlayerPos.z,
        heading: localPlayerPos.heading || 0,
        statusLabel: 'Patruliuoja',
        crewLabel: '—',
        gpsActive: true,
        inVeh: false,
        panic: false,
        isCrewLeader: false,
      });
    }
    return merged;
  }

  function setSelfSource(src) {
    if (src == null || src === '') return;
    const next = Number(src);
    if (next === selfSource) return;
    if (selfSource != null) removeSelfUnitMarker();
    selfSource = next;
    removeSelfUnitMarker();
  }

  function localPlayerUnit() {
    if (!localPlayerPos || selfSource == null) return null;
    const key = `u:${selfSource}`;
    const existing = unitState[key];
    return {
      ...(existing?.data || {}),
      source: selfSource,
      name: existing?.data?.name || 'Tu',
      callsign: existing?.data?.callsign || '',
      x: localPlayerPos.x,
      y: localPlayerPos.y,
      z: localPlayerPos.z,
      heading: localPlayerPos.heading,
      statusLabel: existing?.data?.statusLabel || 'Patruliuoja',
      crewLabel: existing?.data?.crewLabel || '—',
      gpsActive: true,
      inVeh: existing?.data?.inVeh || false,
      panic: existing?.data?.panic || false,
      isCrewLeader: existing?.data?.isCrewLeader || false,
    };
  }

  function syncSelfMarker() {
    if (!leafletMap || !mapCfg || !localPlayerPos) return;
    const [lat, lng] = gameToLatLng(localPlayerPos.x, localPlayerPos.y, mapCfg);
    selfHeading = localPlayerPos.heading != null ? Number(localPlayerPos.heading) : selfHeading;
    if (!selfMarker) {
      selfMarker = L.marker([lat, lng], {
        icon: makeDivIcon('mdt-blip self', selfHeading),
        interactive: false,
        zIndexOffset: 1200,
      }).addTo(leafletMap);
      return;
    }
    selfMarker.setLatLng([lat, lng]);
    selfMarker.setIcon(makeDivIcon('mdt-blip self', selfHeading));
  }

  function setLocalPlayerPos(pos) {
    if (!pos || pos.x == null || pos.y == null) return;
    if (pos.selfSource != null) setSelfSource(pos.selfSource);
    localPlayerPos = {
      x: Number(pos.x),
      y: Number(pos.y),
      z: pos.z != null ? Number(pos.z) : 0,
      heading: pos.heading != null ? Number(pos.heading) : 0,
    };
    syncSelfMarker();
    refreshRoute();
  }

  function update(payload) {
    if (!leafletMap || !mapCfg) return;
    if (payload.selfSource != null) setSelfSource(payload.selfSource);
    const units = applyLocalPlayerToUnits(enrichUnits(payload.units, payload.crews));
    const calls = activeCalls(payload.calls);
    lastCalls = calls;

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
    syncSelfMarker();
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
    if (localPlayerPos && leafletMap && mapCfg) {
      syncSelfMarker();
      const [lat, lng] = gameToLatLng(localPlayerPos.x, localPlayerPos.y, mapCfg);
      centerOnLatLng(lat, lng, 1.4);
      return true;
    }
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
    clearRoute();
    if (selfMarker && leafletMap) leafletMap.removeLayer(selfMarker);
    selfMarker = null;
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

  function setCrewsVisible(on) {
    crewsVisible = on !== false;
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
    setCrewsVisible,
    setSelfSource,
    setLocalPlayerPos,
    setRoute: drawRouteTo,
    clearRoute,
    destroy,
    gameToLatLng: (x, y) => gameToLatLng(x, y, mapCfg),
  };
})();
