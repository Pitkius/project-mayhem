const app = document.getElementById('app');
const btnClose = document.getElementById('btnClose');
let dispatchPoll = null;
const MAP_BOUNDS = { minX: -4500, maxX: 4500, minY: -4500, maxY: 9000 };

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
    const perms = (d.data && d.data.permissions) || {};
    document.getElementById('tabFine').style.display = perms.fine ? '' : 'none';
    document.getElementById('tabWant').style.display = perms.wanted ? '' : 'none';
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
    stopDispatchPoll();
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
    x: Math.max(1, Math.min(99, px)),
    y: Math.max(1, Math.min(99, py)),
  };
}

let dispatchMapPan = { x: 0, y: 0, scale: 1 };
let dispatchMapInteractBound = false;

function applyDispatchMapTransform() {
  const layer = document.getElementById('dispatchMapTransform');
  if (!layer) return;
  layer.style.transform = `translate(${dispatchMapPan.x}px, ${dispatchMapPan.y}px) scale(${dispatchMapPan.scale})`;
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
      dispatchMapPan.scale = Math.max(0.45, Math.min(3.2, dispatchMapPan.scale + delta));
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
    applyDispatchMapTransform();
  });
}

function renderDispatchMap(calls, units) {
  const markers = document.getElementById('dispatchMapMarkers');
  if (!markers) return;
  markers.innerHTML = '';
  bindDispatchMapInteract();
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
      dispatchMapPan.scale = Math.min(3.2, dispatchMapPan.scale + 0.15);
      applyDispatchMapTransform();
    });
  }
  if (zOut) {
    zOut.addEventListener('click', () => {
      dispatchMapPan.scale = Math.max(0.45, dispatchMapPan.scale - 0.15);
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
  dispatchMapPan = { x: 0, y: 0, scale: 1 };
  applyDispatchMapTransform();
  refreshDispatch();
};
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

function escapeHtml(s) {
  const d = document.createElement('div');
  d.textContent = s == null ? '' : String(s);
  return d.innerHTML;
}
