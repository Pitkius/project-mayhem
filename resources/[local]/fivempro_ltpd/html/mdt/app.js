const app = document.getElementById('app');
const btnClose = document.getElementById('btnClose');
let dispatchPoll = null;
const MAP_BOUNDS = { minX: -4000, maxX: 4500, minY: -4000, maxY: 8000 };
const MAP_IMG_W = 1066;
const MAP_IMG_H = 861;
function nuiImageUrl(pathFromHtml) {
  const raw = String(pathFromHtml || '').trim();
  if (!raw || /^https?:\/\//i.test(raw) || /^nui:\/\//i.test(raw)) return raw;
  const res = resourceName();
  let p = raw.replace(/^\/+/, '');
  if (!p.startsWith('html/')) p = `html/${p}`;
  return `nui://${res}/${p}`;
}

const MAP_SAT_URL = nuiImageUrl('mdt/asset/gtav_satellite.jpg');
const MAP_MIN_SCALE = 0.45;
const MAP_MAX_SCALE = 4.0;
const MAP_FIT_PAD = 0.98;

function resourceName() {
  try {
    if (typeof GetParentResourceName === 'function') return GetParentResourceName();
  } catch (e) {}
  return 'fivempro_ltpd';
}

function nuiPost(endpoint, data) {
  return fetch(`https://${resourceName()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
  }).then((r) => r.json());
}

window.addEventListener('message', (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === 'open') {
    app.classList.remove('hidden');
    mdtDocked = false;
    app.classList.remove('is-docked');
    const perms = (d.data && d.data.permissions) || {};
    document.getElementById('tabFine').style.display = perms.fine ? '' : 'none';
    document.getElementById('tabWant').style.display = perms.wanted ? '' : 'none';
    const tabArrests = document.getElementById('tabArrests');
    if (tabArrests) tabArrests.style.display = perms.arrest ? '' : 'none';
    document.getElementById('tabCctv').style.display = perms.cctv ? '' : 'none';
    document.getElementById('tabBodycam').style.display = perms.bodycam ? '' : 'none';
    const sel = document.getElementById('finePreset');
    sel.innerHTML = '';
    (d.data.presets || []).forEach((p) => {
      const o = document.createElement('option');
      o.value = p.code;
      o.textContent = `${p.label} (${p.defaultAmount} €)`;
      o.dataset.amount = p.defaultAmount;
      o.dataset.label = p.label;
      sel.appendChild(o);
    });
    sel.onchange = () => {
      const opt = sel.options[sel.selectedIndex];
      document.getElementById('fineAmt').value = opt.dataset.amount || '';
      document.getElementById('fineLabel').value = opt.dataset.label || '';
    };
    if (sel.options.length) sel.onchange();
    startDispatchPoll();
  }
  if (d.action === 'close') {
    app.classList.add('hidden');
    mdtDocked = false;
    app.classList.remove('is-docked');
    dispatchMapLayoutReady = false;
    stopDispatchPoll();
    stopSurveillanceUi();
  }
  if (d.action === 'dock') {
    setMdtDocked(true, true);
  }
  if (d.action === 'cctvOverlay') {
    const meta = [d.camId ? `ID ${d.camId}` : '', d.audio ? 'Garsas' : 'Be garso'].filter(Boolean).join(' • ');
    setSurveillanceOverlay(d.active, d.label || 'CCTV LIVE', meta, d);
    document.getElementById('cctvLiveHint').classList.toggle('hidden', !d.active);
    if (d.active && d.label) {
      document.getElementById('cctvStatus').textContent = d.label;
    }
  }
  if (d.action === 'bodycamOverlay') {
    setSurveillanceOverlay(d.active, 'BODYCAM LIVE', d.targetId ? `ID ${d.targetId}` : '');
    document.getElementById('bodycamLiveHint').classList.toggle('hidden', !d.active);
  }
});

btnClose.onclick = () => nuiPost('close', {});

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    e.preventDefault();
    nuiPost('close', {});
  }
});

document.querySelectorAll('.tab').forEach((t) => {
  t.onclick = () => {
    document.querySelectorAll('.tab').forEach((x) => x.classList.remove('active'));
    t.classList.add('active');
    document.querySelectorAll('.panel').forEach((p) => p.classList.add('hidden'));
    const id = 'panel-' + t.dataset.tab;
    const pan = document.getElementById(id);
    if (pan) pan.classList.remove('hidden');
    if (t.dataset.tab === 'units') {
      ensureDispatchMapDom();
      watchDispatchMapResize();
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          const root = document.getElementById('dispatchMap');
          if (root && root.clientHeight < 80) {
            dispatchMapLayoutReady = false;
          }
          layoutDispatchMapCanvas();
          if (!dispatchMapLayoutReady) {
            dispatchMapLayoutReady = true;
            fitDispatchMapInView();
          } else {
            clampDispatchMapPan();
            applyDispatchMapTransform();
          }
          refreshDispatch();
        });
      });
    }
    if (t.dataset.tab === 'cctv') refreshCctvList();
    if (t.dataset.tab === 'bodycam') refreshBodycamList();
    if (t.dataset.tab !== 'cctv' && t.dataset.tab !== 'bodycam') {
      nuiPost('cctvStop', {});
      nuiPost('bodycamStop', {});
      stopSurveillanceUi();
    }
  };
});

document.getElementById('goPerson').onclick = () => {
  const q = document.getElementById('qPerson').value.trim();
  nuiPost('searchPerson', { query: q }).then((res) => renderPerson(res));
};

function renderPerson(res) {
  const el = document.getElementById('personResults');
  el.innerHTML = '';
  if (!res || !res.ok || !res.rows || !res.rows.length) {
    el.innerHTML = '<div class="muted">Nieko nerasta.</div>';
    return;
  }
  res.rows.forEach((r) => {
    const c = document.createElement('div');
    c.className = 'card';
    let html = `<h4>${escapeHtml(r.name || '')}</h4>`;
    html += `<div class="muted">citizenid: ${escapeHtml(r.citizenid)}`;
    if (r.player_id != null) html += ` • server ID: ${escapeHtml(String(r.player_id))}`;
    html += `</div>`;
    if (res.full && r.cash != null) {
      html += `<div>Grynieji: ${r.cash} € | Bankas: ${r.bank} €</div>`;
    }
    html += `<div>Paieškomumas: <strong>${r.wanted_level}</strong> ${escapeHtml(r.wanted_reason || '')}</div>`;
    if (res.full && r.vehicles && r.vehicles.length) {
      html += '<div class="muted">Transportas:</div><ul>';
      r.vehicles.forEach((v) => {
        html += `<li>${escapeHtml(v.plate)} — ${escapeHtml(v.vehicle)} (${v.state})</li>`;
      });
      html += '</ul>';
    }
    if (res.full && r.fines && r.fines.length) {
      html += '<div class="muted">Paskutinės baudos:</div><ul>';
      r.fines.forEach((f) => {
        html += `<li>${f.amount} € — ${escapeHtml(f.reason_label || '')}</li>`;
      });
      html += '</ul>';
    }
    c.innerHTML = html;
    el.appendChild(c);
  });
}

document.getElementById('goVeh').onclick = () => {
  const plate = document.getElementById('qPlate').value.trim();
  nuiPost('searchVehicle', { plate }).then((res) => {
    const el = document.getElementById('vehResults');
    el.innerHTML = '';
    if (!res || !res.ok || !res.row) {
      el.innerHTML = '<div class="muted">Nerasta.</div>';
      return;
    }
    const v = res.row;
    el.innerHTML = `<div class="card"><h4>${escapeHtml(v.plate)}</h4>
      <div>Modelis: ${escapeHtml(v.vehicle)}</div>
      <div>Savininkas: ${escapeHtml(v.owner_name)} (${escapeHtml(v.citizenid)})</div>
      <div>Statusas: ${escapeHtml(v.status)}</div></div>`;
  });
};

document.getElementById('goFine').onclick = () => {
  const preset = document.getElementById('finePreset');
  const opt = preset.options[preset.selectedIndex];
  nuiPost('issueFine', {
    citizenid: document.getElementById('fineCid').value.trim(),
    amount: Number(document.getElementById('fineAmt').value),
    reason_code: opt ? opt.value : '',
    reason_label: document.getElementById('fineLabel').value.trim(),
  });
};

document.getElementById('goWant').onclick = () => {
  nuiPost('setWanted', {
    citizenid: document.getElementById('wantCid').value.trim(),
    level: Number(document.getElementById('wantLvl').value),
    reason: document.getElementById('wantReason').value.trim(),
  });
};

function renderArrestHistory(res) {
  const el = document.getElementById('arrestResults');
  if (!el) return;
  el.innerHTML = '';
  if (!res || !res.ok || !res.rows || !res.rows.length) {
    el.innerHTML = '<div class="muted">Areštų istorijos nėra.</div>';
    return;
  }
  res.rows.forEach((a) => {
    const c = document.createElement('div');
    c.className = 'card';
    c.innerHTML = `<h4>${escapeHtml(a.created_at || '')}</h4>
      <div><strong>Priežastis:</strong> ${escapeHtml(a.reason || '—')}</div>
      <div><strong>Bausmė:</strong> ${escapeHtml(a.sentence || '—')}</div>
      <div class="muted">Pareigūnas: ${escapeHtml(a.officer_name || a.officer_citizenid || '—')}</div>
      ${a.detail_notes ? `<div>${escapeHtml(a.detail_notes)}</div>` : ''}`;
    el.appendChild(c);
  });
}

const arrestLoad = document.getElementById('arrestLoad');
if (arrestLoad) {
  arrestLoad.onclick = () => {
    const cid = document.getElementById('arrestCid').value.trim();
    if (!cid) return;
    nuiPost('getArrestHistory', { citizenid: cid }).then(renderArrestHistory);
  };
}

const arrestSave = document.getElementById('arrestSave');
if (arrestSave) {
  arrestSave.onclick = () => {
    const citizenid = document.getElementById('arrestCid').value.trim();
    if (!citizenid) return;
    nuiPost('addArrest', {
      citizenid,
      reason: document.getElementById('arrestReason').value.trim(),
      sentence: document.getElementById('arrestSentence').value.trim(),
      notes: document.getElementById('arrestNotes').value.trim(),
    }).then((res) => {
      if (res && res.ok) {
        document.getElementById('arrestNotes').value = '';
        nuiPost('getArrestHistory', { citizenid }).then(renderArrestHistory);
      }
    });
  };
}

function stopDispatchPoll() {
  if (dispatchPoll) {
    clearInterval(dispatchPoll);
    dispatchPoll = null;
  }
}

function startDispatchPoll() {
  stopDispatchPoll();
  refreshDispatch();
  dispatchPoll = setInterval(refreshDispatch, 2000);
}

function countObj(obj) {
  if (!obj || typeof obj !== 'object') return 0;
  return Object.keys(obj).length;
}

function callActions(callId) {
  return `
    <div class="row">
      <button class="btn js-dispatch" data-action="accept" data-callid="${escapeHtml(callId)}">Priimti</button>
      <button class="btn js-dispatch" data-action="enroute" data-callid="${escapeHtml(callId)}">Vykstu</button>
      <button class="btn js-dispatch" data-action="arrived" data-callid="${escapeHtml(callId)}">Atvykau</button>
      <button class="btn js-dispatch" data-action="done" data-callid="${escapeHtml(callId)}">Baigta</button>
      <button class="btn js-dispatch" data-action="reject" data-callid="${escapeHtml(callId)}">Atmesti</button>
    </div>
  `;
}

function resolveUnitNames(idMap, units) {
  const out = [];
  const list = units || [];
  Object.keys(idMap || {}).forEach((sid) => {
    const unit = list.find((u) => String(u.source) === String(sid));
    out.push(unit ? `${unit.callsign ? `[${unit.callsign}] ` : ''}${unit.name || `ID ${sid}`}` : `ID ${sid}`);
  });
  return out.length ? out.join(', ') : '-';
}

function worldToMap(x, y) {
  const px = ((Number(x || 0) - MAP_BOUNDS.minX) / (MAP_BOUNDS.maxX - MAP_BOUNDS.minX)) * 100;
  const py = (1 - ((Number(y || 0) - MAP_BOUNDS.minY) / (MAP_BOUNDS.maxY - MAP_BOUNDS.minY))) * 100;
  return {
    x: Math.max(0.2, Math.min(99.8, px)),
    y: Math.max(0.2, Math.min(99.8, py)),
  };
}

let dispatchMapPan = { x: 0, y: 0, scale: 1 };
let dispatchMapInteractBound = false;
let dispatchMapResizeObs = null;
let dispatchMapLayoutReady = false;
let mdtDocked = false;
let mdtDragBound = false;

function ensureDispatchMapDom() {
  const transform = document.getElementById('dispatchMapTransform');
  if (!transform || document.getElementById('dispatchMapSurface')) return;

  let markers = document.getElementById('dispatchMapMarkers');
  const inner = document.getElementById('dispatchMapInner');
  const surface = document.createElement('div');
  surface.id = 'dispatchMapSurface';
  surface.className = 'dispatch-map-surface';
  surface.style.backgroundImage = `url("${MAP_SAT_URL}")`;

  if (inner) inner.remove();
  if (!markers) {
    markers = document.createElement('div');
    markers.id = 'dispatchMapMarkers';
    markers.className = 'dispatch-map-markers';
  } else {
    markers.remove();
  }

  surface.appendChild(markers);
  transform.appendChild(surface);
}

function layoutDispatchMapCanvas() {
  const root = document.getElementById('dispatchMap');
  const surface = document.getElementById('dispatchMapSurface');
  if (!root || !surface) return;

  const cw = Math.max(320, root.clientWidth || 0);
  const ch = Math.max(240, root.clientHeight || 0);
  const imgAspect = MAP_IMG_W / MAP_IMG_H;
  const boxAspect = cw / ch;
  let w;
  let h;
  if (boxAspect > imgAspect) {
    h = ch;
    w = h * imgAspect;
  } else {
    w = cw;
    h = w / imgAspect;
  }
  surface.style.width = `${Math.round(w)}px`;
  surface.style.height = `${Math.round(h)}px`;
}

function clampDispatchMapPan() {
  const root = document.getElementById('dispatchMap');
  const surface = document.getElementById('dispatchMapSurface');
  if (!root || !surface) return;
  const cw = root.clientWidth;
  const ch = root.clientHeight;
  const sw = surface.offsetWidth * dispatchMapPan.scale;
  const sh = surface.offsetHeight * dispatchMapPan.scale;
  if (sw <= cw + 1 && sh <= ch + 1) {
    dispatchMapPan.x = 0;
    dispatchMapPan.y = 0;
    return;
  }
  const maxX = Math.max(0, (sw - cw) / 2);
  const maxY = Math.max(0, (sh - ch) / 2);
  dispatchMapPan.x = Math.max(-maxX, Math.min(maxX, dispatchMapPan.x));
  dispatchMapPan.y = Math.max(-maxY, Math.min(maxY, dispatchMapPan.y));
}

function fitDispatchMapInView() {
  const root = document.getElementById('dispatchMap');
  const surface = document.getElementById('dispatchMapSurface');
  if (!root || !surface) return;
  layoutDispatchMapCanvas();
  const cw = Math.max(1, root.clientWidth || 1);
  const ch = Math.max(1, root.clientHeight || 1);
  const sw = Math.max(1, surface.offsetWidth);
  const sh = Math.max(1, surface.offsetHeight);
  const fitScale = Math.min(cw / sw, ch / sh) * MAP_FIT_PAD;
  const panScale = Math.max(1.05, fitScale);
  dispatchMapPan.scale = Math.max(MAP_MIN_SCALE, Math.min(MAP_MAX_SCALE, panScale));
  dispatchMapPan.x = 0;
  dispatchMapPan.y = 0;
  applyDispatchMapTransform();
}

function watchDispatchMapResize() {
  const root = document.getElementById('dispatchMap');
  if (!root || dispatchMapResizeObs) return;
  dispatchMapResizeObs = new ResizeObserver(() => {
    if (document.getElementById('panel-units')?.classList.contains('hidden')) return;
    layoutDispatchMapCanvas();
    clampDispatchMapPan();
    applyDispatchMapTransform();
  });
  dispatchMapResizeObs.observe(root);
}

function applyDispatchMapTransform() {
  const layer = document.getElementById('dispatchMapTransform');
  if (!layer) return;
  layer.style.transform = `translate(calc(-50% + ${dispatchMapPan.x}px), calc(-50% + ${dispatchMapPan.y}px)) scale(${dispatchMapPan.scale})`;
}

function bindDispatchMapInteract() {
  if (dispatchMapInteractBound) return;
  const root = document.getElementById('dispatchMap');
  const layer = document.getElementById('dispatchMapTransform');
  if (!root || !layer) return;
  dispatchMapInteractBound = true;

  root.addEventListener(
    'wheel',
    (e) => {
      e.preventDefault();
      const delta = e.deltaY > 0 ? -0.1 : 0.1;
      dispatchMapPan.scale = Math.max(MAP_MIN_SCALE, Math.min(MAP_MAX_SCALE, dispatchMapPan.scale + delta));
      clampDispatchMapPan();
      applyDispatchMapTransform();
    },
    { passive: false },
  );

  let drag = false;
  let lx = 0;
  let ly = 0;
  root.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return;
    drag = true;
    lx = e.clientX;
    ly = e.clientY;
    root.style.cursor = 'grabbing';
  });
  window.addEventListener('mouseup', () => {
    if (!drag) return;
    drag = false;
    root.style.cursor = 'grab';
  });
  window.addEventListener('mousemove', (e) => {
    if (!drag) return;
    dispatchMapPan.x += e.clientX - lx;
    dispatchMapPan.y += e.clientY - ly;
    lx = e.clientX;
    ly = e.clientY;
    clampDispatchMapPan();
    applyDispatchMapTransform();
  });
}

function renderDispatchMap(calls, units) {
  if (document.getElementById('panel-units')?.classList.contains('hidden')) return;
  ensureDispatchMapDom();
  watchDispatchMapResize();
  layoutDispatchMapCanvas();
  const markers = document.getElementById('dispatchMapMarkers');
  if (!markers) return;
  markers.innerHTML = '';
  bindDispatchMapInteract();
  if (!dispatchMapLayoutReady) {
    dispatchMapLayoutReady = true;
    requestAnimationFrame(() => fitDispatchMapInView());
  } else {
    clampDispatchMapPan();
    applyDispatchMapTransform();
  }
  units.forEach((u) => {
    const p = worldToMap(u.x, u.y);
    const d = document.createElement('div');
    d.className = 'map-dot unit';
    d.style.left = `${p.x}%`;
    d.style.top = `${p.y}%`;
    d.textContent = `${u.callsign ? `[${u.callsign}] ` : ''}${u.name || 'Unit'}`;
    markers.appendChild(d);
  });
  calls.forEach((c) => {
    const p = worldToMap(c.x, c.y);
    const d = document.createElement('div');
    d.className = `map-dot call ${c.panic ? 'panic' : ''}`.trim();
    d.style.left = `${p.x}%`;
    d.style.top = `${p.y}%`;
    d.textContent = `${c.id} ${c.callTypeLabel || c.callType || 'Call'}`;
    markers.appendChild(d);
  });
}

(function bindDispatchMapZoomButtons() {
  const zIn = document.getElementById('dispatchZoomIn');
  const zOut = document.getElementById('dispatchZoomOut');
  if (zIn) {
    zIn.addEventListener('click', () => {
      dispatchMapPan.scale = Math.min(MAP_MAX_SCALE, dispatchMapPan.scale + 0.15);
      clampDispatchMapPan();
      applyDispatchMapTransform();
    });
  }
  if (zOut) {
    zOut.addEventListener('click', () => {
      dispatchMapPan.scale = Math.max(MAP_MIN_SCALE, dispatchMapPan.scale - 0.15);
      clampDispatchMapPan();
      applyDispatchMapTransform();
    });
  }
})();

function renderDispatch(res) {
  const callsEl = document.getElementById('dispatchCalls');
  const crewsEl = document.getElementById('dispatchCrews');
  const unitsEl = document.getElementById('dispatchUnits');
  callsEl.innerHTML = '';
  crewsEl.innerHTML = '';
  unitsEl.innerHTML = '';

  const calls = (res && res.calls) || [];
  const crews = (res && res.crews) || [];
  const units = (res && res.units) || [];

  if (!calls.length) {
    callsEl.innerHTML = '<div class="muted">Aktyvių iškvietimų nėra.</div>';
  } else {
    calls.forEach((c) => {
      const card = document.createElement('div');
      card.className = 'card';
      card.innerHTML = `
        <h4>[${escapeHtml(c.id)}] ${escapeHtml(c.callTypeLabel || c.callType || 'Kitas')}</h4>
        <div>Statusas: <strong>${escapeHtml(c.statusLabel || c.status || 'N/A')}</strong></div>
        <div>Lokacija: ${Number(c.x || 0).toFixed(1)}, ${Number(c.y || 0).toFixed(1)}</div>
        <div>Laikas: ${escapeHtml(c.createdAt || '')}</div>
        <div>Priėmė: ${resolveUnitNames(c.acceptedBy, units)}</div>
        <div>Vyksta: ${resolveUnitNames(c.enrouteBy, units)}</div>
        <div>Atvyko: ${resolveUnitNames(c.arrivedBy, units)}</div>
        ${c.panic ? `<div class="row"><button class="btn danger js-panic-off" data-callid="${escapeHtml(c.id)}">Išjungti PANIC</button></div>` : ''}
        ${callActions(c.id)}
      `;
      callsEl.appendChild(card);
    });
  }

  if (!crews.length) {
    crewsEl.innerHTML = '<div class="muted">Aktyvių ekipažų nėra.</div>';
  } else {
    crews.forEach((c) => {
      const card = document.createElement('div');
      card.className = 'card';
      const members = (c.members || []).map((m) => `${escapeHtml(m.name)} ${m.callsign ? `[${escapeHtml(m.callsign)}]` : ''}`).join(', ');
      card.innerHTML = `
        <h4>Ekipažas #${escapeHtml(String(c.crewNumber || 'N/A'))} ${c.callsign ? '[' + escapeHtml(c.callsign) + ']' : ''}</h4>
        <div>ID: <strong>${escapeHtml(c.crewId || '-')}</strong> | Vadas: ${escapeHtml(String(c.leader || '-'))}</div>
        <div>Statusas: ${escapeHtml(c.status || 'active')} | Priskirtas: ${escapeHtml(c.assignedCallId || '-')}</div>
        <div>Nariai: ${members || '-'}</div>
      `;
      crewsEl.appendChild(card);
    });
  }

  if (!units.length) {
    unitsEl.innerHTML = '<div class="muted">Pamainoje vienetų nėra.</div>';
  } else {
    units.forEach((u) => {
      const card = document.createElement('div');
      card.className = 'card';
      card.innerHTML = `
        <h4>${u.callsign ? '[' + escapeHtml(u.callsign) + ']' : ''} ${escapeHtml(u.name || 'Pareigūnas')}</h4>
        <div>Koord: ${Number(u.x || 0).toFixed(1)}, ${Number(u.y || 0).toFixed(1)}</div>
        <div>Ekipažas: ${escapeHtml(u.crewId || '-')}</div>
      `;
      unitsEl.appendChild(card);
    });
  }
  renderDispatchMap(calls, units);

  document.querySelectorAll('.js-dispatch').forEach((btn) => {
    btn.onclick = () => nuiPost('dispatchAction', { callId: btn.dataset.callid, action: btn.dataset.action }).then(() => refreshDispatch());
  });
  document.querySelectorAll('.js-panic-off').forEach((btn) => {
    btn.onclick = () => nuiPost('crewAction', { action: 'panicOff', callId: btn.dataset.callid }).then(() => refreshDispatch());
  });
}

function refreshDispatch() {
  return nuiPost('dispatchSnapshot', {}).then((res) => renderDispatch(res || { calls: [], crews: [], units: [] }));
}

document.getElementById('refreshDispatch').onclick = () => refreshDispatch();
document.getElementById('refreshDispatchMap').onclick = () => {
  ensureDispatchMapDom();
  fitDispatchMapInView();
  refreshDispatch();
};

window.addEventListener('resize', () => {
  if (!document.getElementById('panel-units')?.classList.contains('hidden')) {
    layoutDispatchMapCanvas();
    applyDispatchMapTransform();
  }
});

function setMdtDocked(docked, skipPost) {
  mdtDocked = !!docked;
  app.classList.toggle('is-docked', mdtDocked);
  const btn = document.getElementById('btnDock');
  if (btn) btn.textContent = mdtDocked ? '⊞ Visas' : '⊟ Kampas';
  if (!skipPost) nuiPost('mdtSetDocked', { docked: mdtDocked });
  if (!mdtDocked) {
    app.style.left = '';
    app.style.top = '';
    app.style.right = '';
    app.style.bottom = '';
  }
  if (!document.getElementById('panel-units')?.classList.contains('hidden')) {
    requestAnimationFrame(() => {
      layoutDispatchMapCanvas();
      clampDispatchMapPan();
      applyDispatchMapTransform();
    });
  }
}

function bindMdtDrag() {
  if (mdtDragBound) return;
  mdtDragBound = true;
  const head = document.querySelector('.top');
  if (!head) return;
  let drag = false;
  let sx = 0;
  let sy = 0;
  let sl = 0;
  let st = 0;
  head.addEventListener('mousedown', (e) => {
    if (!mdtDocked || e.target.closest('button')) return;
    drag = true;
    const r = app.getBoundingClientRect();
    sx = e.clientX;
    sy = e.clientY;
    sl = r.left;
    st = r.top;
    e.preventDefault();
  });
  window.addEventListener('mouseup', () => {
    drag = false;
  });
  window.addEventListener('mousemove', (e) => {
    if (!drag || !mdtDocked) return;
    app.style.left = `${sl + e.clientX - sx}px`;
    app.style.top = `${st + e.clientY - sy}px`;
    app.style.right = 'auto';
    app.style.bottom = 'auto';
  });
}

const btnDock = document.getElementById('btnDock');
if (btnDock) {
  btnDock.onclick = () => setMdtDocked(!mdtDocked);
}
bindMdtDrag();
document.getElementById('btnCreateCrew').onclick = () => nuiPost('crewAction', { action: 'create', callsign: document.getElementById('crewCallsign').value.trim() }).then(refreshDispatch);
document.getElementById('btnJoinCrew').onclick = () => nuiPost('crewAction', { action: 'join', crewId: document.getElementById('crewIdInput').value.trim() }).then(refreshDispatch);
document.getElementById('btnAddCrewMember').onclick = () => nuiPost('crewAction', {
  action: 'addMember',
  crewId: document.getElementById('crewIdInput').value.trim(),
  targetId: Number(document.getElementById('crewMemberId').value),
}).then(refreshDispatch);
document.getElementById('btnDeleteCrew').onclick = () => nuiPost('crewAction', { action: 'delete', crewId: document.getElementById('crewIdInput').value.trim() }).then(refreshDispatch);
document.getElementById('btnLeaveCrew').onclick = () => nuiPost('crewAction', { action: 'leave' }).then(refreshDispatch);
document.getElementById('btnSetCallsign').onclick = () => nuiPost('crewAction', { action: 'setCallsign', callsign: document.getElementById('crewCallsign').value.trim() }).then(refreshDispatch);
document.getElementById('btnPanic').onclick = () => nuiPost('crewAction', { action: 'panic' }).then(refreshDispatch);

let cctvCameras = [];
let selectedCctvId = null;
let selectedBodycamId = null;
let cctvHudTimer = null;

function setSurveillanceOverlay(active, label, meta, cctvData) {
  const ov = document.getElementById('survOverlay');
  document.body.classList.toggle('mdt-surveillance-live', !!active);
  if (!ov) return;
  ov.classList.toggle('hidden', !active);
  document.getElementById('survOverlayLabel').textContent = label || 'LIVE';
  document.getElementById('survOverlayMeta').textContent = meta || '';
  const rec = document.getElementById('survRec');
  if (rec) rec.classList.toggle('on', !!(active && cctvData && cctvData.rec));
  const hudId = document.getElementById('cctvHudId');
  if (hudId) hudId.textContent = cctvData && cctvData.camId ? `CAM ${cctvData.camId}` : 'CAM —';
  if (cctvHudTimer) {
    clearInterval(cctvHudTimer);
    cctvHudTimer = null;
  }
  if (active) {
    const tick = () => {
      const el = document.getElementById('cctvHudTime');
      if (el) {
        el.textContent = new Date().toLocaleTimeString('lt-LT', {
          hour: '2-digit',
          minute: '2-digit',
          second: '2-digit',
        });
      }
    };
    tick();
    cctvHudTimer = setInterval(tick, 1000);
  }
}

function stopSurveillanceUi() {
  setSurveillanceOverlay(false);
  nuiPost('cctvStop', {});
  nuiPost('bodycamStop', {});
  document.getElementById('cctvLiveHint')?.classList.add('hidden');
  document.getElementById('bodycamLiveHint')?.classList.add('hidden');
}

function renderCctvList() {
  const el = document.getElementById('cctvList');
  const q = (document.getElementById('cctvSearch').value || '').trim().toLowerCase();
  const zone = document.getElementById('cctvFilter').value;
  el.innerHTML = '';
  const rows = cctvCameras.filter((c) => {
    if (zone && c.zone !== zone) return false;
    if (q && !(c.label || '').toLowerCase().includes(q) && !(c.id || '').toLowerCase().includes(q)) return false;
    return true;
  });
  if (!rows.length) {
    el.innerHTML = '<div class="muted">Kamerų nerasta.</div>';
    return;
  }
  rows.forEach((c) => {
    const card = document.createElement('button');
    card.type = 'button';
    card.className = 'card surv-card' + (selectedCctvId === c.id ? ' selected' : '');
    const st = c.online ? '<span class="badge ok">ONLINE</span>' : '<span class="badge off">OFFLINE</span>';
    card.innerHTML = `<h4>${escapeHtml(c.label)}</h4><div class="muted">${escapeHtml(c.zoneLabel || c.zone)} • ${st}${c.audio ? ' • audio' : ''}</div>`;
    card.onclick = () => {
      selectedCctvId = c.id;
      document.getElementById('cctvStatus').textContent = c.label + (c.online ? '' : ' (OFFLINE)');
      renderCctvList();
    };
    el.appendChild(card);
  });
}

function refreshCctvList() {
  return nuiPost('cctvList', {}).then((res) => {
    if (!res || !res.ok) return;
    cctvCameras = res.cameras || [];
    const sel = document.getElementById('cctvFilter');
    const cur = sel.value;
    sel.innerHTML = '<option value="">Visos kategorijos</option>';
    const cats = res.categories || {};
    Object.keys(cats).forEach((k) => {
      const o = document.createElement('option');
      o.value = k;
      o.textContent = cats[k] || k;
      sel.appendChild(o);
    });
    sel.value = cur;
    sel.onchange = renderCctvList;
    document.getElementById('cctvSearch').oninput = renderCctvList;
    renderCctvList();
  });
}

document.getElementById('cctvRefresh').onclick = () => refreshCctvList();
document.getElementById('cctvWatchBtn').onclick = () => {
  if (!selectedCctvId) return;
  const audio = document.getElementById('cctvAudio').checked;
  nuiPost('cctvWatch', { camId: selectedCctvId }).then((res) => {
    if (!res || !res.ok) {
      document.getElementById('cctvStatus').textContent = (res && res.msg) || 'Nepavyko';
      stopSurveillanceUi();
      return;
    }
    nuiPost('cctvToggleAudio', { enabled: audio });
  });
};
document.getElementById('cctvStopBtn').onclick = () => {
  nuiPost('cctvStop', {}).then(() => stopSurveillanceUi());
};
document.getElementById('cctvAudio').onchange = (e) => {
  nuiPost('cctvToggleAudio', { enabled: e.target.checked });
};

function renderBodycamList() {
  const el = document.getElementById('bodycamList');
  el.innerHTML = '';
  return nuiPost('bodycamList', {}).then((res) => {
    const feeds = (res && res.feeds) || [];
    if (!feeds.length) {
      el.innerHTML = '<div class="muted">Nėra aktyvių bodycam.</div>';
      return;
    }
    feeds.forEach((f) => {
      const card = document.createElement('button');
      card.type = 'button';
      card.className = 'card surv-card' + (selectedBodycamId === f.serverId ? ' selected' : '');
      const crew = f.crew ? ` • ${escapeHtml(String(f.crew))}` : '';
      const batt = f.battery != null ? ` • ${f.battery}%` : '';
      card.innerHTML = `<h4>${escapeHtml(f.name)}</h4><div class="muted">ID ${f.serverId}${f.callsign ? ' • ' + escapeHtml(f.callsign) : ''}${crew}${batt}</div><span class="badge ok">LIVE</span>`;
      card.onclick = () => {
        selectedBodycamId = f.serverId;
        document.getElementById('bodycamStatus').textContent = `${f.name} (ID ${f.serverId})`;
        renderBodycamList();
      };
      el.appendChild(card);
    });
  });
}

function refreshBodycamList() {
  return renderBodycamList();
}

document.getElementById('bodycamRefresh').onclick = () => refreshBodycamList();
document.getElementById('bodycamWatchBtn').onclick = () => {
  if (!selectedBodycamId) return;
  nuiPost('bodycamWatch', { targetId: selectedBodycamId }).then((res) => {
    if (!res || !res.ok) {
      document.getElementById('bodycamStatus').textContent = (res && res.msg) || 'Nepavyko';
      stopSurveillanceUi();
    }
  });
};
document.getElementById('bodycamStopBtn').onclick = () => {
  nuiPost('bodycamStop', {}).then(() => stopSurveillanceUi());
};

function escapeHtml(s) {
  const d = document.createElement('div');
  d.textContent = s == null ? '' : String(s);
  return d.innerHTML;
}
