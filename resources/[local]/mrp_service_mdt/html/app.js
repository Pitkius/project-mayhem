const app = document.getElementById('app');
const btnClose = document.getElementById('btnClose');
let dispatchPoll = null;
let dispatchReadOnly = false;
let mdtSessionActive = false;
let mdtFetchFailStreak = 0;
const MDT_FETCH_FAIL_MAX = 4;
let lastDispatchPayload = null;
let selectedMapTarget = null;
let activeService = null;
let unitLabel = 'Vienetas';
let canInvoice = false;
let crewsEnabled = true;
let mdtPerf = {
  dispatchPollMs: 2500,
  pushStaleMs: 3500,
  dispatchPollPushMs: 8000,
  disablePollWhenPushActive: true,
};
let lastDispatchPushAt = 0;
let lastTabTelemetry = '';

function resourceName() {
  try {
    if (typeof GetParentResourceName === 'function') return GetParentResourceName();
  } catch (e) {}
  return 'mrp_service_mdt';
}

function escapeHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function mdtLocalClose() {
  mdtSessionActive = false;
  mdtFetchFailStreak = 0;
  app.classList.add('hidden');
  stopDispatchPoll();
}

function nuiPost(endpoint, data, opts) {
  const force = opts && opts.force === true;
  if (!force && (!mdtSessionActive || app.classList.contains('hidden'))) {
    return Promise.resolve(null);
  }
  return fetch(`https://${resourceName()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
  })
    .then((r) => {
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return r.json();
    })
    .then((json) => {
      mdtFetchFailStreak = 0;
      return json;
    })
    .catch((err) => {
      mdtFetchFailStreak += 1;
      if (mdtFetchFailStreak >= MDT_FETCH_FAIL_MAX) stopDispatchPoll();
      console.warn('[service-mdt]', endpoint, err);
      return null;
    });
}

function stopDispatchPoll() {
  if (dispatchPoll) {
    clearInterval(dispatchPoll);
    dispatchPoll = null;
  }
}

function applyMdtPerformance(cfg) {
  if (!cfg || typeof cfg !== 'object') return;
  mdtPerf = {
    dispatchPollMs: Number(cfg.dispatchPollMs) || 2500,
    pushStaleMs: Number(cfg.pushStaleMs) || 3500,
    dispatchPollPushMs: Number(cfg.dispatchPollPushMs) || 8000,
    disablePollWhenPushActive: cfg.disablePollWhenPushActive !== false,
  };
}

function dispatchPollIntervalMs() {
  if (!mdtPerf.disablePollWhenPushActive) return mdtPerf.dispatchPollMs;
  const age = Date.now() - lastDispatchPushAt;
  if (lastDispatchPushAt > 0 && age < mdtPerf.pushStaleMs) {
    return mdtPerf.dispatchPollPushMs;
  }
  return mdtPerf.dispatchPollMs;
}

function shouldSkipDispatchPollTick() {
  if (!mdtPerf.disablePollWhenPushActive || !lastDispatchPushAt) return false;
  return (Date.now() - lastDispatchPushAt) < mdtPerf.pushStaleMs;
}

function telemetryTab(name) {
  const tab = String(name || '').slice(0, 32);
  if (!tab || tab === lastTabTelemetry) return;
  lastTabTelemetry = tab;
  nuiPost('mdtTelemetry', { event: 'tab_switch', tab, service: activeService });
}

function startDispatchPoll() {
  stopDispatchPoll();
  refreshDispatch();
  dispatchPoll = setInterval(() => {
    if (!mdtSessionActive) return;
    if (!shouldSkipDispatchPollTick()) refreshDispatch();
  }, mdtPerf.dispatchPollMs);
}

function switchTab(name) {
  document.querySelectorAll('.tab').forEach((t) => {
    t.classList.toggle('active', t.dataset.tab === name);
  });
  document.querySelectorAll('.panel').forEach((p) => {
    p.classList.toggle('hidden', p.id !== `panel-${name}`);
  });
  telemetryTab(name);
  if (name === 'units' && window.MdtMap) {
    requestAnimationFrame(() => {
      MdtMap.invalidate();
      MdtMap.resetView();
    });
  }
}

document.querySelectorAll('.tab').forEach((tab) => {
  tab.addEventListener('click', () => switchTab(tab.dataset.tab));
});

btnClose.addEventListener('click', () => nuiPost('mdtClose', {}));

window.addEventListener('message', (e) => {
  const d = e.data;
  if (!d || !d.action) return;

  if (d.action === 'open') {
    mdtSessionActive = true;
    mdtFetchFailStreak = 0;
    app.classList.remove('hidden');
    activeService = d.data?.service || null;
    unitLabel = d.data?.unitLabel || 'Vienetas';
    canInvoice = d.data?.canInvoice === true;
    crewsEnabled = d.data?.enableCrews !== false;
    dispatchReadOnly = d.data?.onDuty === false;

    const tabIncidents = document.getElementById('tabIncidents');
    const enableIncidents = d.data?.enableIncidents === true && (activeService === 'ems' || activeService === 'mechanic');
    window.activeService = activeService;
    if (tabIncidents) tabIncidents.style.display = enableIncidents ? '' : 'none';
    const emsPanel = document.getElementById('emsIncPanel');
    const mechPanel = document.getElementById('mechIncPanel');
    if (emsPanel) emsPanel.classList.toggle('hidden', activeService !== 'ems');
    if (mechPanel) mechPanel.classList.toggle('hidden', activeService !== 'mechanic');

    const tabCrews = document.querySelector('.tab[data-tab="crews"]');
    const panelCrews = document.getElementById('panel-crews');
    if (tabCrews) tabCrews.style.display = crewsEnabled ? '' : 'none';
    if (panelCrews) panelCrews.classList.toggle('hidden', !crewsEnabled);
    const legendLeader = document.querySelector('#mapLegend .leg-item .leg-dot.leader')?.parentElement;
    if (legendLeader) legendLeader.style.display = crewsEnabled ? '' : 'none';
    if (window.MdtMap?.setCrewsVisible) MdtMap.setCrewsVisible(crewsEnabled);

    const brand = document.getElementById('mdtBrand');
    const brandLogo = document.getElementById('mdtBrandLogo');
    const brandLabel = escapeHtml(d.data?.brand || 'SERVICE');
    if (brand) {
      const textEl = brand.querySelector('.brand-text');
      if (textEl) {
        textEl.innerHTML = `${brandLabel} <span>MDT</span>`;
      } else {
        brand.innerHTML = `${brandLabel} <span>MDT</span>`;
      }
    }
    if (brandLogo) {
      const logoByService = {
        ems: 'assets/logo_ems.png',
        mechanic: 'assets/logo_mechanic.png',
      };
      brandLogo.src = logoByService[activeService] || 'assets/mayhem_mark.png';
      brandLogo.alt = brandLabel;
    }
    const footer = document.getElementById('mdtFooter');
    if (footer) footer.textContent = `${d.data?.label || 'Service MDT'} • Fivempro`;
    const legendUnit = document.getElementById('legendUnit');
    if (legendUnit) legendUnit.textContent = unitLabel;

    if (d.data?.accent) {
      document.documentElement.style.setProperty('--mdt-accent', d.data.accent);
    }

    const tabInv = document.getElementById('tabInvoices');
    if (tabInv) tabInv.style.display = canInvoice ? '' : 'none';

    const sel = document.getElementById('invPreset');
    sel.innerHTML = '';
    (d.data?.presets || []).forEach((p) => {
      const o = document.createElement('option');
      o.value = p.code;
      o.textContent = `${p.label} (${p.defaultAmount} €)`;
      o.dataset.amount = p.defaultAmount;
      o.dataset.label = p.label;
      sel.appendChild(o);
    });
    sel.onchange = () => {
      const opt = sel.options[sel.selectedIndex];
      document.getElementById('invAmt').value = opt?.dataset.amount || '';
      document.getElementById('invLabel').value = opt?.dataset.label || '';
    };
    if (sel.options.length) sel.onchange();

    applyMdtPerformance(d.data?.performance);
    lastDispatchPushAt = 0;
    lastTabTelemetry = '';

    if (window.MdtMap) {
      MdtMap.ensureMap(d.data?.map);
      MdtMap.setOnSelect(onMapBlipSelect);
      if (MdtMap.setAnimEnabled) MdtMap.setAnimEnabled(false);
      if (d.data?.selfSource != null) MdtMap.setSelfSource(d.data.selfSource);
      if (d.data?.playerPos) {
        MdtMap.setLocalPlayerPos({ ...d.data.playerPos, selfSource: d.data.selfSource });
      }
    }

    switchTab('calls');
    startDispatchPoll();
  }

  if (d.action === 'mdtPlayerPos' && window.MdtMap && d.x != null && d.y != null) {
    MdtMap.setLocalPlayerPos(d);
    if (lastDispatchPayload && mdtSessionActive) {
      renderDispatchMap({
        ...lastDispatchPayload,
        selfSource: d.selfSource != null ? d.selfSource : lastDispatchPayload.selfSource,
      });
    }
  }

  if (d.action === 'dispatchLive') {
    if (!mdtSessionActive || !d.data) return;
    lastDispatchPushAt = Date.now();
    const base = lastDispatchPayload && typeof lastDispatchPayload === 'object' ? lastDispatchPayload : { ok: true };
    renderDispatch({
      ...base,
      ok: base.ok !== false,
      units: d.data.units || [],
      calls: d.data.calls || [],
      crews: crewsEnabled ? (d.data.crews || []) : [],
      selfSource: d.data.selfSource != null ? d.data.selfSource : base.selfSource,
    });
  }

  if (d.action === 'close') mdtLocalClose();
});

function callActions(callId) {
  return `
    <div class="row">
      <button class="btn js-dispatch" data-action="accept" data-callid="${escapeHtml(callId)}">Priimti</button>
      <button class="btn js-dispatch" data-action="enroute" data-callid="${escapeHtml(callId)}">Vykstu</button>
      <button class="btn js-dispatch" data-action="done" data-callid="${escapeHtml(callId)}">Baigta</button>
      <button class="btn js-dispatch" data-action="reject" data-callid="${escapeHtml(callId)}">Atmesti</button>
    </div>`;
}

function resolveUnitNames(map, units) {
  if (!map || typeof map !== 'object') return '—';
  const ids = Object.keys(map);
  if (!ids.length) return '—';
  return ids.map((id) => {
    const u = (units || []).find((x) => String(x.source) === String(id));
    return u ? (u.callsign || u.name || id) : id;
  }).join(', ');
}

function statusPillClass(label) {
  const s = String(label || '').toLowerCase();
  if (s.includes('atvyk') || s.includes('arrived')) return 'arrived';
  if (s.includes('vyk') || s.includes('enroute') || s.includes('priority')) return 'enroute';
  return 'patrol';
}

function enrichUnitForPanel(u, crews) {
  const crew = (crews || []).find((c) => c.crewId === u.crewId);
  const crewLabel = crew
    ? (crew.callsign ? crew.callsign : `Ekipažas #${crew.crewNumber || '—'}`)
    : '—';
  return { ...u, crewLabel };
}

function renderMapDetail(kind, data) {
  const el = document.getElementById('dispatchMapDetail');
  if (!el) return;
  selectedMapTarget = data ? { kind, data } : null;
  if (!data) {
    el.innerHTML = '<div class="gps-detail-empty muted">Pasirink blipą žemėlapyje.</div>';
    return;
  }
  if (kind === 'unit') {
    const badge = data.callsign || (data.name ? String(data.name).split(' ')[0] : '—');
    const pill = statusPillClass(data.statusLabel);
    el.innerHTML = `
      <div class="gps-detail-card">
        <h3>${escapeHtml(unitLabel)}</h3>
        <div class="gps-detail-row"><span>Vardas</span><strong>${escapeHtml(data.name || '—')}</strong></div>
        <div class="gps-detail-row"><span>Ženklelis</span><strong>${escapeHtml(badge)}</strong></div>
        ${crewsEnabled ? `<div class="gps-detail-row"><span>Ekipažas</span><strong>${escapeHtml(data.crewLabel || '—')}</strong></div>` : ''}
        <div class="gps-detail-row"><span>Statusas</span><strong><span class="gps-status-pill ${pill}">${escapeHtml(data.statusLabel || 'Patruliuoja')}</span></strong></div>
        <div class="gps-detail-row"><span>Koordinatės</span><strong>${Number(data.x || 0).toFixed(1)} ${Number(data.y || 0).toFixed(1)}</strong></div>
        <div class="gps-detail-actions">
          <button type="button" class="btn primary" id="gpsSetRouteBtn">Nustatyti maršrutą</button>
        </div>
      </div>`;
  } else {
    const pill = statusPillClass(data.statusLabel);
    el.innerHTML = `
      <div class="gps-detail-card">
        <h3>Iškvietimas</h3>
        <div class="gps-detail-row"><span>ID</span><strong>${escapeHtml(data.id || '—')}</strong></div>
        <div class="gps-detail-row"><span>Tipas</span><strong>${escapeHtml(data.callTypeLabel || data.callType || '—')}</strong></div>
        <div class="gps-detail-row"><span>Statusas</span><strong><span class="gps-status-pill ${pill}">${escapeHtml(data.statusLabel || data.status || '—')}</span></strong></div>
        <div class="gps-detail-row"><span>Koordinatės</span><strong>${Number(data.x || 0).toFixed(1)} ${Number(data.y || 0).toFixed(1)}</strong></div>
        <div class="gps-detail-actions">
          <button type="button" class="btn primary" id="gpsSetRouteBtn">Nustatyti maršrutą</button>
        </div>
      </div>`;
  }
  const btn = document.getElementById('gpsSetRouteBtn');
  if (btn) {
    btn.onclick = () => {
      nuiPost('mdtSetRoute', { x: data.x, y: data.y });
      if (window.MdtMap?.setRoute) MdtMap.setRoute(data.x, data.y);
    };
  }
}

function onMapBlipSelect(kind, data) {
  if (kind === 'unit' && data && lastDispatchPayload) {
    renderMapDetail(kind, enrichUnitForPanel(data, lastDispatchPayload.crews));
    return;
  }
  renderMapDetail(kind, data);
}

function renderDispatchMap(payload) {
  if (!window.MdtMap) return;
  MdtMap.update(payload || {});
}

function setDispatchControlsEnabled(enabled) {
  const ids = ['refreshDispatch'];
  if (crewsEnabled) {
    ids.push('btnCreateCrew', 'btnJoinCrew', 'btnAddCrewMember', 'btnDeleteCrew', 'btnLeaveCrew', 'btnSetCallsign');
  }
  ids.forEach((id) => {
      const el = document.getElementById(id);
      if (el) el.disabled = !enabled;
    });
}

function renderDispatch(res) {
  dispatchReadOnly = !!(res && res.readOnly);
  setDispatchControlsEnabled(!dispatchReadOnly);
  const callsEl = document.getElementById('dispatchCalls');
  const crewsEl = document.getElementById('dispatchCrews');
  callsEl.innerHTML = '';
  if (crewsEl) crewsEl.innerHTML = '';

  if (res && res.ok === false && res.msg) {
    callsEl.innerHTML = `<div class="muted">${escapeHtml(res.msg)}</div>`;
    lastDispatchPayload = res;
    renderDispatchMap(res);
    return;
  }

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
        ${dispatchReadOnly ? '' : callActions(c.id)}
      `;
      callsEl.appendChild(card);
    });
  }

  if (crewsEnabled && crewsEl) {
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
        <div>Statusas: ${escapeHtml(c.status || 'active')}</div>
        <div>Nariai: ${members || '-'}</div>`;
        crewsEl.appendChild(card);
      });
    }
  }

  lastDispatchPayload = res;
  renderDispatchMap(crewsEnabled ? res : { ...res, crews: [] });

  document.querySelectorAll('.js-dispatch').forEach((btn) => {
    btn.onclick = () => nuiPost('dispatchAction', { callId: btn.dataset.callid, action: btn.dataset.action }).then(() => refreshDispatch());
  });
}

function refreshDispatch() {
  if (!mdtSessionActive) return Promise.resolve(null);
  return nuiPost('dispatchSnapshot', {}).then((res) => {
    if (!res) return null;
    renderDispatch(res);
    return res;
  });
}

document.getElementById('refreshDispatch').onclick = () => refreshDispatch();

(function bindCrewButtons() {
  const map = {
    btnCreateCrew: () => ({ action: 'create', callsign: document.getElementById('crewCallsign').value }),
    btnJoinCrew: () => ({ action: 'join', crewId: document.getElementById('crewIdInput').value }),
    btnAddCrewMember: () => ({
      action: 'addMember',
      crewId: document.getElementById('crewIdInput').value,
      targetId: document.getElementById('crewMemberId').value,
    }),
    btnDeleteCrew: () => ({ action: 'delete', crewId: document.getElementById('crewIdInput').value }),
    btnLeaveCrew: () => ({ action: 'leave' }),
    btnSetCallsign: () => ({ action: 'setCallsign', callsign: document.getElementById('crewCallsign').value }),
  };
  Object.keys(map).forEach((id) => {
    const el = document.getElementById(id);
    if (!el) return;
    el.onclick = () => nuiPost('crewAction', map[id]()).then(() => refreshDispatch());
  });
})();

(function bindGpsToolbar() {
  const zIn = document.getElementById('dispatchZoomIn');
  const zOut = document.getElementById('dispatchZoomOut');
  const reset = document.getElementById('gpsResetView');
  const centerSelf = document.getElementById('gpsCenterSelf');
  const centerCall = document.getElementById('gpsCenterCall');
  const refresh = document.getElementById('refreshDispatchMap');
  if (zIn) zIn.addEventListener('click', () => window.MdtMap && MdtMap.zoomIn());
  if (zOut) zOut.addEventListener('click', () => window.MdtMap && MdtMap.zoomOut());
  if (reset) reset.addEventListener('click', () => window.MdtMap && MdtMap.resetView());
  if (centerSelf) centerSelf.addEventListener('click', () => window.MdtMap && MdtMap.centerOnPlayer());
  if (centerCall) centerCall.addEventListener('click', () => window.MdtMap && MdtMap.centerOnActiveCall());
  if (refresh) refresh.addEventListener('click', () => { if (window.MdtMap) MdtMap.resetView(); refreshDispatch(); });
})();

function renderInvoiceRows(rows, title) {
  const el = document.getElementById('invResults');
  if (!rows || !rows.length) {
    el.innerHTML = '<div class="muted">Įrašų nerasta.</div>';
    return;
  }
  let html = title ? `<div class="muted">${escapeHtml(title)}</div>` : '';
  rows.forEach((r) => {
    html += `
      <div class="card">
        <h4>${escapeHtml(r.reason_label || 'Sąskaita')} — ${Number(r.amount || 0)} €</h4>
        <div>${escapeHtml(r.name || r.citizenid || '')} ${r.plate ? '• ' + escapeHtml(r.plate) : ''}</div>
        <div class="muted">${escapeHtml(r.created_at || '')}</div>
      </div>`;
  });
  el.innerHTML = html;
}

document.getElementById('goInvoice').onclick = () => {
  const status = document.getElementById('invStatus');
  status.textContent = '';
  const sel = document.getElementById('invPreset');
  const opt = sel.options[sel.selectedIndex];
  nuiPost('issueInvoice', {
    citizenid: document.getElementById('invCid').value.trim(),
    amount: Number(document.getElementById('invAmt').value),
    reason_code: opt?.value || '',
    reason_label: document.getElementById('invLabel').value.trim() || opt?.dataset.label || '',
    plate: document.getElementById('invPlate').value.trim(),
  }).then((res) => {
    if (!res) return;
    status.textContent = res.ok ? 'Sąskaita išrašyta.' : (res.message || 'Klaida.');
    if (res.ok) nuiPost('recentInvoices', {}).then((r) => renderInvoiceRows(r?.rows, 'Naujausios sąskaitos'));
  });
};

document.getElementById('invSearch').onclick = () => {
  const cid = document.getElementById('invCid').value.trim();
  if (!cid) return;
  nuiPost('searchInvoices', { citizenid: cid }).then((res) => {
    if (!res || !res.ok) return;
    renderInvoiceRows(res.rows, `${res.name || res.citizenid} istorija`);
  });
};

document.getElementById('invRecent').onclick = () => {
  nuiPost('recentInvoices', {}).then((res) => {
    if (!res || !res.ok) return;
    renderInvoiceRows(res.rows, 'Naujausios sąskaitos');
  });
};

window.addEventListener('resize', () => {
  if (!document.getElementById('panel-units')?.classList.contains('hidden') && window.MdtMap) {
    MdtMap.invalidate();
  }
});

window.nuiPost = nuiPost;
window.escapeHtml = escapeHtml;
