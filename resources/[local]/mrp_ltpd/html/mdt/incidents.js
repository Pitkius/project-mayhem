/*
  MDT V2 Phase 3 — „Bylos" (PD incident) tab.

  Presentation only: every field shown here comes from mrp_mdt_core through
  mrp_ltpd server callbacks, and every action is re-authorized server-side.
  Reuses nuiPost() / escapeHtml() from app.js and the existing MDT styles.
*/
(function () {
  'use strict';

  const state = {
    ready: false,
    meta: null,
    perms: {},
    vocab: {},
    evidenceVocab: {},
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
    return window.nuiPost(endpoint, data || {}, { force: true });
  }

  const el = (id) => document.getElementById(id);

  const EVENT_LABELS = {
    incident_created: 'Byla sukurta',
    status_changed: 'Statusas pakeistas',
    crew_assigned: 'Priskirtas ekipažas',
    crew_cleared: 'Ekipažas atšauktas',
    officer_attached: 'Pareigūnas byloje',
    officer_role_changed: 'Pareigūno rolė',
    officer_detached: 'Pareigūnas pašalintas',
    party_attached: 'Pridėtas dalyvis',
    party_updated: 'Dalyvis atnaujintas',
    party_detached: 'Dalyvis pašalintas',
    vehicle_attached: 'Pridėta TP',
    vehicle_updated: 'TP atnaujinta',
    vehicle_detached: 'TP pašalinta',
    report_filed: 'Raportas užpildytas',
    report_updated: 'Raportas atnaujintas',
    force_logged: 'Jėgos naudojimas',
    tool_logged: 'Naudota priemonė',
    item_seized: 'Paimtas objektas',
    ref_linked: 'Prisegta nuoroda',
    evidence_logged: 'Įkaltis į saugyklą',
    evidence_sealed: 'Įkaltis užplombuotas',
    case_updated: 'Bylos duomenys',
    wanted_updated: 'Paieškomumas',
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

  function parsePayload(raw) {
    if (!raw) return {};
    if (typeof raw === 'object') return raw;
    try {
      return JSON.parse(raw) || {};
    } catch (e) {
      return {};
    }
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

  /* ---------------------------------------------------------------- list */

  function renderList() {
    const box = el('incList');
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
      const police = row.police || {};
      const bits = [];
      if (row.unit_labels) bits.push(esc(row.unit_labels));
      if (police.offence_label) bits.push(esc(police.offence_label));
      if (Number(police.fine_total) > 0) bits.push(`${Number(police.fine_total)} €`);
      if (Number(police.arrest_made) === 1) bits.push('areštas');
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
    const box = el('incList');
    if (box && !state.rows.length) box.innerHTML = '<div class="muted">Kraunama…</div>';
    return post('incidentList', {
      openOnly: el('incOpenOnly') ? el('incOpenOnly').checked : true,
      mine: el('incMine') ? el('incMine').checked : false,
      search: el('incSearch') ? el('incSearch').value.trim() : '',
      limit: 30,
    }).then((res) => {
      if (!res || !res.ok) {
        if (box) box.innerHTML = `<div class="muted">${esc((res && res.message) || 'Nepavyko užkrauti bylų.')}</div>`;
        return;
      }
      state.rows = res.rows || [];
      renderList();
    });
  }

  /* -------------------------------------------------------------- detail */

  function setStatus(message, ok) {
    const node = document.querySelector('#incDetail .inc-status');
    if (!node) return;
    node.textContent = message || '';
    node.className = 'inc-status' + (message ? (ok ? ' ok' : ' err') : '');
  }

  function openIncident(ref) {
    state.selected = ref;
    const box = el('incDetail');
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

  function partyRoles() {
    return state.vocab.partyRoles || { suspect: 'Įtariamasis', victim: 'Nukentėjęs', witness: 'Liudytojas' };
  }

  function vehicleRoles() {
    return state.vocab.vehicleRoles || { involved: 'Susijusi TP' };
  }

  function stubRefTypes() {
    const all = state.vocab.refTypes || {};
    const allowed = ['photo', 'warrant', 'other'];
    const out = {};
    allowed.forEach((key) => {
      if (all[key]) out[key] = labelOf(all, key);
    });
    return out;
  }

  function surveillanceRefs(bundle) {
    return (bundle.refs || []).filter((r) => ['bodycam', 'cctv', 'evidence'].indexOf(String(r.ref_type)) !== -1);
  }

  function otherRefs(bundle) {
    return (bundle.refs || []).filter((r) => ['bodycam', 'cctv', 'evidence'].indexOf(String(r.ref_type)) === -1);
  }

  function refRowHtml(r) {
    return `
      <li>
        <span class="inc-row-main">
          <strong>${esc(labelOf(state.vocab.refTypes, r.ref_type))}</strong>
          <span class="muted">${r.label ? ' — ' + esc(r.label) : ''}${r.amount != null ? ' · ' + Number(r.amount) + ' €' : ''}
          ${r.citizenid ? ' · ' + esc(r.citizenid) : ''}${r.ref_id ? ' · #' + esc(r.ref_id) : ''}</span>
          <div class="muted">${esc(shortTime(r.created_at))}</div>
        </span>
      </li>`;
  }

  function sectionEvidence(bundle) {
    const evVocab = state.evidenceVocab || {};
    const rows = (bundle.evidence || []).map((e) => `
      <li>
        <span class="inc-row-main">
          <strong>${esc(e.item_label || e.item_name)}</strong>
          ${Number(e.sealed) === 1 ? '<span class="inc-pill alert">UŽPLOMBUOTA</span>' : ''}
          <span class="muted"> ×${Number(e.quantity) || 1}
          · ${esc(labelOf(evVocab.categories, e.category))}
          · ${esc(labelOf(evVocab.lockerLocations, e.location))}${e.locker_slot ? ' / ' + esc(e.locker_slot) : ''}</span>
          ${e.description ? `<div class="muted">${esc(e.description)}</div>` : ''}
          <div class="muted">${esc(shortTime(e.created_at))} · ${esc(e.logged_by_name || e.logged_by_citizenid || '—')}</div>
        </span>
        ${state.perms.evidence && Number(e.sealed) !== 1 ? `<button type="button" class="btn inc-mini inc-evidence-seal" data-id="${esc(e.id)}">Užplombuoti</button>` : ''}
      </li>`).join('');
    return `
      <details class="inc-section" open>
        <summary>Įkalčių saugykla (${(bundle.evidence || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Įkalčių nėra.</span></li>'}</ul>
          ${state.perms.evidence ? `
          <div class="grid2">
            <label>Objektas <input type="text" class="inc-ev-item" maxlength="64" placeholder="item_name" /></label>
            <label>Pavadinimas <input type="text" class="inc-ev-label" maxlength="128" /></label>
            <label>Kiekis <input type="number" class="inc-ev-qty" value="1" min="1" /></label>
            <label>Kategorija <select class="inc-ev-cat">${options(evVocab.categories || {}, 'other')}</select></label>
            <label>Saugykla <select class="inc-ev-loc">${options(evVocab.lockerLocations || {}, 'mrpd_main')}</select></label>
            <label>Lentynos nr. <input type="text" class="inc-ev-slot" maxlength="32" placeholder="A-12" /></label>
          </div>
          <div class="row">
            <input type="text" class="inc-ev-desc" placeholder="Aprašymas / grandinė" maxlength="500" />
            <button type="button" class="btn inc-ev-add">Įrašyti į saugyklą</button>
          </div>` : ''}
          <div class="row">
            ${state.perms.cctv ? '<button type="button" class="btn inc-open-cctv">Atidaryti CCTV (byla)</button>' : ''}
            ${state.perms.bodycam ? '<button type="button" class="btn inc-open-bodycam">Atidaryti bodycam (byla)</button>' : ''}
            <span class="muted">Peržiūros automatiškai prisegamos prie aktyvios bylos.</span>
          </div>
        </div>
      </details>`;
  }

  function sectionOfficers(bundle) {
    const rows = (bundle.officers || []).map((o) => `
      <li>
        <span class="inc-row-main">
          <strong>${esc(o.callsign || o.display_name || o.citizenid)}</strong>
          ${o.callsign && o.display_name ? ' · ' + esc(o.display_name) : ''}
          <span class="muted"> — ${esc(labelOf(state.vocab.officerRoles, o.role))}</span>
        </span>
      </li>`).join('');
    return `
      <details class="inc-section" open>
        <summary>Pareigūnai (${(bundle.officers || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Nėra įrašytų pareigūnų.</span></li>'}</ul>
          <div class="row">
            <select class="inc-officer-role">${options(state.vocab.officerRoles || {}, 'assist')}</select>
            <button type="button" class="btn inc-officer-join">Prisidėti prie bylos</button>
            <select class="inc-officer-nearby"><option value="">Šalia esantis pareigūnas…</option></select>
            <button type="button" class="btn inc-officer-add">Pridėti</button>
          </div>
        </div>
      </details>`;
  }

  function sectionParties(bundle) {
    const rows = (bundle.parties || []).map((p) => `
      <li>
        <span class="inc-row-main">
          <strong>${esc(p.display_name || p.citizenid || '—')}</strong>
          <span class="muted"> — ${esc(labelOf(partyRoles(), p.role))}${p.citizenid ? ' · ' + esc(p.citizenid) : ''}</span>
          ${p.notes ? `<div class="muted">${esc(p.notes)}</div>` : ''}
        </span>
        ${state.perms.report ? `<button type="button" class="btn inc-mini inc-party-del" data-id="${esc(p.id)}">Pašalinti</button>` : ''}
      </li>`).join('');
    return `
      <details class="inc-section" open>
        <summary>Dalyviai (${(bundle.parties || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Dalyvių nėra.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="row">
            <select class="inc-party-nearby"><option value="">Šalia esantis asmuo…</option></select>
            <input type="text" class="inc-party-cid" placeholder="arba citizenid" maxlength="64" />
            <select class="inc-party-role">${options(partyRoles(), 'suspect')}</select>
            <button type="button" class="btn inc-party-add">Pridėti dalyvį</button>
            <button type="button" class="btn inc-nearby-refresh">Atnaujinti šalia</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function sectionVehicles(bundle) {
    const rows = (bundle.vehicles || []).map((v) => `
      <li>
        <span class="inc-row-main">
          <strong>${esc(v.plate || v.vin || '—')}</strong>
          <span class="muted"> — ${esc(labelOf(vehicleRoles(), v.role))}${v.model ? ' · ' + esc(v.model) : ''}</span>
        </span>
        ${state.perms.report ? `<button type="button" class="btn inc-mini inc-veh-del" data-id="${esc(v.id)}">Pašalinti</button>` : ''}
      </li>`).join('');
    return `
      <details class="inc-section">
        <summary>Transporto priemonės (${(bundle.vehicles || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">TP nėra.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="row">
            <input type="text" class="inc-veh-plate" placeholder="Numeriai" maxlength="16" />
            <select class="inc-veh-role">${options(vehicleRoles(), 'involved')}</select>
            <button type="button" class="btn inc-veh-add">Pridėti TP</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function sectionForce(bundle) {
    const rows = (bundle.force || []).map((f) => `
      <li>
        <span class="inc-row-main">
          <strong>${esc(labelOf(state.vocab.forceTypes, f.force_type))}</strong>
          <span class="muted"> — ${esc(f.subject_name || f.subject_citizenid || 'nenurodytas asmuo')}
          · sužalojimai: ${esc(labelOf(state.vocab.injuries, f.injuries))}${f.tool ? ' · ' + esc(f.tool) : ''}</span>
          ${f.notes ? `<div class="muted">${esc(f.notes)}</div>` : ''}
          <div class="muted">${esc(shortTime(f.created_at))} · ${esc(f.officer_name || f.officer_citizenid || '—')}</div>
        </span>
      </li>`).join('');
    return `
      <details class="inc-section">
        <summary>Jėgos naudojimas (${(bundle.force || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Jėga nenaudota.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="grid2">
            <label>Priemonė / lygis <select class="inc-force-type">${options(state.vocab.forceTypes || {}, 'hands')}</select></label>
            <label>Asmuo (citizenid) <input type="text" class="inc-force-cid" maxlength="64" /></label>
            <label>Sužalojimai <select class="inc-force-inj">${options(state.vocab.injuries || {}, 'none')}</select></label>
            <label>Įrankis / ginklas <input type="text" class="inc-force-tool" maxlength="64" /></label>
          </div>
          <div class="row">
            <input type="text" class="inc-force-notes" placeholder="Aplinkybės" maxlength="500" />
            <label class="inc-check"><input type="checkbox" class="inc-force-med" /> Kviesta medikų</label>
            <button type="button" class="btn inc-force-add">Fiksuoti</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function sectionTools(bundle) {
    const rows = (bundle.tools || []).map((t) => `
      <li>
        <span class="inc-row-main">
          <strong>${esc(labelOf(state.vocab.toolTypes, t.tool_type))}</strong>
          <span class="muted"> ×${Number(t.quantity) || 1}${t.item_name ? ' · ' + esc(t.item_name) : ''}
          · ${esc(t.officer_name || t.officer_citizenid || '—')}</span>
          ${t.notes ? `<div class="muted">${esc(t.notes)}</div>` : ''}
        </span>
      </li>`).join('');
    return `
      <details class="inc-section">
        <summary>Naudotos priemonės (${(bundle.tools || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Priemonių neįrašyta.</span></li>'}</ul>
          ${state.perms.report ? `
          <div class="row">
            <select class="inc-tool-type">${options(state.vocab.toolTypes || {}, 'handcuffs')}</select>
            <input type="text" class="inc-tool-item" placeholder="Item / modelis" maxlength="64" />
            <input type="number" class="inc-tool-qty" value="1" min="1" max="999" />
            <button type="button" class="btn inc-tool-add">Fiksuoti</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function sectionSeized(bundle) {
    const rows = (bundle.seized || []).map((s) => `
      <li>
        <span class="inc-row-main">
          <strong>${esc(s.item_label || s.item_name)}</strong>
          <span class="muted"> ×${Number(s.quantity) || 1} · ${esc(labelOf(state.vocab.seizedCategories, s.category))}
          ${s.from_name || s.from_citizenid ? ' · iš ' + esc(s.from_name || s.from_citizenid) : ''}
          ${s.storage_ref ? ' · saugykla: ' + esc(s.storage_ref) : ''}</span>
          ${s.notes ? `<div class="muted">${esc(s.notes)}</div>` : ''}
        </span>
      </li>`).join('');
    return `
      <details class="inc-section">
        <summary>Paimti objektai (${(bundle.seized || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-rows">${rows || '<li><span class="muted">Nieko nepaimta.</span></li>'}</ul>
          ${state.perms.evidence ? `
          <div class="grid2">
            <label>Objektas <input type="text" class="inc-seized-item" maxlength="64" placeholder="pvz. weapon_pistol" /></label>
            <label>Pavadinimas <input type="text" class="inc-seized-label" maxlength="128" /></label>
            <label>Kiekis <input type="number" class="inc-seized-qty" value="1" min="1" /></label>
            <label>Kategorija <select class="inc-seized-cat">${options(state.vocab.seizedCategories || {}, 'other')}</select></label>
            <label>Iš ko (citizenid) <input type="text" class="inc-seized-from" maxlength="64" /></label>
            <label>Saugyklos nr. <input type="text" class="inc-seized-store" maxlength="64" /></label>
          </div>
          <div class="row">
            <button type="button" class="btn inc-seized-add">Fiksuoti paėmimą</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function sectionRefs(bundle) {
    const survRows = surveillanceRefs(bundle).map(refRowHtml).join('');
    const rows = otherRefs(bundle).map(refRowHtml).join('');
    return `
      <details class="inc-section" open>
        <summary>Nuorodos: baudos, areštai, medija (${(bundle.refs || []).length})</summary>
        <div class="inc-section-body">
          ${survRows ? `<div class="muted" style="margin-bottom:6px">CCTV / bodycam / įkalčiai</div><ul class="inc-rows">${survRows}</ul>` : ''}
          <ul class="inc-rows">${rows || (survRows ? '' : '<li><span class="muted">Nuorodų nėra.</span></li>')}</ul>
          ${state.perms.fine ? `
          <div class="row">
            <input type="text" class="inc-fine-cid" placeholder="Baudos gavėjas (citizenid)" maxlength="64" />
            <input type="number" class="inc-fine-amount" placeholder="Suma €" min="1" />
            <input type="text" class="inc-fine-reason" placeholder="Priežastis" maxlength="120" />
            <button type="button" class="btn inc-fine-add">Išrašyti baudą byloje</button>
          </div>` : ''}
          ${state.perms.arrest ? `
          <div class="row">
            <input type="text" class="inc-arrest-cid" placeholder="Areštuotas (citizenid)" maxlength="64" />
            <input type="text" class="inc-arrest-reason" placeholder="Priežastis" maxlength="120" />
            <input type="text" class="inc-arrest-sentence" placeholder="Bausmė" maxlength="120" />
            <button type="button" class="btn inc-arrest-add">Įrašyti areštą</button>
          </div>` : ''}
          ${state.perms.report ? `
          <div class="row">
            <select class="inc-ref-type">${options(stubRefTypes(), 'photo')}</select>
            <input type="text" class="inc-ref-id" placeholder="Įrašo ID / URL" maxlength="64" />
            <input type="text" class="inc-ref-label" placeholder="Pastaba" maxlength="120" />
            <button type="button" class="btn inc-ref-add">Prisegti</button>
          </div>` : ''}
        </div>
      </details>`;
  }

  function sectionReport(bundle) {
    const report = bundle.report || {};
    return `
      <details class="inc-section inc-report" open>
        <summary>Raportas${report.revision ? ` (v${esc(report.revision)})` : ''}</summary>
        <div class="inc-section-body">
          <div class="row">
            <input type="text" class="inc-report-title" placeholder="Raporto antraštė" maxlength="200" />
          </div>
          <textarea class="inc-report-body" placeholder="Įvykio aprašymas, veiksmai, liudytojų parodymai…"${state.perms.report ? '' : ' readonly'}></textarea>
          <div class="row">
            ${state.perms.report ? '<button type="button" class="btn primary inc-report-save">Išsaugoti raportą</button>' : '<span class="muted">Raportą rašyti gali pareigūnai su MDT_REPORT teise.</span>'}
            <span class="muted">${report.author_name ? 'Autorius: ' + esc(report.author_name) : ''}${report.updated_at ? ' · atnaujinta ' + esc(shortTime(report.updated_at)) : ''}</span>
          </div>
        </div>
      </details>`;
  }

  function timelineEntry(row) {
    const payload = parsePayload(row.payload);
    let detail = '';
    if (row.event_type === 'status_changed') {
      detail = `${statusLabel(payload.from)} → ${statusLabel(payload.to)}`;
      if (payload.reason) detail += ` (${payload.reason})`;
    } else if (row.event_type === 'ref_linked') {
      detail = labelOf(state.vocab.refTypes, payload.ref_type);
      if (payload.label) detail += `: ${payload.label}`;
      if (payload.amount != null) detail += ` · ${Number(payload.amount)} €`;
    } else if (row.event_type === 'force_logged') {
      detail = labelOf(state.vocab.forceTypes, payload.force_type);
      if (payload.injuries) detail += ` · ${labelOf(state.vocab.injuries, payload.injuries)}`;
    } else if (row.event_type === 'tool_logged') {
      detail = labelOf(state.vocab.toolTypes, payload.tool_type);
    } else if (row.event_type === 'item_seized') {
      detail = `${payload.item_name || ''} ×${payload.quantity || 1}`;
    } else if (row.event_type === 'evidence_logged') {
      detail = `${payload.item_name || ''} ×${payload.quantity || 1}${payload.locker_slot ? ' · ' + payload.locker_slot : ''}`;
    } else if (row.event_type === 'evidence_sealed') {
      detail = payload.item_name || String(payload.evidence_id || '');
    } else if (row.event_type === 'party_attached' || row.event_type === 'party_updated' || row.event_type === 'party_detached') {
      detail = `${payload.display_name || payload.citizenid || ''} — ${labelOf(partyRoles(), payload.role)}`;
    } else if (row.event_type === 'officer_attached' || row.event_type === 'officer_role_changed') {
      detail = `${payload.callsign || payload.display_name || payload.citizenid || ''} — ${labelOf(state.vocab.officerRoles, payload.role)}`;
    } else if (row.event_type === 'vehicle_attached' || row.event_type === 'vehicle_detached') {
      detail = `${payload.plate || ''} — ${labelOf(vehicleRoles(), payload.role)}`;
    } else if (row.event_type === 'wanted_updated') {
      detail = `${payload.citizenid || ''} → ${payload.level != null ? payload.level : '?'}`;
    } else if (row.event_type === 'case_updated') {
      detail = Object.keys(payload).map((k) => `${k}: ${payload[k]}`).join(', ');
    } else if (row.event_type === 'incident_created') {
      detail = payload.public_number || '';
    }
    return `
      <li>
        <span class="inc-tl-when">${esc(shortTime(row.created_at))}</span>
        <strong>${esc(EVENT_LABELS[row.event_type] || row.event_type)}</strong>
        ${detail ? ' — ' + esc(detail) : ''}
        <span class="inc-tl-who">${row.actor_name ? ' · ' + esc(row.actor_name) : ''}</span>
      </li>`;
  }

  function renderDetail() {
    const box = el('incDetail');
    const bundle = state.bundle;
    if (!box || !bundle || !bundle.incident) return;
    const inc = bundle.incident;
    const police = bundle.police || {};
    const closed = isClosedStatus(inc.status);
    const transitions = bundle.allowedTransitions || [];

    box.innerHTML = `
      <div class="inc-detail-head">
        <h3>${esc(inc.public_number)}</h3>
        <span class="inc-pill ${closed ? 'closed' : 'open'}">${esc(statusLabel(inc.status))}</span>
        ${Number(police.arrest_made) === 1 ? '<span class="inc-pill alert">AREŠTAS</span>' : ''}
        ${Number(police.weapon_involved) === 1 ? '<span class="inc-pill alert">GINKLAS</span>' : ''}
      </div>
      <div class="card">
        <div>${esc(inc.summary || '—')}</div>
        <div class="inc-meta-grid">
          <div><span>Sukurta:</span> ${esc(shortTime(inc.created_at))}</div>
          <div><span>Vieta:</span> ${esc(inc.location_label || '—')}</div>
          <div><span>Iškvietimas:</span> ${esc(inc.dispatch_call_id || '—')}</div>
          <div><span>Ekipažas:</span> ${esc(inc.assigned_crew || '—')}</div>
          <div><span>Baudos:</span> ${Number(police.fine_total) || 0} €</div>
          <div><span>Prioritetas:</span> ${Number(inc.priority) || 0}</div>
        </div>
        <div class="row">
          <select class="inc-transition">
            <option value="">Keisti statusą…</option>
            ${transitions.map((s) => `<option value="${esc(s)}">${esc(statusLabel(s))}</option>`).join('')}
          </select>
          <button type="button" class="btn inc-transition-go"${state.perms.transition ? '' : ' disabled'}>Taikyti</button>
        </div>
        <div class="grid2">
          <label>Kvalifikacija <input type="text" class="inc-offence-label" maxlength="200" /></label>
          <label>Kodas <input type="text" class="inc-offence-code" maxlength="64" /></label>
          <label>Sprendimas <select class="inc-disposition">${options(state.vocab.dispositions || {}, police.disposition || 'pending')}</select></label>
        </div>
        <div class="row">
          <button type="button" class="btn inc-case-save"${state.perms.report ? '' : ' disabled'}>Išsaugoti bylos duomenis</button>
        </div>
        <p class="inc-status" role="status"></p>
      </div>
      ${sectionOfficers(bundle)}
      ${sectionParties(bundle)}
      ${sectionVehicles(bundle)}
      ${sectionRefs(bundle)}
      ${sectionEvidence(bundle)}
      ${sectionForce(bundle)}
      ${sectionTools(bundle)}
      ${sectionSeized(bundle)}
      ${sectionReport(bundle)}
      <details class="inc-section" open>
        <summary>Laiko juosta (${(bundle.timeline || []).length})</summary>
        <div class="inc-section-body">
          <ul class="inc-timeline">${(bundle.timeline || []).map(timelineEntry).join('') || '<li class="muted">Įrašų nėra.</li>'}</ul>
        </div>
      </details>
    `;

    bindDetail();
    fillNearbySelects();
  }

  /* ------------------------------------------------------------- actions */

  function detailQuery(selector) {
    return document.querySelector('#incDetail ' + selector);
  }

  function valueOf(selector) {
    const node = detailQuery(selector);
    return node ? String(node.value || '').trim() : '';
  }

  function handle(promise, okMessage) {
    return promise.then((res) => {
      if (!res || !res.ok) {
        setStatus((res && res.message) || 'Veiksmas nepavyko.', false);
        return null;
      }
      return reloadDetail(res.message || okMessage, true).then(() => {
        loadList();
        return res;
      });
    });
  }

  function bindClick(selector, handler) {
    const node = detailQuery(selector);
    if (node) node.onclick = handler;
  }

  //- Free-text values are assigned as properties, never inlined into HTML attributes.
  function fillDetailValues() {
    const police = (state.bundle && state.bundle.police) || {};
    const report = (state.bundle && state.bundle.report) || {};
    const pairs = [
      ['.inc-offence-label', police.offence_label],
      ['.inc-offence-code', police.offence_code],
      ['.inc-report-title', report.title],
      ['.inc-report-body', report.body],
    ];
    pairs.forEach(([selector, value]) => {
      const node = detailQuery(selector);
      if (node) node.value = value == null ? '' : String(value);
    });
  }

  function bindDetail() {
    const incidentId = state.selected;
    window.mrpMdtActiveIncidentId = incidentId;
    fillDetailValues();

    bindClick('.inc-transition-go', () => {
      const status = valueOf('.inc-transition');
      if (!status) return setStatus('Pasirink statusą.', false);
      handle(post('incidentTransition', { incidentId: incidentId, status: status }));
    });

    bindClick('.inc-case-save', () => handle(post('incidentUpdateCase', {
      incidentId: incidentId,
      offence_label: valueOf('.inc-offence-label'),
      offence_code: valueOf('.inc-offence-code'),
      disposition: valueOf('.inc-disposition'),
    })));

    bindClick('.inc-report-save', () => {
      const body = detailQuery('.inc-report-body');
      handle(post('incidentSaveReport', {
        incidentId: incidentId,
        title: valueOf('.inc-report-title'),
        body: body ? body.value : '',
      }));
    });

    bindClick('.inc-officer-join', () => handle(post('incidentAttachOfficer', {
      incidentId: incidentId,
      role: valueOf('.inc-officer-role') || 'assist',
    })));

    bindClick('.inc-officer-add', () => {
      const target = valueOf('.inc-officer-nearby');
      if (!target) return setStatus('Pasirink šalia esantį pareigūną.', false);
      handle(post('incidentAttachOfficer', {
        incidentId: incidentId,
        role: valueOf('.inc-officer-role') || 'assist',
        targetSource: Number(target),
      }));
    });

    bindClick('.inc-nearby-refresh', () => loadNearby().then(() => {
      fillNearbySelects();
      setStatus('Šalia esantys asmenys atnaujinti.', true);
    }));

    bindClick('.inc-party-add', () => {
      const target = valueOf('.inc-party-nearby');
      const cid = valueOf('.inc-party-cid');
      if (!target && !cid) return setStatus('Pasirink asmenį arba įvesk citizenid.', false);
      handle(post('incidentAttachParty', {
        incidentId: incidentId,
        targetSource: target ? Number(target) : undefined,
        citizenid: target ? undefined : cid,
        role: valueOf('.inc-party-role') || 'suspect',
      }));
    });

    document.querySelectorAll('#incDetail .inc-party-del').forEach((btn) => {
      btn.onclick = () => handle(post('incidentDetachParty', { incidentId: incidentId, partyId: Number(btn.dataset.id) }));
    });

    bindClick('.inc-veh-add', () => {
      const plate = valueOf('.inc-veh-plate');
      if (!plate) return setStatus('Įvesk numerius.', false);
      handle(post('incidentAttachVehicle', {
        incidentId: incidentId,
        plate: plate,
        role: valueOf('.inc-veh-role') || 'involved',
      }));
    });

    document.querySelectorAll('#incDetail .inc-veh-del').forEach((btn) => {
      btn.onclick = () => handle(post('incidentDetachVehicle', { incidentId: incidentId, vehicleId: Number(btn.dataset.id) }));
    });

    bindClick('.inc-force-add', () => {
      const med = detailQuery('.inc-force-med');
      handle(post('incidentAddForce', {
        incidentId: incidentId,
        force_type: valueOf('.inc-force-type'),
        subject_citizenid: valueOf('.inc-force-cid'),
        injuries: valueOf('.inc-force-inj') || 'none',
        tool: valueOf('.inc-force-tool'),
        notes: valueOf('.inc-force-notes'),
        medical_called: med ? med.checked : false,
      }));
    });

    bindClick('.inc-tool-add', () => handle(post('incidentAddTool', {
      incidentId: incidentId,
      tool_type: valueOf('.inc-tool-type'),
      item_name: valueOf('.inc-tool-item'),
      quantity: Number(valueOf('.inc-tool-qty')) || 1,
    })));

    bindClick('.inc-seized-add', () => {
      const item = valueOf('.inc-seized-item');
      if (!item) return setStatus('Nurodyk objektą.', false);
      handle(post('incidentAddSeized', {
        incidentId: incidentId,
        item_name: item,
        item_label: valueOf('.inc-seized-label'),
        quantity: Number(valueOf('.inc-seized-qty')) || 1,
        category: valueOf('.inc-seized-cat') || 'other',
        from_citizenid: valueOf('.inc-seized-from'),
        storage_ref: valueOf('.inc-seized-store'),
      }));
    });

    bindClick('.inc-fine-add', () => {
      const cid = valueOf('.inc-fine-cid');
      const amount = Number(valueOf('.inc-fine-amount'));
      if (!cid || !(amount > 0)) return setStatus('Nurodyk citizenid ir sumą.', false);
      handle(post('incidentIssueFine', {
        incidentId: incidentId,
        citizenid: cid,
        amount: amount,
        reason_label: valueOf('.inc-fine-reason'),
        reason_code: 'incident',
      }));
    });

    bindClick('.inc-arrest-add', () => {
      const cid = valueOf('.inc-arrest-cid');
      if (!cid) return setStatus('Nurodyk areštuoto citizenid.', false);
      handle(post('incidentAddArrest', {
        incidentId: incidentId,
        citizenid: cid,
        reason: valueOf('.inc-arrest-reason'),
        sentence: valueOf('.inc-arrest-sentence'),
      }));
    });

    bindClick('.inc-ref-add', () => {
      const refId = valueOf('.inc-ref-id');
      if (!refId) return setStatus('Nurodyk įrašo ID.', false);
      handle(post('incidentAddRef', {
        incidentId: incidentId,
        ref_type: valueOf('.inc-ref-type'),
        ref_id: refId,
        label: valueOf('.inc-ref-label'),
      }));
    });

    bindClick('.inc-ev-add', () => {
      const item = valueOf('.inc-ev-item');
      if (!item) return setStatus('Nurodyk objektą.', false);
      handle(post('incidentAddEvidence', {
        incidentId: incidentId,
        item_name: item,
        item_label: valueOf('.inc-ev-label'),
        quantity: Number(valueOf('.inc-ev-qty')) || 1,
        category: valueOf('.inc-ev-cat') || 'other',
        location: valueOf('.inc-ev-loc') || 'mrpd_main',
        locker_slot: valueOf('.inc-ev-slot'),
        description: valueOf('.inc-ev-desc'),
      }));
    });

    document.querySelectorAll('#incDetail .inc-evidence-seal').forEach((btn) => {
      btn.onclick = () => handle(post('incidentSealEvidence', {
        incidentId: incidentId,
        evidenceId: Number(btn.dataset.id),
      }));
    });

    bindClick('.inc-open-cctv', () => {
      if (typeof window.activateMdtTab === 'function') window.activateMdtTab('cctv');
      setStatus('CCTV skirtukas — peržiūra bus prisegta prie bylos.', true);
    });

    bindClick('.inc-open-bodycam', () => {
      if (typeof window.activateMdtTab === 'function') window.activateMdtTab('bodycam');
      setStatus('Bodycam skirtukas — peržiūra bus prisegta prie bylos.', true);
    });
  }

  /* -------------------------------------------------------------- nearby */

  function loadNearby() {
    if (!state.perms.search) return Promise.resolve();
    return post('incidentNearby', {}).then((res) => {
      state.nearby = (res && res.ok && res.rows) || [];
    });
  }

  function fillNearbySelects() {
    const people = detailQuery('.inc-party-nearby');
    const officers = detailQuery('.inc-officer-nearby');
    if (people) {
      people.innerHTML = '<option value="">Šalia esantis asmuo…</option>' + state.nearby.map((p) =>
        `<option value="${esc(p.source)}">${esc(p.name || p.citizenid)} · ${esc(p.distance)} m</option>`).join('');
    }
    if (officers) {
      officers.innerHTML = '<option value="">Šalia esantis pareigūnas…</option>' + state.nearby
        .filter((p) => p.isOfficer && p.onduty)
        .map((p) => `<option value="${esc(p.source)}">${esc(p.callsign || p.name || p.citizenid)} · ${esc(p.distance)} m</option>`)
        .join('');
    }
  }

  /* ---------------------------------------------------------------- boot */

  function loadMeta() {
    return post('incidentMeta', {}).then((res) => {
      if (!res || !res.ok) {
        const box = el('incDetail');
        if (box) box.innerHTML = `<div class="muted">${esc((res && res.message) || 'Bylų sistema neprieinama.')}</div>`;
        return false;
      }
      state.meta = res;
      state.perms = res.permissions || {};
      state.vocab = res.vocabulary || {};
      state.evidenceVocab = res.evidenceVocabulary || {};
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
    if (tab) tab.addEventListener('click', onTabOpened);

    const refresh = el('incRefresh');
    if (refresh) refresh.onclick = () => loadList();

    const search = el('incSearch');
    if (search) {
      search.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') loadList();
      });
    }
    ['incOpenOnly', 'incMine'].forEach((id) => {
      const node = el(id);
      if (node) node.onchange = () => loadList();
    });

    const toggle = el('incNewToggle');
    const createBox = el('incCreateBox');
    if (toggle && createBox) {
      toggle.onclick = () => createBox.classList.toggle('hidden');
    }

    const create = el('incCreate');
    if (create) {
      create.onclick = () => {
        const status = el('incCreateStatus');
        const summary = el('incNewSummary') ? el('incNewSummary').value.trim() : '';
        if (summary.length < 3) {
          if (status) status.textContent = 'Įvesk trumpą aprašymą.';
          return;
        }
        if (status) status.textContent = 'Kuriama…';
        post('incidentCreate', {
          summary: summary,
          offence_label: el('incNewOffence') ? el('incNewOffence').value.trim() : '',
        }).then((res) => {
          if (!res || !res.ok) {
            if (status) status.textContent = (res && res.message) || 'Nepavyko sukurti bylos.';
            return;
          }
          if (status) status.textContent = res.message || 'Byla sukurta.';
          if (el('incNewSummary')) el('incNewSummary').value = '';
          if (el('incNewOffence')) el('incNewOffence').value = '';
          if (createBox) createBox.classList.add('hidden');
          loadList().then(() => openIncident(res.incident.id));
        });
      };
    }
  }

  window.addEventListener('message', (e) => {
    const d = e.data;
    if (!d || d.action !== 'open') return;
    const perms = (d.data && d.data.permissions) || {};
    const tab = el('tabIncidents');
    if (tab) tab.style.display = perms.incidents ? '' : 'none';
    //- Permissions can change with duty/grade between MDT opens.
    state.ready = false;
    state.rows = [];
    state.selected = null;
    state.bundle = null;
    window.mrpMdtActiveIncidentId = null;
    const detail = el('incDetail');
    if (detail) detail.innerHTML = '<div class="muted">Pasirink bylą iš sąrašo arba sukurk naują.</div>';
    //- MDT remembers the last tab, so reload straight away when it reopens here.
    if (perms.incidents && tab && tab.classList.contains('active')) onTabOpened();
  });

  bindStatic();
})();
