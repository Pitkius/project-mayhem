/*
  MDT V2 Phase 4 — EMS medicininės bylos skirtukas (Service MDT, tik EMS).
*/
(function () {
  'use strict';

  const state = {
    ready: false,
    service: 'ems',
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
    const payload = Object.assign({ service: 'ems' }, data || {});
    return window.nuiPost(endpoint, payload, { force: true });
  }

  const el = (id) => document.getElementById(id);

  const EVENT_LABELS = {
    incident_created: 'Byla sukurta',
    status_changed: 'Statusas pakeistas',
    officer_attached: 'Medikas byloje',
    officer_role_changed: 'Mediko rolė',
    party_attached: 'Pridėtas dalyvis',
    report_filed: 'Kortelė užpildyta',
    report_updated: 'Kortelė atnaujinta',
    med_administered: 'Vaistas',
    medical_action: 'Procedūra',
    equipment_used: 'Įranga',
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
    const box = el('emsIncList');
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
      const med = row.medical || {};
      const bits = [];
      if (row.unit_labels) bits.push(esc(row.unit_labels));
      if (med.presentation_label) bits.push(esc(med.presentation_label));
      if (Number(med.invoice_total) > 0) bits.push(`${Number(med.invoice_total)} €`);
      if (Number(med.transported) === 1) bits.push('transportuotas');
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
    const box = el('emsIncList');
    if (box && !state.rows.length) box.innerHTML = '<div class="muted">Kraunama…</div>';
    return post('incidentList', {
      openOnly: el('emsIncOpenOnly') ? el('emsIncOpenOnly').checked : true,
      mine: el('emsIncMine') ? el('emsIncMine').checked : false,
      search: el('emsIncSearch') ? el('emsIncSearch').value.trim() : '',
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
    const node = document.querySelector('#emsIncDetail .inc-status');
    if (!node) return;
    node.textContent = message || '';
    node.className = 'inc-status' + (message ? (ok ? ' ok' : ' err') : '');
  }

  function openIncident(ref) {
    state.selected = ref;
    const box = el('emsIncDetail');
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
    const root = el('emsIncDetail');
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
    const box = el('emsIncDetail');
    const bundle = state.bundle;
    if (!box || !bundle || !bundle.incident) return;

    const inc = bundle.incident;
    const med = bundle.medical || {};
    const report = bundle.report || {};
    const closed = isClosedStatus(inc.status);
    const triageClass = med.triage_level === 'red' || med.triage_level === 'black' ? 'alert' : 'open';

    box.innerHTML = `
      <div class="inc-detail-head">
        <h3>${esc(inc.public_number)}</h3>
        <span class="inc-pill ${closed ? 'closed' : 'open'}">${esc(statusLabel(inc.status))}</span>
        ${med.triage_level ? `<span class="inc-pill ${triageClass}">${esc(labelOf(state.vocab.triageLevels, med.triage_level))}</span>` : ''}
        ${Number(med.transported) === 1 ? '<span class="inc-pill alert">TRANSPORTAS</span>' : ''}
      </div>
      <div class="muted">${esc(inc.summary || '')}</div>
      <div class="inc-meta-grid">
        <div><span>Sprendimas</span><strong>${esc(labelOf(state.vocab.dispositions, med.disposition))}</strong></div>
        <div><span>Įstaiga</span><strong>${esc(med.facility || '—')}</strong></div>
        <div><span>Sąskaitos</span><strong>${Number(med.invoice_total || 0)} €</strong></div>
        <div><span>Sukurta</span><strong>${esc(shortTime(inc.created_at))}</strong></div>
      </div>
      ${state.perms.transition && !closed ? `
        <div class="row">
          <select class="inc-transition">${options(state.statusLabels, inc.status)}</select>
          <button type="button" class="btn inc-transition-go">Taikyti statusą</button>
        </div>` : ''}
      <div class="grid2">
        <label>Skundas / pateikimas
          <input type="text" class="inc-presentation-label" maxlength="200" value="${esc(med.presentation_label || '')}" />
        </label>
        <label>Kategorija
          <select class="inc-presentation-code">${options(state.vocab.presentations || {}, med.presentation_code, '—')}</select>
        </label>
        <label>Triažas
          <select class="inc-triage">${options(state.vocab.triageLevels || {}, med.triage_level || 'green')}</select>
        </label>
        <label>Sprendimas
          <select class="inc-disposition">${options(state.vocab.dispositions || {}, med.disposition || 'pending')}</select>
        </label>
        <label>Ligoninė / įstaiga
          <input type="text" class="inc-facility" maxlength="64" value="${esc(med.facility || '')}" />
        </label>
        <label class="inc-check"><input type="checkbox" class="inc-transported" ${Number(med.transported) === 1 ? 'checked' : ''} /> Hospitalizuotas / transportuotas</label>
      </div>
      <details class="inc-section" open>
        <summary>Vitaliniai rodikliai</summary>
        <div class="inc-section-body grid2">
          <label>Pulsas <input type="number" class="inc-pulse" min="0" max="300" value="${esc(med.pulse != null ? med.pulse : '')}" /></label>
          <label>SpO₂ % <input type="number" class="inc-spo2" min="0" max="100" value="${esc(med.spo2 != null ? med.spo2 : '')}" /></label>
          <label>RR sys <input type="number" class="inc-bp-sys" min="0" max="300" value="${esc(med.bp_systolic != null ? med.bp_systolic : '')}" /></label>
          <label>RR dia <input type="number" class="inc-bp-dia" min="0" max="200" value="${esc(med.bp_diastolic != null ? med.bp_diastolic : '')}" /></label>
          <label>Kvėp. dažnis <input type="number" class="inc-resp" min="0" max="80" value="${esc(med.resp_rate != null ? med.resp_rate : '')}" /></label>
          <label>GCS <input type="number" class="inc-gcs" min="3" max="15" value="${esc(med.gcs != null ? med.gcs : '')}" /></label>
        </div>
      </details>
      ${renderMedicsSection(bundle)}
      ${renderPartiesSection(bundle)}
      ${renderMedsSection(bundle)}
      ${renderActionsSection(bundle)}
      ${renderEquipmentSection(bundle)}
      ${renderRefsSection(bundle)}
      ${renderReportSection(bundle, report)}
      ${renderTimelineSection(bundle)}
      <p class="inc-status" role="status"></p>
      ${state.perms.report && !closed ? '<button type="button" class="btn primary inc-case-save">Išsaugoti bylos duomenis</button>' : ''}
    `;

    bindDetailHandlers(inc.id, closed);
    fillNearbySelects();
  }

  function renderMedicsSection(bundle) {
    const rows = (bundle.officers || []).map((o) =>
      `<li><span class="inc-row-main">${esc(o.callsign || o.display_name || o.citizenid)} · ${esc(labelOf(state.vocab.medicRoles, o.role))}</span></li>`
    ).join('');
    return `
      <details class="inc-section" open>
        <summary>Medikai (${(bundle.officers || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Medikų nėra.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="row">
            <select class="inc-medic-role">${options(state.vocab.medicRoles || {}, 'assist')}</select>
            <button type="button" class="btn inc-medic-join">Prisidėti</button>
            <select class="inc-medic-nearby"><option value="">Šalia esantis medikas…</option></select>
            <button type="button" class="btn inc-medic-add">Pridėti</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function renderPartiesSection(bundle) {
    const roles = state.vocab.partyRoles || { patient: 'Pacientas' };
    const rows = (bundle.parties || []).map((p) =>
      `<li><span class="inc-row-main">${esc(p.display_name || p.citizenid)} · ${esc(labelOf(roles, p.role))}</span>
        ${state.perms.report ? `<button type="button" class="btn inc-mini inc-party-del" data-id="${esc(p.id)}">Pašalinti</button>` : ''}</li>`
    ).join('');
    return `
      <details class="inc-section" open>
        <summary>Dalyviai / pacientai</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Dalyvių nėra.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="row">
            <select class="inc-party-nearby"><option value="">Šalia esantis asmuo…</option></select>
            <input type="text" class="inc-party-cid" placeholder="arba citizenid" maxlength="64" />
            <select class="inc-party-role">${options(roles, 'patient')}</select>
            <button type="button" class="btn inc-party-add">Pridėti</button>
            <button type="button" class="btn inc-nearby-refresh">Atnaujinti šalia</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function renderMedsSection(bundle) {
    const rows = (bundle.meds || []).map((m) =>
      `<li><span class="inc-row-main">${esc(m.med_label)} ${m.dose ? esc(m.dose) : ''} · ${esc(labelOf(state.vocab.medRoutes, m.route))}${m.patient_name ? ' → ' + esc(m.patient_name) : ''}</span></li>`
    ).join('');
    return `
      <details class="inc-section">
        <summary>Vaistai (${(bundle.meds || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Vaistų neįrašyta.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="grid2">
            <label>Vaistas <input type="text" class="inc-med-label" maxlength="128" placeholder="Pavadinimas" /></label>
            <label>Dozė <input type="text" class="inc-med-dose" maxlength="32" /></label>
            <label>Route <select class="inc-med-route">${options(state.vocab.medRoutes || {}, 'iv')}</select></label>
            <label>Pacientas (cid) <input type="text" class="inc-med-patient" maxlength="64" /></label>
          </div>
          <button type="button" class="btn inc-med-add">Fiksuoti vaistą</button>` : ''}
        </div>
      </details>`;
  }

  function renderActionsSection(bundle) {
    const rows = (bundle.actions || []).map((a) =>
      `<li><span class="inc-row-main">${esc(labelOf(state.vocab.actionTypes, a.action_type))}${a.patient_name ? ' → ' + esc(a.patient_name) : ''}</span></li>`
    ).join('');
    return `
      <details class="inc-section">
        <summary>Procedūros (${(bundle.actions || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Procedūrų neįrašyta.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="row">
            <select class="inc-action-type">${options(state.vocab.actionTypes || {}, 'assessment')}</select>
            <input type="text" class="inc-action-patient" placeholder="Pacientas (cid)" maxlength="64" />
            <button type="button" class="btn inc-action-add">Fiksuoti</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function renderEquipmentSection(bundle) {
    const rows = (bundle.equipment || []).map((e) =>
      `<li><span class="inc-row-main">${esc(labelOf(state.vocab.equipmentTypes, e.equipment_type))}${e.item_name ? ' · ' + esc(e.item_name) : ''} ×${esc(e.quantity || 1)}</span></li>`
    ).join('');
    return `
      <details class="inc-section">
        <summary>Įranga (${(bundle.equipment || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Įrangos neįrašyta.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="row">
            <select class="inc-equip-type">${options(state.vocab.equipmentTypes || {}, 'bandage')}</select>
            <input type="text" class="inc-equip-item" placeholder="Item / aprašymas" maxlength="64" />
            <input type="number" class="inc-equip-qty" value="1" min="1" max="999" />
            <button type="button" class="btn inc-equip-add">Fiksuoti</button>
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
        <summary>Sąskaitos / nuorodos</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Nuorodų nėra. Sąskaitos iš „Sąskaitos" skirtuko automatiškai prisegamos prie aktyvios bylos.</span></li>'}</ul>
        </div>
      </details>`;
  }

  function renderReportSection(bundle, report) {
    return `
      <details class="inc-section inc-report" open>
        <summary>Medicininė kortelė${report.revision ? ' (v' + esc(report.revision) + ')' : ''}</summary>
        <div class="inc-section-body">
          <input type="text" class="inc-report-title" placeholder="Antraštė" maxlength="200" value="${esc(report.title || '')}"${state.perms.report ? '' : ' readonly'} />
          <textarea class="inc-report-body" placeholder="Anamnezė, apžiūra, gydymas, rekomendacijos…"${state.perms.report ? '' : ' readonly'}>${esc(report.body || '')}</textarea>
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
        presentation_label: valueOf('.inc-presentation-label'),
        presentation_code: valueOf('.inc-presentation-code'),
        disposition: valueOf('.inc-disposition'),
        facility: valueOf('.inc-facility'),
        triage_level: valueOf('.inc-triage'),
        transported: valueOf('.inc-transported'),
        pulse: valueOf('.inc-pulse') || null,
        spo2: valueOf('.inc-spo2') || null,
        bp_systolic: valueOf('.inc-bp-sys') || null,
        bp_diastolic: valueOf('.inc-bp-dia') || null,
        resp_rate: valueOf('.inc-resp') || null,
        gcs: valueOf('.inc-gcs') || null,
      }));
    });

    bindClick('.inc-report-save', () => {
      handle(post('incidentSaveReport', {
        incidentId: incidentId,
        title: valueOf('.inc-report-title'),
        body: valueOf('.inc-report-body'),
      }));
    });

    bindClick('.inc-medic-join', () => {
      handle(post('incidentAttachMedic', { incidentId: incidentId, role: valueOf('.inc-medic-role') }));
    });

    bindClick('.inc-medic-add', () => {
      const src = valueOf('.inc-medic-nearby');
      if (!src) return setStatus('Pasirink mediką iš sąrašo.', false);
      handle(post('incidentAttachMedic', { incidentId: incidentId, role: valueOf('.inc-medic-role'), targetSource: src }));
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

    const detail = el('emsIncDetail');
    if (detail) {
      detail.querySelectorAll('.inc-party-del').forEach((btn) => {
        btn.onclick = () => handle(post('incidentDetachParty', { incidentId: incidentId, partyId: btn.dataset.id }));
      });
    }

    bindClick('.inc-med-add', () => {
      const label = valueOf('.inc-med-label');
      if (!label) return setStatus('Įvesk vaisto pavadinimą.', false);
      handle(post('incidentAddMed', {
        incidentId: incidentId,
        med_label: label,
        dose: valueOf('.inc-med-dose'),
        route: valueOf('.inc-med-route'),
        patient_citizenid: valueOf('.inc-med-patient') || undefined,
      }));
    });

    bindClick('.inc-action-add', () => {
      handle(post('incidentAddAction', {
        incidentId: incidentId,
        action_type: valueOf('.inc-action-type'),
        patient_citizenid: valueOf('.inc-action-patient') || undefined,
      }));
    });

    bindClick('.inc-equip-add', () => {
      handle(post('incidentAddEquipment', {
        incidentId: incidentId,
        equipment_type: valueOf('.inc-equip-type'),
        item_name: valueOf('.inc-equip-item'),
        quantity: Number(valueOf('.inc-equip-qty')) || 1,
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
    const medics = detailQuery('.inc-medic-nearby');
    if (people) {
      people.innerHTML = '<option value="">Šalia esantis asmuo…</option>' + state.nearby.map((p) =>
        `<option value="${esc(p.source)}">${esc(p.name || p.citizenid)} · ${esc(p.distance)} m</option>`).join('');
    }
    if (medics) {
      medics.innerHTML = '<option value="">Šalia esantis medikas…</option>' + state.nearby
        .filter((p) => p.isMedic && p.onduty)
        .map((p) => `<option value="${esc(p.source)}">${esc(p.callsign || p.name || p.citizenid)} · ${esc(p.distance)} m</option>`)
        .join('');
    }
  }

  function loadMeta() {
    return post('incidentMeta', {}).then((res) => {
      if (!res || !res.ok) {
        const box = el('emsIncDetail');
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
      if (window.activeService === 'ems') onTabOpened();
    });

    const refresh = el('emsIncRefresh');
    if (refresh) refresh.onclick = () => loadList();

    const search = el('emsIncSearch');
    if (search) {
      search.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') loadList();
      });
    }
    ['emsIncOpenOnly', 'emsIncMine'].forEach((id) => {
      const node = el(id);
      if (node) node.onchange = () => loadList();
    });

    const toggle = el('emsIncNewToggle');
    const createBox = el('emsIncCreateBox');
    if (toggle && createBox) {
      toggle.onclick = () => createBox.classList.toggle('hidden');
    }

    const create = el('emsIncCreate');
    if (create) {
      create.onclick = () => {
        const status = el('emsIncCreateStatus');
        const summary = el('emsIncNewSummary') ? el('emsIncNewSummary').value.trim() : '';
        if (summary.length < 3) {
          if (status) status.textContent = 'Įvesk trumpą aprašymą.';
          return;
        }
        if (status) status.textContent = 'Kuriama…';
        post('incidentCreate', {
          summary: summary,
          presentation_label: el('emsIncNewPresentation') ? el('emsIncNewPresentation').value.trim() : '',
        }).then((res) => {
          if (!res || !res.ok) {
            if (status) status.textContent = (res && res.message) || 'Nepavyko sukurti.';
            return;
          }
          if (status) status.textContent = res.message || 'Byla sukurta.';
          if (el('emsIncNewSummary')) el('emsIncNewSummary').value = '';
          if (createBox) createBox.classList.add('hidden');
          loadList().then(() => openIncident(res.incident.id));
        });
      };
    }
  }

  window.addEventListener('message', (e) => {
    const d = e.data;
    if (!d || d.action !== 'open') return;
    const isEms = d.data && d.data.service === 'ems';
    const show = isEms && d.data.enableIncidents === true;
    const tab = el('tabIncidents');
    const panel = el('panel-incidents');
    const emsPanel = el('emsIncPanel');
    const mechPanel = el('mechIncPanel');
    if (tab) tab.style.display = show || (d.data && d.data.service === 'mechanic' && d.data.enableIncidents) ? '' : 'none';
    if (emsPanel) emsPanel.classList.toggle('hidden', !show);
    if (mechPanel && d.data && d.data.service !== 'mechanic') mechPanel.classList.add('hidden');
    if (panel && !show && !(d.data && d.data.service === 'mechanic' && d.data.enableIncidents)) panel.classList.add('hidden');
    if (!show) return;
    state.ready = false;
    state.rows = [];
    state.selected = null;
    state.bundle = null;
    const detail = el('emsIncDetail');
    if (detail) detail.innerHTML = '<div class="muted">Pasirink bylą arba sukurk naują.</div>';
    if (tab && tab.classList.contains('active')) onTabOpened();
  });

  bindStatic();
})();
