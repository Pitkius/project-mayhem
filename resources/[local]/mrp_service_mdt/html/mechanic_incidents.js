/*
  MDT V2 Phase 5 — Mechanic repair bylos skirtukas (Service MDT, tik mechanic).
*/
(function () {
  'use strict';

  const state = {
    ready: false,
    service: 'mechanic',
    meta: null,
    perms: {},
    vocab: {},
    statusLabels: {},
    rows: [],
    selected: null,
    bundle: null,
    nearby: [],
  };

  const esc = (value) => (typeof window.escapeHtml === 'function'
    ? window.escapeHtml(value)
    : String(value == null ? '' : value));

  function post(endpoint, data) {
    if (typeof window.nuiPost !== 'function') return Promise.resolve(null);
    const payload = Object.assign({ service: 'mechanic' }, data || {});
    return window.nuiPost(endpoint, payload, { force: true });
  }

  const el = (id) => document.getElementById(id);

  const EVENT_LABELS = {
    incident_created: 'Byla sukurta',
    status_changed: 'Statusas pakeistas',
    officer_attached: 'Mechanikas byloje',
    officer_role_changed: 'Mechaniko rolė',
    party_attached: 'Pridėtas klientas',
    vehicle_attached: 'Pridėtas TP',
    report_filed: 'Kortelė užpildyta',
    report_updated: 'Kortelė atnaujinta',
    diagnostic_logged: 'Diagnostika',
    repair_work: 'Atliktas darbas',
    part_replaced: 'Pakeista dalis',
    ref_linked: 'Sąskaita / nuoroda',
    case_updated: 'Bylos duomenys',
  };

  function labelOf(map, key, fallback) {
    if (!map || key == null) return fallback || String(key == null ? '—' : key);
    const value = map[String(key)];
    if (typeof value === 'string') return value;
    if (value && typeof value.label === 'string') return value.label;
    return fallback || String(key);
  }

  function statusLabel(status) {
    return labelOf(state.statusLabels, status, status);
  }

  function options(map, selected, placeholder) {
    const out = [];
    if (placeholder) out.push(`<option value="">${esc(placeholder)}</option>`);
    Object.keys(map || {}).forEach((key) => {
      const isSel = String(selected || '') === key ? ' selected' : '';
      out.push(`<option value="${esc(key)}"${isSel}>${esc(labelOf(map, key))}</option>`);
    });
    return out.join('');
  }

  function shortTime(value) {
    if (!value) return '';
    const text = String(value).replace('T', ' ').replace('Z', '');
    return text.length > 16 ? text.slice(0, 16) : text;
  }

  function isClosedStatus(status) {
    return ['completed', 'archived', 'cancelled', 'expired', 'duplicate', 'merged', 'rejected', 'timeout']
      .indexOf(String(status)) !== -1;
  }

  function renderList() {
    const box = el('mechIncList');
    if (!box) return;
    box.innerHTML = '';
    if (!state.rows.length) {
      box.innerHTML = '<div class="muted">Bylų nerasta.</div>';
      return;
    }
    state.rows.forEach((row) => {
      const card = document.createElement('button');
      card.type = 'button';
      card.className = 'card inc-card' + (String(state.selected) === String(row.id) ? ' selected' : '');
      const closed = isClosedStatus(row.status);
      const mech = row.mechanic || {};
      const bits = [];
      if (row.unit_labels) bits.push(esc(row.unit_labels));
      if (mech.fault_label) bits.push(esc(mech.fault_label));
      if (Number(mech.invoice_total) > 0) bits.push(`${Number(mech.invoice_total)} €`);
      if (Number(mech.tow_completed) === 1) bits.push('nutempta');
      card.innerHTML = `
        <div class="inc-card-top">
          <span class="inc-num">${esc(row.public_number)}</span>
          <span class="inc-pill ${closed ? 'closed' : 'open'}">${esc(statusLabel(row.status))}</span>
        </div>
        <div>${esc(row.summary || '—')}</div>
        <div class="muted">${esc(shortTime(row.created_at))}${bits.length ? ' · ' + bits.join(' · ') : ''}</div>
      `;
      card.onclick = () => openIncident(row.id);
      box.appendChild(card);
    });
  }

  function loadList() {
    const box = el('mechIncList');
    if (box && !state.rows.length) box.innerHTML = '<div class="muted">Kraunama…</div>';
    return post('incidentList', {
      openOnly: el('mechIncOpenOnly') ? el('mechIncOpenOnly').checked : true,
      mine: el('mechIncMine') ? el('mechIncMine').checked : false,
      search: el('mechIncSearch') ? el('mechIncSearch').value.trim() : '',
      limit: 30,
    }).then((res) => {
      if (!res || !res.ok) {
        if (box) box.innerHTML = `<div class="muted">${esc((res && res.message) || 'Nepavyko užkrauti.')}</div>`;
        return;
      }
      state.rows = res.rows || [];
      renderList();
    });
  }

  function setStatus(message, ok) {
    const node = document.querySelector('#mechIncDetail .inc-status');
    if (!node) return;
    node.textContent = message || '';
    node.className = 'inc-status' + (message ? (ok ? ' ok' : ' err') : '');
  }

  function openIncident(ref) {
    state.selected = ref;
    const box = el('mechIncDetail');
    if (box) box.innerHTML = '<div class="muted">Kraunama byla…</div>';
    return post('incidentGet', { ref: ref }).then((res) => {
      if (!res || !res.ok || !res.bundle) {
        if (box) box.innerHTML = `<div class="muted">${esc((res && res.message) || 'Bylos užkrauti nepavyko.')}</div>`;
        return;
      }
      state.bundle = res.bundle;
      state.selected = res.bundle.incident.id;
      renderDetail();
      renderList();
    });
  }

  function reloadDetail(message, ok) {
    return openIncident(state.selected).then(() => {
      if (message) setStatus(message, ok !== false);
    });
  }

  function detailQuery(sel) {
    const root = el('mechIncDetail');
    return root ? root.querySelector(sel) : null;
  }

  function valueOf(sel) {
    const node = detailQuery(sel);
    if (!node) return '';
    if (node.type === 'checkbox') return node.checked;
    return node.value;
  }

  function bindClick(sel, fn) {
    const node = detailQuery(sel);
    if (node) node.onclick = fn;
  }

  function handle(promise) {
    promise.then((res) => {
      if (!res) return setStatus('Ryšio klaida.', false);
      if (!res.ok) return setStatus(res.message || 'Klaida.', false);
      reloadDetail(res.message || 'Išsaugota.', true);
    });
  }

  function renderDetail() {
    const box = el('mechIncDetail');
    const bundle = state.bundle;
    if (!box || !bundle || !bundle.incident) return;

    const inc = bundle.incident;
    const mech = bundle.mechanic || {};
    const report = bundle.report || {};
    const closed = isClosedStatus(inc.status);

    box.innerHTML = `
      <div class="inc-detail-head">
        <h3>${esc(inc.public_number)}</h3>
        <span class="inc-pill ${closed ? 'closed' : 'open'}">${esc(statusLabel(inc.status))}</span>
        ${Number(mech.tow_requested) === 1 ? '<span class="inc-pill alert">Nutempimas</span>' : ''}
        ${Number(mech.tow_completed) === 1 ? '<span class="inc-pill closed">NUTEMPTA</span>' : ''}
      </div>
      <div class="muted">${esc(inc.summary || '')}</div>
      <div class="inc-meta-grid">
        <div><span>Sprendimas</span><strong>${esc(labelOf(state.vocab.dispositions, mech.disposition))}</strong></div>
        <div><span>Dirbtuvės</span><strong>${esc(mech.shop || '—')}</strong></div>
        <div><span>Sąskaitos</span><strong>${Number(mech.invoice_total || 0)} €</strong></div>
        <div><span>Trukmė</span><strong>${mech.duration_minutes != null ? esc(mech.duration_minutes) + ' min' : '—'}</strong></div>
      </div>
      ${state.perms.transition && !closed ? `
        <div class="row">
          <select class="inc-transition">${options(state.statusLabels, inc.status)}</select>
          <button type="button" class="btn inc-transition-go">Taikyti statusą</button>
        </div>` : ''}
      <div class="grid2">
        <label>Gedimas / aprašymas
          <input type="text" class="inc-fault-label" maxlength="200" value="${esc(mech.fault_label || '')}" />
        </label>
        <label>Kategorija
          <select class="inc-fault-code">${options(state.vocab.faults || {}, mech.fault_code, '—')}</select>
        </label>
        <label>Sprendimas
          <select class="inc-disposition">${options(state.vocab.dispositions || {}, mech.disposition || 'pending')}</select>
        </label>
        <label>Dirbtuvės
          <input type="text" class="inc-shop" maxlength="64" value="${esc(mech.shop || '')}" />
        </label>
        <label>Trukmė (min)
          <input type="number" class="inc-duration" min="0" max="9999" value="${esc(mech.duration_minutes != null ? mech.duration_minutes : '')}" />
        </label>
        <label>Diagnostikos santrauka
          <input type="text" class="inc-diag-summary" maxlength="512" value="${esc(mech.diagnostics_summary || '')}" />
        </label>
        <label class="inc-check"><input type="checkbox" class="inc-tow-requested" ${Number(mech.tow_requested) === 1 ? 'checked' : ''} /> Reikalingas nutempimas</label>
        <label class="inc-check"><input type="checkbox" class="inc-tow-completed" ${Number(mech.tow_completed) === 1 ? 'checked' : ''} /> Nutempimas atliktas</label>
      </div>
      <label>Rekomendacijos
        <textarea class="inc-recommendations" maxlength="1024" placeholder="Tolimesni darbai, profilaktika…">${esc(mech.recommendations || '')}</textarea>
      </label>
      ${renderMechanicsSection(bundle)}
      ${renderPartiesSection(bundle)}
      ${renderVehiclesSection(bundle)}
      ${renderDiagnosticsSection(bundle)}
      ${renderWorkSection(bundle)}
      ${renderPartsSection(bundle)}
      ${renderRefsSection(bundle)}
      ${renderReportSection(report)}
      ${renderTimelineSection(bundle)}
      <p class="inc-status" role="status"></p>
      ${state.perms.report && !closed ? '<button type="button" class="btn primary inc-case-save">Išsaugoti bylos duomenis</button>' : ''}
    `;

    bindDetailHandlers(inc.id, closed);
    fillNearbySelects();
  }

  function renderMechanicsSection(bundle) {
    const rows = (bundle.officers || []).map((o) =>
      `<li><span class="inc-row-main">${esc(o.callsign || o.display_name || o.citizenid)} · ${esc(labelOf(state.vocab.mechanicRoles, o.role))}</span></li>`
    ).join('');
    return `
      <details class="inc-section" open>
        <summary>Mechanikai (${(bundle.officers || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Mechanikų nėra.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="row">
            <select class="inc-mechanic-role">${options(state.vocab.mechanicRoles || {}, 'assist')}</select>
            <button type="button" class="btn inc-mechanic-join">Prisidėti</button>
            <select class="inc-mechanic-nearby"><option value="">Šalia esantis mechanikas…</option></select>
            <button type="button" class="btn inc-mechanic-add">Pridėti</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function renderPartiesSection(bundle) {
    const roles = state.vocab.partyRoles || { client: 'Klientas' };
    const rows = (bundle.parties || []).map((p) =>
      `<li><span class="inc-row-main">${esc(p.display_name || p.citizenid)} · ${esc(labelOf(roles, p.role))}</span>
        ${state.perms.report ? `<button type="button" class="btn inc-mini inc-party-del" data-id="${esc(p.id)}">Pašalinti</button>` : ''}</li>`
    ).join('');
    return `
      <details class="inc-section" open>
        <summary>Klientai / dalyviai</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Dalyvių nėra.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="row">
            <select class="inc-party-nearby"><option value="">Šalia esantis asmuo…</option></select>
            <input type="text" class="inc-party-cid" placeholder="arba citizenid" maxlength="64" />
            <select class="inc-party-role">${options(roles, 'client')}</select>
            <button type="button" class="btn inc-party-add">Pridėti</button>
            <button type="button" class="btn inc-nearby-refresh">Atnaujinti šalia</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function renderVehiclesSection(bundle) {
    const roles = state.vocab.vehicleRoles || { subject: 'Remontuojamas TP' };
    const rows = (bundle.vehicles || []).map((v) =>
      `<li><span class="inc-row-main">${esc(v.plate || '—')} · ${esc(labelOf(roles, v.role))}${v.model ? ' · ' + esc(v.model) : ''}</span>
        ${state.perms.report ? `<button type="button" class="btn inc-mini inc-vehicle-del" data-id="${esc(v.id)}">Pašalinti</button>` : ''}</li>`
    ).join('');
    return `
      <details class="inc-section" open>
        <summary>Transporto priemonės</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">TP neįrašytas.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="row">
            <input type="text" class="inc-vehicle-plate" placeholder="Numeriai ABC123" maxlength="16" />
            <select class="inc-vehicle-role">${options(roles, 'subject')}</select>
            <button type="button" class="btn inc-vehicle-add">Pridėti TP</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function renderDiagnosticsSection(bundle) {
    const rows = (bundle.diagnostics || []).map((d) =>
      `<li><span class="inc-row-main">${esc(labelOf(state.vocab.diagTypes, d.diag_type))} · ${esc(labelOf(state.vocab.diagResults, d.result))}${d.diag_label ? ' — ' + esc(d.diag_label) : ''}</span></li>`
    ).join('');
    return `
      <details class="inc-section">
        <summary>Diagnostika (${(bundle.diagnostics || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Diagnostikos neįrašyta.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="row">
            <select class="inc-diag-type">${options(state.vocab.diagTypes || {}, 'obd_scan')}</select>
            <select class="inc-diag-result">${options(state.vocab.diagResults || {}, 'unknown')}</select>
            <input type="text" class="inc-diag-label" placeholder="Aprašymas" maxlength="128" />
            <button type="button" class="btn inc-diag-add">Fiksuoti</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function renderWorkSection(bundle) {
    const rows = (bundle.work || []).map((w) =>
      `<li><span class="inc-row-main">${esc(labelOf(state.vocab.workTypes, w.work_type))}${w.duration_minutes ? ' · ' + esc(w.duration_minutes) + ' min' : ''}</span></li>`
    ).join('');
    return `
      <details class="inc-section">
        <summary>Atlikti darbai (${(bundle.work || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Darbo neįrašyta.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="row">
            <select class="inc-work-type">${options(state.vocab.workTypes || {}, 'repair')}</select>
            <input type="number" class="inc-work-duration" placeholder="min" min="0" max="9999" />
            <button type="button" class="btn inc-work-add">Fiksuoti</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function renderPartsSection(bundle) {
    const rows = (bundle.parts || []).map((p) =>
      `<li><span class="inc-row-main">${esc(p.part_label)} ×${esc(p.quantity || 1)} · ${esc(labelOf(state.vocab.partCategories, p.part_category))}</span></li>`
    ).join('');
    return `
      <details class="inc-section">
        <summary>Pakeistos dalys (${(bundle.parts || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Dalių neįrašyta.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="row">
            <input type="text" class="inc-part-label" placeholder="Dalies pavadinimas" maxlength="128" />
            <select class="inc-part-category">${options(state.vocab.partCategories || {}, 'other')}</select>
            <input type="number" class="inc-part-qty" value="1" min="1" max="999" />
            <button type="button" class="btn inc-part-add">Fiksuoti</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function renderRefsSection(bundle) {
    const rows = (bundle.refs || []).map((r) =>
      `<li><span class="inc-row-main">${esc(labelOf(state.vocab.refTypes, r.ref_type))}${r.amount ? ': ' + esc(r.amount) + ' €' : ''} ${r.label ? '· ' + esc(r.label) : ''}</span></li>`
    ).join('');
    return `
      <details class="inc-section" open>
        <summary>Sąskaitos / nutempimas / nuorodos</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Nuorodų nėra. Sąskaitos iš „Sąskaitos" skirtuko automatiškai prisegamos prie aktyvios bylos.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="row">
            <input type="text" class="inc-tow-label" placeholder="Nutempimo aprašymas" maxlength="200" />
            <input type="text" class="inc-tow-plate" placeholder="TP numeriai" maxlength="16" />
            <button type="button" class="btn inc-tow-add">Susieti nutempimą</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function renderReportSection(report) {
    return `
      <details class="inc-section inc-report" open>
        <summary>Remonto kortelė${report.revision ? ' (v' + esc(report.revision) + ')' : ''}</summary>
        <div class="inc-section-body">
          <input type="text" class="inc-report-title" placeholder="Antraštė" maxlength="200" value="${esc(report.title || '')}"${state.perms.report ? '' : ' readonly'} />
          <textarea class="inc-report-body" placeholder="Gedimo aprašymas, atlikti darbai, išvados…"${state.perms.report ? '' : ' readonly'}>${esc(report.body || '')}</textarea>
          ${state.perms.report ? '<button type="button" class="btn primary inc-report-save">Išsaugoti kortelę</button>' : ''}
        </div>
      </details>`;
  }

  function renderTimelineSection(bundle) {
    const rows = (bundle.timeline || []).slice().reverse().map((row) => {
      const label = EVENT_LABELS[row.event_type] || row.event_type;
      return `<li><span class="inc-tl-when">${esc(shortTime(row.created_at))}</span>${esc(label)}<span class="inc-tl-who">${row.actor_name ? ' · ' + esc(row.actor_name) : ''}</span></li>`;
    }).join('');
    return `
      <details class="inc-section">
        <summary>Laiko juosta</summary>
        <div class="inc-section-body"><ul class="inc-timeline">${rows || '<li class="muted">Įrašų nėra.</li>'}</ul></div>
      </details>`;
  }

  function bindDetailHandlers(incidentId, closed) {
    if (closed) return;

    bindClick('.inc-transition-go', () => {
      handle(post('incidentTransition', { incidentId: incidentId, status: valueOf('.inc-transition') }));
    });

    bindClick('.inc-case-save', () => {
      handle(post('incidentUpdateCase', {
        incidentId: incidentId,
        fault_label: valueOf('.inc-fault-label'),
        fault_code: valueOf('.inc-fault-code'),
        disposition: valueOf('.inc-disposition'),
        shop: valueOf('.inc-shop'),
        duration_minutes: valueOf('.inc-duration') || null,
        diagnostics_summary: valueOf('.inc-diag-summary'),
        recommendations: valueOf('.inc-recommendations'),
        tow_requested: valueOf('.inc-tow-requested'),
        tow_completed: valueOf('.inc-tow-completed'),
      }));
    });

    bindClick('.inc-report-save', () => {
      handle(post('incidentSaveReport', {
        incidentId: incidentId,
        title: valueOf('.inc-report-title'),
        body: valueOf('.inc-report-body'),
      }));
    });

    bindClick('.inc-mechanic-join', () => {
      handle(post('incidentAttachUnit', { incidentId: incidentId, role: valueOf('.inc-mechanic-role') }));
    });

    bindClick('.inc-mechanic-add', () => {
      const src = valueOf('.inc-mechanic-nearby');
      if (!src) return setStatus('Pasirink mechaniką iš sąrašo.', false);
      handle(post('incidentAttachUnit', { incidentId: incidentId, role: valueOf('.inc-mechanic-role'), targetSource: src }));
    });

    bindClick('.inc-party-add', () => {
      const nearby = valueOf('.inc-party-nearby');
      const cid = valueOf('.inc-party-cid');
      if (!nearby && !cid) return setStatus('Pasirink asmenį arba įvesk citizenid.', false);
      handle(post('incidentAttachParty', {
        incidentId: incidentId,
        targetSource: nearby || undefined,
        citizenid: cid || undefined,
        role: valueOf('.inc-party-role'),
      }));
    });

    bindClick('.inc-nearby-refresh', () => loadNearby().then(() => fillNearbySelects()));

    const detail = el('mechIncDetail');
    if (detail) {
      detail.querySelectorAll('.inc-party-del').forEach((btn) => {
        btn.onclick = () => handle(post('incidentDetachParty', { incidentId: incidentId, partyId: btn.dataset.id }));
      });
      detail.querySelectorAll('.inc-vehicle-del').forEach((btn) => {
        btn.onclick = () => handle(post('incidentDetachVehicle', { incidentId: incidentId, vehicleId: btn.dataset.id }));
      });
    }

    bindClick('.inc-vehicle-add', () => {
      const plate = valueOf('.inc-vehicle-plate');
      if (!plate) return setStatus('Įvesk numerius.', false);
      handle(post('incidentAttachVehicle', { incidentId: incidentId, plate: plate, role: valueOf('.inc-vehicle-role') }));
    });

    bindClick('.inc-diag-add', () => {
      handle(post('incidentAddDiagnostic', {
        incidentId: incidentId,
        diag_type: valueOf('.inc-diag-type'),
        result: valueOf('.inc-diag-result'),
        diag_label: valueOf('.inc-diag-label'),
      }));
    });

    bindClick('.inc-work-add', () => {
      handle(post('incidentAddWork', {
        incidentId: incidentId,
        work_type: valueOf('.inc-work-type'),
        duration_minutes: valueOf('.inc-work-duration') || null,
      }));
    });

    bindClick('.inc-part-add', () => {
      const label = valueOf('.inc-part-label');
      if (!label) return setStatus('Įvesk dalies pavadinimą.', false);
      handle(post('incidentAddPart', {
        incidentId: incidentId,
        part_label: label,
        part_category: valueOf('.inc-part-category'),
        quantity: Number(valueOf('.inc-part-qty')) || 1,
      }));
    });

    bindClick('.inc-tow-add', () => {
      handle(post('incidentAddTowRef', {
        incidentId: incidentId,
        label: valueOf('.inc-tow-label') || 'Nutempimas',
        plate: valueOf('.inc-tow-plate') || undefined,
      }));
    });
  }

  function loadNearby() {
    if (!state.perms.search) return Promise.resolve();
    return post('incidentNearby', {}).then((res) => {
      state.nearby = (res && res.ok && res.rows) || [];
    });
  }

  function fillNearbySelects() {
    const people = detailQuery('.inc-party-nearby');
    const mechanics = detailQuery('.inc-mechanic-nearby');
    if (people) {
      people.innerHTML = '<option value="">Šalia esantis asmuo…</option>' + state.nearby.map((p) =>
        `<option value="${esc(p.source)}">${esc(p.name || p.citizenid)} · ${esc(p.distance)} m</option>`).join('');
    }
    if (mechanics) {
      mechanics.innerHTML = '<option value="">Šalia esantis mechanikas…</option>' + state.nearby
        .filter((p) => p.isMechanic && p.onduty)
        .map((p) => `<option value="${esc(p.source)}">${esc(p.callsign || p.name || p.citizenid)} · ${esc(p.distance)} m</option>`)
        .join('');
    }
  }

  function loadMeta() {
    return post('incidentMeta', {}).then((res) => {
      if (!res || !res.ok) {
        const box = el('mechIncDetail');
        if (box) box.innerHTML = `<div class="muted">${esc((res && res.message) || 'Bylų sistema neprieinama.')}</div>`;
        return false;
      }
      state.meta = res;
      state.perms = res.permissions || {};
      state.vocab = res.vocabulary || {};
      state.statusLabels = res.statusLabels || {};
      state.ready = true;
      return true;
    });
  }

  function onTabOpened() {
    const first = !state.ready;
    (first ? loadMeta() : Promise.resolve(true)).then((ok) => {
      if (!ok) return;
      loadNearby();
      loadList();
      if (state.selected) openIncident(state.selected);
    });
  }

  function bindStatic() {
    const tab = el('tabIncidents');
    if (tab) tab.addEventListener('click', () => {
      if (window.activeService === 'mechanic') onTabOpened();
    });

    const refresh = el('mechIncRefresh');
    if (refresh) refresh.onclick = () => loadList();

    const search = el('mechIncSearch');
    if (search) {
      search.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') loadList();
      });
    }
    ['mechIncOpenOnly', 'mechIncMine'].forEach((id) => {
      const node = el(id);
      if (node) node.onchange = () => loadList();
    });

    const toggle = el('mechIncNewToggle');
    const createBox = el('mechIncCreateBox');
    if (toggle && createBox) {
      toggle.onclick = () => createBox.classList.toggle('hidden');
    }

    const create = el('mechIncCreate');
    if (create) {
      create.onclick = () => {
        const status = el('mechIncCreateStatus');
        const summary = el('mechIncNewSummary') ? el('mechIncNewSummary').value.trim() : '';
        if (summary.length < 3) {
          if (status) status.textContent = 'Įvesk trumpą aprašymą.';
          return;
        }
        if (status) status.textContent = 'Kuriama…';
        post('incidentCreate', {
          summary: summary,
          fault_label: el('mechIncNewFault') ? el('mechIncNewFault').value.trim() : '',
        }).then((res) => {
          if (!res || !res.ok) {
            if (status) status.textContent = (res && res.message) || 'Nepavyko sukurti.';
            return;
          }
          if (status) status.textContent = res.message || 'Byla sukurta.';
          if (el('mechIncNewSummary')) el('mechIncNewSummary').value = '';
          if (createBox) createBox.classList.add('hidden');
          loadList().then(() => openIncident(res.incident.id));
        });
      };
    }
  }

  window.addEventListener('message', (e) => {
    const d = e.data;
    if (!d || d.action !== 'open') return;
    const isMech = d.data && d.data.service === 'mechanic';
    const show = isMech && d.data.enableIncidents === true;
    const emsPanel = el('emsIncPanel');
    const mechPanel = el('mechIncPanel');
    if (emsPanel) emsPanel.classList.toggle('hidden', isMech);
    if (mechPanel) mechPanel.classList.toggle('hidden', !show);
    if (!show) return;
    state.ready = false;
    state.rows = [];
    state.selected = null;
    state.bundle = null;
    const detail = el('mechIncDetail');
    if (detail) detail.innerHTML = '<div class="muted">Pasirink bylą arba sukurk naują.</div>';
    const tab = el('tabIncidents');
    if (tab && tab.classList.contains('active')) onTabOpened();
  });

  bindStatic();
})();
