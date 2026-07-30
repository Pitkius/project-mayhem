const app = document.getElementById('app');
const btnClose = document.getElementById('btnClose');
let dispatchPoll = null;
let dispatchReadOnly = false;
let mdtSessionActive = false;
let mdtSurveillanceLive = false;
let mdtFetchFailStreak = 0;
const MDT_FETCH_FAIL_MAX = 4;
let lastDispatchPayload = null;
let selectedMapTarget = null;
let mdtPermissions = {};
let mdtPerf = {
  dispatchPollMs: 2500,
  pushStaleMs: 3500,
  dispatchPollPushMs: 8000,
  disablePollWhenPushActive: true,
};
let lastDispatchPushAt = 0;
let lastTabTelemetry = '';

const mapMeta = {
  minX: -4000,
  maxX: 4500,
  minY: -4000,
  maxY: 6625,
  imgW: 2048,
  imgH: 2048,
  imageUrl: '',
  loaded: false,
};

function applyMapConfig(cfg) {
  if (!cfg || typeof cfg !== 'object') return;
  mapMeta.minX = Number(cfg.gameMin?.x ?? mapMeta.minX);
  mapMeta.minY = Number(cfg.gameMin?.y ?? mapMeta.minY);
  mapMeta.maxX = Number(cfg.gameMax?.x ?? mapMeta.maxX);
  mapMeta.maxY = Number(cfg.gameMax?.y ?? mapMeta.maxY);
  mapMeta.imgW = Number(cfg.imageWidth) || mapMeta.imgW;
  mapMeta.imgH = Number(cfg.imageHeight) || mapMeta.imgH;
  if (cfg.imageFile) {
    mapMeta.imageUrl = nuiImageUrl(cfg.imageFile);
  }
}

function nuiImageUrl(pathFromHtml) {
  const raw = String(pathFromHtml || '').trim();
  if (!raw || /^https?:\/\//i.test(raw) || /^nui:\/\//i.test(raw)) return raw;
  const res = resourceName();
  let p = raw.replace(/^\/+/, '');
  if (!p.startsWith('html/')) p = `html/${p}`;
  return `nui://${res}/${p}`;
}

const MAP_SAT_URL = nuiImageUrl('mdt/asset/gtav_satellite_2048.png');
mapMeta.imageUrl = MAP_SAT_URL;

function preloadMapImage(url) {
  const src = url || mapMeta.imageUrl || MAP_SAT_URL;
  if (!src) return Promise.resolve();
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => {
      if (img.naturalWidth > 0 && img.naturalHeight > 0) {
        mapMeta.imgW = img.naturalWidth;
        mapMeta.imgH = img.naturalHeight;
      }
      mapMeta.loaded = true;
      resolve();
    };
    img.onerror = () => resolve();
    img.src = src;
  });
}

function resourceName() {
  try {
    if (typeof GetParentResourceName === 'function') return GetParentResourceName();
  } catch (e) {}
  return 'mrp_ltpd';
}

function mdtLocalClose() {
  mdtSessionActive = false;
  mdtSurveillanceLive = false;
  mdtFetchFailStreak = 0;
  app.classList.add('hidden');
  mdtDocked = false;
  app.classList.remove('is-docked');
  stopDispatchPoll();
  stopSurveillanceUi(false);
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
      if (mdtFetchFailStreak === 1 || mdtFetchFailStreak >= MDT_FETCH_FAIL_MAX) {
        console.warn('[mdt] nuiPost', endpoint, err);
      }
      if (mdtFetchFailStreak >= MDT_FETCH_FAIL_MAX) {
        stopDispatchPoll();
      }
      return null;
    });
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
  nuiPost('mdtTelemetry', { event: 'tab_switch', tab });
}

function mdtEnsureConnected() {
  return nuiPost('mdtPing', {}).then((res) => {
    if (!res || res.ok !== true || res.mdtOpen !== true) {
      mdtSessionActive = false;
      return false;
    }
    return true;
  });
}

window.addEventListener('message', (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === 'open') {
    mdtSessionActive = true;
    mdtFetchFailStreak = 0;
    app.classList.remove('hidden');
    mdtDocked = false;
    app.classList.remove('is-docked');
    const perms = (d.data && d.data.permissions) || {};
    mdtPermissions = perms;
    const idEl = document.getElementById('mdtOfficerIdentity');
    if (idEl) {
      const bits = [];
      if (d.data.gradeName) bits.push(d.data.gradeName);
      if (d.data.divisionLabel) bits.push(d.data.divisionLabel);
      else if (d.data.divisionRank && d.data.divisionRank.label) bits.push(d.data.divisionRank.label);
      idEl.textContent = bits.length ? bits.join(' · ') : '';
    }
    document.getElementById('tabFine').style.display = perms.fine ? '' : 'none';
    document.getElementById('tabWant').style.display = perms.wanted ? '' : 'none';
    const tabArrests = document.getElementById('tabArrests');
    if (tabArrests) tabArrests.style.display = perms.arrest ? '' : 'none';
    const tabInterr = document.getElementById('tabInterrogations');
    if (tabInterr) tabInterr.style.display = perms.interrogation ? '' : 'none';
    document.getElementById('tabCctv').style.display = perms.cctv ? '' : 'none';
    document.getElementById('tabBodycam').style.display = perms.bodycam ? '' : 'none';
    applySurveillanceMaintenanceFromOpen(d.data || {});
    applyMapMaintenanceFromOpen(d.data || {});
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
    applyMapConfig(d.data && d.data.map);
    applyMdtPerformance(d.data && d.data.performance);
    lastDispatchPushAt = 0;
    lastTabTelemetry = '';
    if (window.MdtMap) {
      MdtMap.ensureMap(d.data && d.data.map);
      MdtMap.setOnSelect(onMapBlipSelect);
      if (MdtMap.setAnimEnabled) MdtMap.setAnimEnabled(false);
      if (d.data?.selfSource != null) MdtMap.setSelfSource(d.data.selfSource);
      if (d.data?.playerPos) MdtMap.setLocalPlayerPos({ ...d.data.playerPos, selfSource: d.data.selfSource });
    }
    preloadMapImage(mapMeta.imageUrl);
    mdtEnsureConnected().then((ok) => {
      if (ok) startDispatchPoll();
    });
  }
  if (d.action === 'mdtPlayerPos' && window.MdtMap && d.x != null && d.y != null) {
    if (!mapMaintenance) {
      MdtMap.setLocalPlayerPos(d);
      if (lastDispatchPayload && mdtSessionActive && !mdtSurveillanceLive) {
        renderDispatchMap({
          ...lastDispatchPayload,
          selfSource: d.selfSource != null ? d.selfSource : lastDispatchPayload.selfSource,
        });
      }
    }
  }
  if (d.action === 'dispatchLive') {
    if (!mdtSessionActive || mdtSurveillanceLive || !d.data) return;
    lastDispatchPushAt = Date.now();
    const base = lastDispatchPayload && typeof lastDispatchPayload === 'object' ? lastDispatchPayload : { ok: true };
    const res = {
      ...base,
      ok: base.ok !== false,
      units: d.data.units || [],
      calls: d.data.calls || [],
      crews: d.data.crews || [],
      selfSource: d.data.selfSource != null ? d.data.selfSource : base.selfSource,
    };
    renderDispatch(res);
  }
  if (d.action === 'close') {
    mdtLocalClose();
  }
  if (d.action === 'dock') {
    setMdtDocked(true, true);
  }
  if (d.action === 'cctvOverlay') {
    mdtSurveillanceLive = d.active === true;
    if (mdtSurveillanceLive) stopDispatchPoll();
    const meta = [d.camId ? `ID ${d.camId}` : '', d.audio ? 'Garsas' : 'Be garso'].filter(Boolean).join(' • ');
    setSurveillanceOverlay(d.active, d.label || 'Kamera tiesiogiai', meta, d);
    document.getElementById('cctvLiveHint').classList.toggle('hidden', !d.active);
    if (d.active && d.label) {
      document.getElementById('cctvStatus').textContent = d.label;
    }
    if (!d.active) {
      onSurveillanceEnded(false);
      if (mdtSessionActive) startDispatchPoll();
    }
  }
  if (d.action === 'bodycamOverlay') {
    mdtSurveillanceLive = d.active === true;
    if (mdtSurveillanceLive) stopDispatchPoll();
    setSurveillanceOverlay(d.active, 'Kūno kamera tiesiogiai', d.targetId ? `ID ${d.targetId}` : '');
    document.getElementById('bodycamLiveHint').classList.toggle('hidden', !d.active);
    if (!d.active) {
      onSurveillanceEnded(false);
      if (mdtSessionActive) startDispatchPoll();
    }
  }
});

btnClose.onclick = () => {
  mdtLocalClose();
  nuiPost('close', {}, { force: true });
};

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && mdtSessionActive) {
    e.preventDefault();
    if (mdtSurveillanceLive || document.body.classList.contains('mdt-surveillance-live')) {
      stopSurveillanceUi();
      return;
    }
    mdtLocalClose();
    nuiPost('close', {}, { force: true });
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
    telemetryTab(t.dataset.tab);
    if (window.MdtMap && window.MdtMap.setAnimEnabled) {
      window.MdtMap.setAnimEnabled(false);
    }
    if (t.dataset.tab === 'units') {
      applyMapMaintenanceUi();
      requestAnimationFrame(() => {
        if (mapMaintenance) return;
        if (window.MdtMap) {
          MdtMap.invalidate();
          MdtMap.resetView();
        }
        refreshDispatch();
      });
    }
    if (t.dataset.tab === 'calls' || t.dataset.tab === 'crews') refreshDispatch();
    if (t.dataset.tab === 'cctv') {
      applySurveillanceMaintenanceUi();
      refreshCctvList();
    }
    if (t.dataset.tab === 'bodycam') {
      applySurveillanceMaintenanceUi();
      refreshBodycamList();
    }
    if (t.dataset.tab !== 'cctv' && t.dataset.tab !== 'bodycam') {
      if (cctvLiveActive || mdtSurveillanceLive || document.body.classList.contains('mdt-surveillance-live')) {
        stopSurveillanceUi(false);
      }
    }
  };
});

function runPersonSearch() {
  const q = document.getElementById('qPerson').value.trim();
  const el = document.getElementById('personResults');
  if (q.length < 2) {
    el.innerHTML = '<div class="muted">Įvesk bent 2 simbolius (vardas, pavardė arba citizenid).</div>';
    return;
  }
  el.innerHTML = '<div class="muted">Ieškoma…</div>';
  nuiPost('searchPerson', { query: q }, { force: true }).then((res) => renderPerson(res));
}

document.getElementById('goPerson').onclick = runPersonSearch;
document.getElementById('qPerson').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') runPersonSearch();
});

function renderPerson(res) {
  const el = document.getElementById('personResults');
  el.innerHTML = '';
  if (!res) {
    el.innerHTML = '<div class="muted">Ryšys su MDT nutrūko. Bandyk dar kartą.</div>';
    return;
  }
  if (!res.ok) {
    el.innerHTML = `<div class="muted">${escapeHtml(res.message || 'Paieška nepavyko.')}</div>`;
    return;
  }
  if (!res.rows || !res.rows.length) {
    el.innerHTML = '<div class="muted">Nieko nerasta.</div>';
    return;
  }
  res.rows.forEach((r) => {
    const c = document.createElement('div');
    c.className = 'card';
    let html = `<h4>${escapeHtml(r.name || '')}</h4>`;
    html += `<div class="muted">citizenid: ${escapeHtml(r.citizenid)}</div>`;
    if (r.fingerprint) {
      html += `<div class="muted">Atspaudas: ${escapeHtml(r.fingerprint)}</div>`;
    }
    if (res.full && r.cash != null) {
      html += `<div>Grynieji: ${r.cash} € | Bankas: ${r.bank} €</div>`;
    }
    const wl = Number(r.wanted_level) || 0;
    html += `<div>Paieškomumas: <strong>${wl}</strong>${wl > 0 ? ' — ' : ' '}${escapeHtml(r.wanted_reason || (wl > 0 ? '' : '(nėra)'))}</div>`;
    if (r.licenses && r.licenses.length) {
      html += '<div class="license-block"><div class="muted">Licencijos ir dokumentai</div><ul class="license-list">';
      r.licenses.forEach((lic) => {
        const badge = lic.active ? '<span class="badge ok">Taip</span>' : '<span class="badge off">Ne</span>';
        let line = `<li>${escapeHtml(lic.label)} ${badge}`;
        if (lic.active && lic.detail) {
          line += ` <span class="muted">(${escapeHtml(lic.detail)})</span>`;
        }
        if (lic.active && lic.expiry) {
          line += ` <span class="muted">galioja iki ${escapeHtml(lic.expiry)}</span>`;
        }
        line += '</li>';
        html += line;
      });
      html += '</ul></div>';
    }
    html += `<div class="row card-actions"><button type="button" class="btn js-fill-want" data-cid="${escapeHtml(r.citizenid)}">→ Paieška</button>`;
    html += `<button type="button" class="btn js-collect-fp" data-cid="${escapeHtml(r.citizenid)}">Įrašyti atspaudus</button>`;
    if (mdtPermissions.weaponLicense) {
      html += `<button type="button" class="btn js-issue-wl" data-cid="${escapeHtml(r.citizenid)}">Išduoti ginklo lic.</button>`;
      html += `<button type="button" class="btn js-revoke-wl" data-cid="${escapeHtml(r.citizenid)}">Atšaukti ginklo lic.</button>`;
    }
    html += `</div>`;
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
    const wantBtn = c.querySelector('.js-fill-want');
    if (wantBtn) {
      wantBtn.onclick = () => {
        document.getElementById('wantCid').value = wantBtn.dataset.cid || '';
        document.querySelector('.tab[data-tab="want"]')?.click();
      };
    }
    const fpBtn = c.querySelector('.js-collect-fp');
    if (fpBtn) {
      fpBtn.onclick = () => {
        nuiPost('collectFingerprint', { citizenid: fpBtn.dataset.cid }, { force: true }).then((res) => {
          if (res && res.ok) runPersonSearch();
        });
      };
    }
    const issueWlBtn = c.querySelector('.js-issue-wl');
    if (issueWlBtn) {
      issueWlBtn.onclick = () => {
        nuiPost('issueWeaponLicense', { citizenid: issueWlBtn.dataset.cid }, { force: true }).then((res) => {
          if (res && res.ok) runPersonSearch();
        });
      };
    }
    const revokeWlBtn = c.querySelector('.js-revoke-wl');
    if (revokeWlBtn) {
      revokeWlBtn.onclick = () => {
        nuiPost('revokeWeaponLicense', { citizenid: revokeWlBtn.dataset.cid }, { force: true }).then((res) => {
          if (res && res.ok) runPersonSearch();
        });
      };
    }
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
  }, { force: true }).then((res) => {
    if (res && res.ok) {
      document.getElementById('fineCid').value = '';
    }
  });
};

document.getElementById('goWant').onclick = () => {
  const status = document.getElementById('wantStatus');
  const cid = document.getElementById('wantCid').value.trim();
  if (!cid) {
    if (status) status.textContent = 'Įvesk citizenid.';
    return;
  }
  if (status) status.textContent = 'Saugoma…';
  nuiPost('setWanted', {
    citizenid: cid,
    level: Number(document.getElementById('wantLvl').value),
    reason: document.getElementById('wantReason').value.trim(),
  }, { force: true }).then((res) => {
    if (!status) return;
    if (res && res.ok) {
      status.textContent = res.message || 'Paieškomumas išsaugotas.';
      status.className = 'want-status ok';
    } else {
      status.textContent = (res && res.message) || 'Nepavyko išsaugoti.';
      status.className = 'want-status err';
    }
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

function renderInterrogationHistory(res) {
  const el = document.getElementById('interrResults');
  if (!el) return;
  el.innerHTML = '';
  if (!res || !res.ok || !res.rows || !res.rows.length) {
    el.innerHTML = '<div class="muted">Apklausų įrašų nėra.</div>';
    return;
  }
  res.rows.forEach((row) => {
    const c = document.createElement('div');
    c.className = 'card';
    const notes = Array.isArray(row.notes) ? row.notes.join(' · ') : '';
    const ans = Array.isArray(row.answers) ? row.answers.length : 0;
    c.innerHTML = `<h4>${escapeHtml(row.created_at || '')} — ${escapeHtml(row.mode || '')}</h4>
      <div><strong>Rezultatas:</strong> ${escapeHtml(row.result || '—')}</div>
      <div><strong>Kambarys:</strong> ${escapeHtml(row.room_id || '—')}</div>
      <div class="muted">Pareigūnas: ${escapeHtml(row.officer_name || row.officer_citizenid || '—')}</div>
      <div>Įrašyta: ${row.recorded ? 'taip' : 'ne'} · Spaudimas: ${escapeHtml(String(row.pressure_max ?? 0))}</div>
      ${row.summary ? `<div>${escapeHtml(row.summary)}</div>` : ''}
      ${notes ? `<div class="muted">${escapeHtml(notes)}</div>` : ''}
      ${ans ? `<div class="muted">${ans} atsakymų</div>` : ''}`;
    el.appendChild(c);
  });
}

const interrLoad = document.getElementById('interrLoad');
if (interrLoad) {
  interrLoad.onclick = () => {
    const cid = document.getElementById('interrCid').value.trim();
    if (!cid) return;
    nuiPost('getInterrogationHistory', { citizenid: cid }).then(renderInterrogationHistory);
  };
}

function stopDispatchPoll() {
  if (dispatchPoll) {
    clearInterval(dispatchPoll);
    dispatchPoll = null;
  }
}

function startDispatchPoll() {
  if (!mdtSessionActive || mdtSurveillanceLive || app.classList.contains('hidden')) return;
  stopDispatchPoll();
  refreshDispatch();
  dispatchPoll = setInterval(() => {
    if (!mdtSessionActive || mdtSurveillanceLive) return;
    if (!shouldSkipDispatchPollTick()) refreshDispatch();
  }, mdtPerf.dispatchPollMs);
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
    out.push(unit ? `${unit.callsign ? `[${unit.callsign}] ` : ''}${unit.name || 'Pareigūnas'}` : 'Pareigūnas');
  });
  return out.length ? out.join(', ') : '-';
}

let mdtDocked = false;
let mdtDragBound = false;

function statusPillClass(label, panic) {
  if (panic) return 'panic';
  const s = String(label || '').toLowerCase();
  if (s.includes('atvyk') || s.includes('arrived')) return 'arrived';
  if (s.includes('vyk') || s.includes('enroute') || s.includes('priority')) return 'enroute';
  return 'patrol';
}

function renderMapDetail(kind, data) {
  const el = document.getElementById('dispatchMapDetail');
  if (!el) return;
  if (mapMaintenance) {
    el.innerHTML = `<div class="surv-offline-status"><span class="surv-offline-title">Sistema neprieinama</span><p class="surv-offline-msg">${escapeHtml(mapMaintenanceMessage)}</p></div>`;
    return;
  }
  selectedMapTarget = data ? { kind, data } : null;
  if (!data) {
    el.innerHTML = '<div class="gps-detail-empty muted">Pasirink blipą žemėlapyje arba užvesk pelę dėl informacijos.</div>';
    return;
  }
  if (kind === 'unit') {
    const badge = data.callsign || (data.name ? String(data.name).split(' ')[0] : '—');
    const pill = statusPillClass(data.statusLabel, data.panic);
    el.innerHTML = `
      <div class="gps-detail-card">
        <h3>Pareigūnas</h3>
        <div class="gps-detail-row"><span>Pareigūnas</span><strong>${escapeHtml(data.name || '—')}</strong></div>
        <div class="gps-detail-row"><span>Ženklelis</span><strong>${escapeHtml(badge)}</strong></div>
        <div class="gps-detail-row"><span>Ekipažas</span><strong>${escapeHtml(data.crewLabel || '—')}</strong></div>
        <div class="gps-detail-row"><span>Statusas</span><strong><span class="gps-status-pill ${pill}">${escapeHtml(data.statusLabel || 'Patruliuoja')}</span></strong></div>
        <div class="gps-detail-row"><span>Greitis</span><strong>${Number(data.speedKmh || 0)} km/h</strong></div>
        <div class="gps-detail-row"><span>GPS</span><strong>${data.gpsActive !== false ? 'aktyvus' : 'neaktyvus'}</strong></div>
        <div class="gps-detail-row"><span>Koordinatės</span><strong>${Number(data.x || 0).toFixed(1)} ${Number(data.y || 0).toFixed(1)} ${Number(data.z || 0).toFixed(1)}</strong></div>
        <div class="gps-detail-actions">
          <button type="button" class="btn primary" id="gpsSetRouteBtn">Nustatyti maršrutą</button>
        </div>
      </div>
    `;
    const btn = document.getElementById('gpsSetRouteBtn');
    if (btn) {
      btn.onclick = () => {
        nuiPost('mdtSetRoute', { x: data.x, y: data.y });
        if (window.MdtMap?.setRoute) MdtMap.setRoute(data.x, data.y);
      };
    }
    return;
  }
  const pill = statusPillClass(data.statusLabel, data.panic);
  el.innerHTML = `
    <div class="gps-detail-card">
      <h3>Iškvietimas</h3>
      <div class="gps-detail-row"><span>ID</span><strong>${escapeHtml(data.id || '—')}</strong></div>
      <div class="gps-detail-row"><span>Tipas</span><strong>${escapeHtml(data.callTypeLabel || data.callType || '—')}</strong></div>
      <div class="gps-detail-row"><span>Statusas</span><strong><span class="gps-status-pill ${pill}">${escapeHtml(data.statusLabel || data.status || '—')}</span></strong></div>
      <div class="gps-detail-row"><span>Koordinatės</span><strong>${Number(data.x || 0).toFixed(1)} ${Number(data.y || 0).toFixed(1)} ${Number(data.z || 0).toFixed(1)}</strong></div>
      <div class="gps-detail-actions">
        <button type="button" class="btn primary" id="gpsSetRouteBtn">Nustatyti maršrutą</button>
      </div>
    </div>
  `;
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

function enrichUnitForPanel(u, crews) {
  const crew = (crews || []).find((c) => c.crewId === u.crewId);
  const crewLabel = crew
    ? (crew.callsign ? crew.callsign : `Ekipažas #${crew.crewNumber || '—'}`)
    : '—';
  return { ...u, crewLabel };
}

function renderDispatchMap(payload) {
  if (mapMaintenance || !window.MdtMap) return;
  MdtMap.update(payload || {});
  if (selectedMapTarget?.data) {
    const crews = payload.crews || [];
    if (selectedMapTarget.kind === 'unit') {
      const fresh = (payload.units || []).find((x) => String(x.source) === String(selectedMapTarget.data.source));
      if (fresh) renderMapDetail('unit', enrichUnitForPanel(fresh, crews));
    } else {
      const fresh = (payload.calls || []).find((x) => String(x.id) === String(selectedMapTarget.data.id));
      if (fresh) renderMapDetail('call', fresh);
    }
  }
}

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
  if (centerSelf) {
    centerSelf.addEventListener('click', () => {
      if (window.MdtMap && !MdtMap.centerOnPlayer()) {
        const note = document.getElementById('dispatchMapDetail');
        if (note) note.innerHTML = '<div class="gps-detail-empty muted">Tavo pozicija žemėlapyje nerasta — palauk GPS sinchronizacijos.</div>';
      }
    });
  }
  if (centerCall) {
    centerCall.addEventListener('click', () => {
      if (window.MdtMap && !MdtMap.centerOnActiveCall()) {
        const note = document.getElementById('dispatchMapDetail');
        if (note) note.innerHTML = '<div class="gps-detail-empty muted">Aktyvių iškvietimų nėra.</div>';
      }
    });
  }
  if (refresh) {
    refresh.addEventListener('click', () => {
      if (window.MdtMap) MdtMap.resetView();
      refreshDispatch();
    });
  }
})();

function setDispatchControlsEnabled(enabled) {
  const ids = [
    'btnCreateCrew', 'btnJoinCrew', 'btnAddCrewMember', 'btnDeleteCrew',
    'btnLeaveCrew', 'btnSetCallsign', 'btnPanic', 'refreshDispatch',
  ];
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
  crewsEl.innerHTML = '';

  if (res && res.ok === false && res.msg) {
    callsEl.innerHTML = `<div class="muted">${escapeHtml(res.msg)}</div>`;
    lastDispatchPayload = res;
    renderDispatchMap(res);
    return;
  }

  if (res && res.readOnly) {
    const note = document.createElement('div');
    note.className = 'muted';
    note.textContent = 'Off duty — žemėlapis ir iškvietimai rodomi. Eik on duty, kad matytum vienetus ir valdytum dispatch.';
    callsEl.appendChild(note);
  }

  const calls = (res && res.ok !== false && res.calls) || (res && res.calls) || [];
  const crews = (res && res.crews) || [];
  const units = (res && res.units) || [];

  if (!calls.length) {
    if (!callsEl.children.length) {
      callsEl.innerHTML = '<div class="muted">Aktyvių iškvietimų nėra.</div>';
    }
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
        ${c.panic && !dispatchReadOnly ? `<div class="row"><button class="btn danger js-panic-off" data-callid="${escapeHtml(c.id)}">Išjungti PANIC</button></div>` : ''}
        ${dispatchReadOnly ? '' : callActions(c.id)}
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

  lastDispatchPayload = res;
  renderDispatchMap(res);

  document.querySelectorAll('.js-dispatch').forEach((btn) => {
    btn.onclick = () => nuiPost('dispatchAction', { callId: btn.dataset.callid, action: btn.dataset.action }).then((r) => {
      if (r && r.ok === false) return;
      refreshDispatch();
    });
  });
  document.querySelectorAll('.js-panic-off').forEach((btn) => {
    btn.onclick = () => nuiPost('crewAction', { action: 'panicOff', callId: btn.dataset.callid }).then((r) => {
      if (r && r.ok === false) return;
      refreshDispatch();
    });
  });
}

function refreshDispatch() {
  if (!mdtSessionActive || mdtSurveillanceLive) return Promise.resolve(null);
  return nuiPost('dispatchSnapshot', {}).then((res) => {
    if (!res) return null;
    renderDispatch(res);
    return res;
  });
}

document.getElementById('refreshDispatch').onclick = () => refreshDispatch();

window.addEventListener('resize', () => {
  if (!document.getElementById('panel-units')?.classList.contains('hidden') && window.MdtMap) {
    MdtMap.invalidate();
  }
});

function setMdtDocked(docked, skipPost) {
  mdtDocked = !!docked;
  app.classList.toggle('is-docked', mdtDocked);
  const btn = document.getElementById('btnDock');
  if (btn) btn.textContent = mdtDocked ? 'Visas' : 'Kampas';
  if (!skipPost) nuiPost('mdtSetDocked', { docked: mdtDocked });
  if (!mdtDocked) {
    app.style.left = '';
    app.style.top = '';
    app.style.right = '';
    app.style.bottom = '';
  }
  if (!document.getElementById('panel-units')?.classList.contains('hidden') && window.MdtMap) {
    requestAnimationFrame(() => MdtMap.invalidate());
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
function crewActionPost(payload) {
  return nuiPost('crewAction', payload).then((r) => {
    if (r && r.ok === false) {
      const el = document.getElementById('dispatchCrews');
      if (el && r.msg) {
        const note = document.createElement('div');
        note.className = 'muted';
        note.textContent = r.msg;
        el.prepend(note);
      }
      return r;
    }
    return refreshDispatch();
  });
}

document.getElementById('btnCreateCrew').onclick = () => crewActionPost({ action: 'create', callsign: document.getElementById('crewCallsign').value.trim() });
document.getElementById('btnJoinCrew').onclick = () => crewActionPost({ action: 'join', crewId: document.getElementById('crewIdInput').value.trim() });
document.getElementById('btnAddCrewMember').onclick = () => crewActionPost({
  action: 'addMember',
  crewId: document.getElementById('crewIdInput').value.trim(),
  targetId: Number(document.getElementById('crewMemberId').value),
});
document.getElementById('btnDeleteCrew').onclick = () => crewActionPost({ action: 'delete', crewId: document.getElementById('crewIdInput').value.trim() });
document.getElementById('btnLeaveCrew').onclick = () => crewActionPost({ action: 'leave' });
document.getElementById('btnSetCallsign').onclick = () => crewActionPost({ action: 'setCallsign', callsign: document.getElementById('crewCallsign').value.trim() });
document.getElementById('btnPanic').onclick = () => crewActionPost({ action: 'panic' });

let cctvSites = [];
let cctvCameras = [];
let cctvView = 'sites';
let selectedCctvSiteId = null;
let selectedCctvSite = null;
let selectedCctvId = null;
let cctvLiveActive = false;
let selectedBodycamId = null;
let cctvHudTimer = null;
let mdtTabBeforeSurveillance = null;
let cctvMaintenance = false;
let cctvMaintenanceMessage = '';
let bodycamMaintenance = false;
let bodycamMaintenanceMessage = '';
let mapMaintenance = false;
let mapMaintenanceMessage = '';

function applyMapMaintenanceFromOpen(data) {
  mapMaintenance = !!(data && data.mapMaintenance);
  mapMaintenanceMessage =
    (data && data.mapMaintenanceMessage) ||
    'GPS žemėlapio sistema laikinai neveikia. Dėl finansavimo skyrimo ir įrengimo kreipkitės į miesto merą.';
  applyMapMaintenanceUi();
}

function applyMapMaintenanceUi() {
  const wrap = document.querySelector('#panel-units .gps-map-wrap');
  const overlay = document.getElementById('mdtMapOffline');
  const msgEl = document.getElementById('mdtMapOfflineMsg');
  const toolbarIds = [
    'dispatchZoomIn',
    'dispatchZoomOut',
    'gpsResetView',
    'gpsCenterSelf',
    'gpsCenterCall',
    'refreshDispatchMap',
  ];

  if (wrap) wrap.classList.toggle('is-map-offline', mapMaintenance);
  if (overlay) overlay.classList.toggle('hidden', !mapMaintenance);
  if (msgEl) msgEl.textContent = mapMaintenanceMessage;

  toolbarIds.forEach((id) => {
    const el = document.getElementById(id);
    if (el) el.disabled = mapMaintenance;
  });

  if (mapMaintenance) {
    const sidebar = document.getElementById('dispatchMapDetail');
    if (sidebar) {
      sidebar.innerHTML = `<div class="surv-offline-status"><span class="surv-offline-title">Sistema neprieinama</span><p class="surv-offline-msg">${escapeHtml(mapMaintenanceMessage)}</p></div>`;
    }
  }
}

function applySurveillanceMaintenanceFromOpen(data) {
  const on = !!(data && data.surveillanceMaintenance);
  const msg =
    (data && data.surveillanceMaintenanceMessage) ||
    'Sistema laikinai neveikia. Dėl finansavimo skyrimo ir įrengimo kreipkitės į miesto merą.';
  cctvMaintenance = on;
  bodycamMaintenance = on;
  cctvMaintenanceMessage = msg;
  bodycamMaintenanceMessage = msg;
  applySurveillanceMaintenanceUi();
}

function applySurveillanceMaintenanceUi() {
  const cctvWrap = document.getElementById('cctvPanelWrap');
  const cctvOverlay = document.getElementById('cctvOffline');
  const cctvMsg = document.getElementById('cctvOfflineMsg');
  const cctvList = document.getElementById('cctvList');

  if (cctvWrap) cctvWrap.classList.toggle('is-surv-offline', cctvMaintenance);
  if (cctvOverlay) cctvOverlay.classList.toggle('hidden', !cctvMaintenance);
  if (cctvMsg) cctvMsg.textContent = cctvMaintenanceMessage;
  if (cctvMaintenance && cctvList) cctvList.innerHTML = '';

  const bodyWrap = document.getElementById('bodycamPanelWrap');
  const bodyOverlay = document.getElementById('bodycamOffline');
  const bodyMsg = document.getElementById('bodycamOfflineMsg');
  const bodyList = document.getElementById('bodycamList');

  if (bodyWrap) bodyWrap.classList.toggle('is-surv-offline', bodycamMaintenance);
  if (bodyOverlay) bodyOverlay.classList.toggle('hidden', !bodycamMaintenance);
  if (bodyMsg) bodyMsg.textContent = bodycamMaintenanceMessage;
  if (bodycamMaintenance && bodyList) bodyList.innerHTML = '';

  setSurvToolbarDisabled('cctv', cctvMaintenance);
  setSurvToolbarDisabled('bodycam', bodycamMaintenance);

  if (cctvMaintenance) {
    const crumb = document.getElementById('cctvBreadcrumb');
    if (crumb) crumb.textContent = 'Vaizdo stebėjimo tinklas • laikinai išjungtas';
  }
}

function setSurvMaintenancePreview(statusId, message) {
  const status = document.getElementById(statusId);
  if (!status) return;
  status.classList.add('surv-offline-status');
  status.innerHTML = `<span class="surv-offline-title">Sistema neprieinama</span><p class="surv-offline-msg">${escapeHtml(message)}</p>`;
}

function setSurvToolbarDisabled(kind, disabled) {
  const ids =
    kind === 'cctv'
      ? [
          'cctvFilter',
          'cctvSearch',
          'cctvRefresh',
          'cctvWatchBtn',
          'cctvStopBtn',
          'cctvPrevCam',
          'cctvNextCam',
          'cctvBackBtn',
          'cctvAudio',
        ]
      : ['bodycamRefresh', 'bodycamWatchBtn', 'bodycamStopBtn'];
  ids.forEach((id) => {
    const el = document.getElementById(id);
    if (el) el.disabled = !!disabled;
  });
}

function renderBodycamMaintenanceList(el, message) {
  if (message) bodycamMaintenanceMessage = message;
  bodycamMaintenance = true;
  if (el) el.innerHTML = '';
  applySurveillanceMaintenanceUi();
}

function activateMdtTab(tabId) {
  if (!tabId) return;
  const tab = document.querySelector(`.tab[data-tab="${tabId}"]`);
  if (tab) tab.click();
}
window.activateMdtTab = activateMdtTab;

function setSurveillanceOverlay(active, label, meta, cctvData) {
  const ov = document.getElementById('survOverlay');
  document.body.classList.toggle('mdt-surveillance-live', !!active);
  if (active && !mdtTabBeforeSurveillance) {
    mdtTabBeforeSurveillance = document.querySelector('.tab.active')?.dataset.tab || 'cctv';
  }
  if (!ov) return;
  ov.classList.toggle('hidden', !active);
  document.getElementById('survOverlayLabel').textContent = label || 'TIESIOGIAI';
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

function onSurveillanceEnded(restoreTab) {
  setSurveillanceOverlay(false);
  cctvLiveActive = false;
  mdtSurveillanceLive = false;
  document.getElementById('cctvLiveHint')?.classList.add('hidden');
  document.getElementById('bodycamLiveHint')?.classList.add('hidden');
  updateCctvNavButtons();
  if (restoreTab !== false) {
    const tab = mdtTabBeforeSurveillance || 'cctv';
    mdtTabBeforeSurveillance = null;
    activateMdtTab(tab);
  }
}

function stopSurveillanceUi(restoreTab) {
  const live =
    cctvLiveActive ||
    mdtSurveillanceLive ||
    document.body.classList.contains('mdt-surveillance-live');
  if (!live) return;
  nuiPost('cctvStop', {}, { force: true });
  nuiPost('bodycamStop', {}, { force: true });
  onSurveillanceEnded(restoreTab);
}

function getSelectedCctvSite() {
  if (selectedCctvSite) return selectedCctvSite;
  if (!selectedCctvSiteId) return null;
  return cctvSites.find((s) => s.id === selectedCctvSiteId) || null;
}

function getSiteCameras(site) {
  return (site && site.cameras) || [];
}

function updateCctvNavButtons() {
  const backBtn = document.getElementById('cctvBackBtn');
  const prevBtn = document.getElementById('cctvPrevCam');
  const nextBtn = document.getElementById('cctvNextCam');
  const site = getSelectedCctvSite();
  const cams = getSiteCameras(site);
  if (backBtn) backBtn.classList.toggle('hidden', cctvView !== 'site');
  const showCamNav = cctvView === 'site' && cams.length > 1;
  if (prevBtn) prevBtn.classList.toggle('hidden', !showCamNav);
  if (nextBtn) nextBtn.classList.toggle('hidden', !showCamNav);
}

function updateCctvBreadcrumb() {
  const el = document.getElementById('cctvBreadcrumb');
  if (!el) return;
  if (cctvView === 'sites') {
    el.textContent = 'Pasirink stebėjimo vietą (bankas, parduotuvė, PD…)';
    return;
  }
  const site = getSelectedCctvSite();
  if (!site) {
    el.textContent = '—';
    return;
  }
  const cam = getSiteCameras(site).find((c) => c.id === selectedCctvId);
  const camPart = cam ? ` → ${cam.label}` : '';
  el.textContent = `Vietos / ${site.label}${camPart}`;
}

function cctvShowSitesList() {
  cctvView = 'sites';
  selectedCctvSiteId = null;
  selectedCctvSite = null;
  selectedCctvId = null;
  const status = document.getElementById('cctvStatus');
  if (status) status.textContent = 'Pasirink vietą, tada kamerą objekte';
  updateCctvBreadcrumb();
  updateCctvNavButtons();
  renderCctvPanel();
}

function cctvOpenSite(siteId) {
  const site = cctvSites.find((s) => s.id === siteId);
  if (!site) return;
  cctvView = 'site';
  selectedCctvSiteId = siteId;
  selectedCctvSite = site;
  const cams = getSiteCameras(site);
  const firstOnline = cams.find((c) => c.online) || cams[0];
  selectedCctvId = firstOnline ? firstOnline.id : null;
  const status = document.getElementById('cctvStatus');
  if (status) {
    status.textContent = `${site.label} • ${site.cameraCount} kamera(-os)`;
  }
  updateCctvBreadcrumb();
  updateCctvNavButtons();
  renderCctvPanel();
}

function cctvSelectCamera(camId) {
  selectedCctvId = camId;
  const site = getSelectedCctvSite();
  const cam = getSiteCameras(site).find((c) => c.id === camId);
  const status = document.getElementById('cctvStatus');
  if (status && cam) {
    status.textContent = `${site ? site.label + ' — ' : ''}${cam.label}${cam.online ? '' : ' (neprieinama)'}`;
  }
  updateCctvBreadcrumb();
  renderCctvPanel();
}

function mdtActiveIncidentId() {
  return window.mrpMdtActiveIncidentId || null;
}

function cctvWatchSelected() {
  if (cctvMaintenance) return Promise.resolve();
  if (!selectedCctvId) return;
  const audio = document.getElementById('cctvAudio').checked;
  return nuiPost('cctvWatch', { camId: selectedCctvId, incidentId: mdtActiveIncidentId() }).then((res) => {
    if (!res || !res.ok) {
      document.getElementById('cctvStatus').textContent = (res && res.msg) || 'Nepavyko';
      stopSurveillanceUi();
      return;
    }
    cctvLiveActive = true;
    document.getElementById('cctvLiveHint')?.classList.remove('hidden');
    nuiPost('cctvToggleAudio', { enabled: audio });
  });
}

function cctvSwitchByDelta(delta) {
  const site = getSelectedCctvSite();
  const cams = getSiteCameras(site);
  if (!cams.length) return;
  let idx = cams.findIndex((c) => c.id === selectedCctvId);
  if (idx < 0) idx = 0;
  for (let i = 0; i < cams.length; i += 1) {
    idx = (idx + delta + cams.length) % cams.length;
    if (cams[idx].online) break;
  }
  selectedCctvId = cams[idx].id;
  updateCctvBreadcrumb();
  renderCctvPanel();
  const fn = cctvLiveActive
    ? nuiPost('cctvSwitch', { camId: selectedCctvId, incidentId: mdtActiveIncidentId() })
    : cctvWatchSelected();
  return fn;
}

function renderCctvPanel() {
  const el = document.getElementById('cctvList');
  if (!el) return;
  const q = (document.getElementById('cctvSearch').value || '').trim().toLowerCase();
  const zone = document.getElementById('cctvFilter').value;
  el.innerHTML = '';

  if (cctvMaintenance) {
    cctvView = 'sites';
    applySurveillanceMaintenanceUi();
    return;
  }

  if (cctvView === 'sites') {
    const rows = cctvSites.filter((s) => {
      if (zone && s.zone !== zone) return false;
      if (!q) return true;
      const hay = `${s.label || ''} ${s.id || ''} ${s.zoneLabel || ''}`.toLowerCase();
      return hay.includes(q);
    });
    if (!rows.length) {
      el.innerHTML = '<div class="muted">Vietų nerasta.</div>';
      return;
    }
    rows.forEach((s) => {
      const card = document.createElement('button');
      card.type = 'button';
      card.className = 'card surv-card surv-site-card';
      const st = s.allOnline
        ? '<span class="badge ok">VEIKIA</span>'
        : s.onlineCount > 0
          ? `<span class="badge warn">${s.onlineCount}/${s.cameraCount}</span>`
          : '<span class="badge off">NEPRIEINAMA</span>';
      card.innerHTML = `<h4>${escapeHtml(s.label)}</h4><div class="muted">${escapeHtml(s.zoneLabel || s.zone)} • ${s.cameraCount} kamera(-os) • ${st}</div>`;
      card.onclick = () => cctvOpenSite(s.id);
      card.ondblclick = () => {
        cctvOpenSite(s.id);
        const first = getSiteCameras(s).find((c) => c.online) || getSiteCameras(s)[0];
        if (first) {
          selectedCctvId = first.id;
          cctvWatchSelected();
        }
      };
      el.appendChild(card);
    });
    return;
  }

  const site = getSelectedCctvSite();
  const cams = getSiteCameras(site);
  if (!site || !cams.length) {
    el.innerHTML = '<div class="muted">Šioje vietoje kamerų nėra.</div>';
    return;
  }
  cams.forEach((c) => {
    const card = document.createElement('button');
    card.type = 'button';
    card.className = 'card surv-card' + (selectedCctvId === c.id ? ' selected' : '');
    const st = c.online ? '<span class="badge ok">VEIKIA</span>' : '<span class="badge off">NEPRIEINAMA</span>';
    const prop = c.hasProp ? ' • prop' : '';
    card.innerHTML = `<h4>${escapeHtml(c.label)}</h4><div class="muted">${st}${c.audio ? ' • garsas' : ''}${prop}</div>`;
    card.onclick = () => cctvSelectCamera(c.id);
    card.ondblclick = () => {
      cctvSelectCamera(c.id);
      cctvWatchSelected();
    };
    el.appendChild(card);
  });
}

function refreshCctvList() {
  if (!mdtSessionActive) return Promise.resolve(null);
  return nuiPost('cctvList', {}).then((res) => {
    const listEl = document.getElementById('cctvList');
    if (!res || !res.ok) {
      if (listEl) {
        listEl.innerHTML =
          '<div class="muted">Vaizdo stebėjimas nepasiekiamas. Būkite <strong>policijoje</strong> ir <strong>tarnyboje</strong>.</div>';
      }
      return;
    }
    cctvMaintenance = res.maintenance === true;
    if (cctvMaintenance) {
      cctvMaintenanceMessage =
        res.maintenanceMessage ||
        'Sistema laikinai neveikia. Dėl finansavimo skyrimo ir įrengimo kreipkitės į miesto merą.';
      cctvSites = res.sites || [];
      cctvCameras = [];
      cctvView = 'sites';
      selectedCctvSiteId = null;
      selectedCctvSite = null;
      selectedCctvId = null;
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
      sel.onchange = renderCctvPanel;
      document.getElementById('cctvSearch').oninput = renderCctvPanel;
      updateCctvNavButtons();
      renderCctvPanel();
      return;
    }
    setSurvToolbarDisabled('cctv', false);
    const cctvWrap = document.getElementById('cctvPanelWrap');
    const cctvOverlay = document.getElementById('cctvOffline');
    if (cctvWrap) cctvWrap.classList.remove('is-surv-offline');
    if (cctvOverlay) cctvOverlay.classList.add('hidden');
    const status = document.getElementById('cctvStatus');
    if (status) status.classList.remove('surv-offline-status');
    cctvSites = res.sites || [];
    cctvCameras = res.cameras || [];
    if (cctvView === 'site' && selectedCctvSiteId) {
      selectedCctvSite = cctvSites.find((s) => s.id === selectedCctvSiteId) || null;
    }
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
    sel.onchange = renderCctvPanel;
    document.getElementById('cctvSearch').oninput = renderCctvPanel;
    updateCctvBreadcrumb();
    updateCctvNavButtons();
    renderCctvPanel();
  });
}

document.getElementById('cctvRefresh').onclick = () => refreshCctvList();
document.getElementById('cctvBackBtn').onclick = () => cctvShowSitesList();
document.getElementById('cctvPrevCam').onclick = () => cctvSwitchByDelta(-1);
document.getElementById('cctvNextCam').onclick = () => cctvSwitchByDelta(1);
document.getElementById('cctvWatchBtn').onclick = () => cctvWatchSelected();
document.getElementById('cctvStopBtn').onclick = () => {
  nuiPost('cctvStop', {}).then(() => stopSurveillanceUi());
};
document.getElementById('cctvAudio').onchange = (e) => {
  nuiPost('cctvToggleAudio', { enabled: e.target.checked });
};

function renderBodycamList() {
  const el = document.getElementById('bodycamList');
  el.innerHTML = '';
  if (bodycamMaintenance) {
    renderBodycamMaintenanceList(el, bodycamMaintenanceMessage);
    return Promise.resolve();
  }
  return nuiPost('bodycamList', {}).then((res) => {
    if (res && res.maintenance) {
      bodycamMaintenance = true;
      bodycamMaintenanceMessage =
        res.maintenanceMessage ||
        'Sistema laikinai neveikia. Dėl finansavimo skyrimo ir įrengimo kreipkitės į miesto merą.';
      renderBodycamMaintenanceList(el, bodycamMaintenanceMessage);
      return;
    }
    bodycamMaintenance = false;
    setSurvToolbarDisabled('bodycam', false);
    const bodyWrap = document.getElementById('bodycamPanelWrap');
    const bodyOverlay = document.getElementById('bodycamOffline');
    if (bodyWrap) bodyWrap.classList.remove('is-surv-offline');
    if (bodyOverlay) bodyOverlay.classList.add('hidden');
    const status = document.getElementById('bodycamStatus');
    if (status) {
      status.classList.remove('surv-offline-status');
      if (!selectedBodycamId) status.textContent = 'Pasirink pareigūno bodycam';
    }
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
      const tag = f.callsign ? escapeHtml(f.callsign) : escapeHtml(f.name || 'Pareigūnas');
      card.innerHTML = `<h4>${escapeHtml(f.name)}</h4><div class="muted">${tag}${crew}${batt}</div><span class="badge ok">TIESIOGIAI</span>`;
      card.onclick = () => {
        selectedBodycamId = f.serverId;
        document.getElementById('bodycamStatus').textContent = `${f.name}${f.callsign ? ' • ' + f.callsign : ''}`;
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
  if (bodycamMaintenance) return;
  if (!selectedBodycamId) return;
  nuiPost('bodycamWatch', { targetId: selectedBodycamId, incidentId: mdtActiveIncidentId() }).then((res) => {
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
