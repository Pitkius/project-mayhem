const app = document.getElementById('app');
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'fivempro_reports';

const state = {
  bootstrap: null,
  step: 1,
  form: { category: null, title: '', message: '', attachments: [] },
  mineFilter: 'all',
  adminFilter: 'all',
  selectedMineId: null,
  selectedAdminId: null,
  pendingAttachType: 'link',
  isStaff: false,
};

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => [...document.querySelectorAll(sel)];

function nui(event, data = {}) {
  return fetch(`https://${RES}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  }).then((r) => r.json()).catch(() => ({}));
}

function fmtTime(ts) {
  if (!ts) return '—';
  const d = new Date(ts * 1000);
  return d.toLocaleString('lt-LT', { dateStyle: 'short', timeStyle: 'short' });
}

const ICONS = {
  violation: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3.5 2.5 19.5h19L12 3.5z"/><path d="M12 9.5v5"/><circle cx="12" cy="17.2" r="0.9" fill="currentColor" stroke="none"/></svg>',
  bug: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M8 13a4 4 0 1 0 8 0 4 4 0 0 0-8 0z"/><path d="m9 3 1.5 3M15 3 13.5 6M4 8l3 1M20 8l-3 1M4 16l3-1M20 16l-3-1M12 17v4"/></svg>',
  question: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M9.5 9.2a2.7 2.7 0 1 1 4.3 2.1c-.9.7-1.3 1.2-1.3 2.2"/><circle cx="12" cy="17.2" r="0.9" fill="currentColor" stroke="none"/></svg>',
  other: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="4" width="14" height="16" rx="2"/><path d="M8.5 9h7M8.5 12.5h7M8.5 16h4.5"/></svg>',
  headset: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 14v-2a8 8 0 0 1 16 0v2"/><rect x="3" y="13" width="4" height="7" rx="2"/><rect x="17" y="13" width="4" height="7" rx="2"/></svg>',
  plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
  list: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M8 6h13M8 12h13M8 18h13"/><circle cx="4" cy="6" r="1" fill="currentColor"/><circle cx="4" cy="12" r="1" fill="currentColor"/><circle cx="4" cy="18" r="1" fill="currentColor"/></svg>',
  inbox: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6h16v12H4z"/><path d="m4 10 4 3h8l4-3"/></svg>',
  shield: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3 5 6v6c0 4.5 3 7.5 7 9 4-1.5 7-4.5 7-9V6l-7-3z"/></svg>',
  image: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="5" width="16" height="14" rx="2"/><circle cx="9" cy="10" r="1.5"/><path d="m5.5 17 4.5-4 3 3 2.5-2.5L18.5 17"/></svg>',
  video: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="7" width="13" height="10" rx="2"/><path d="M16 10.5 21 8v8l-5-2.5z"/></svg>',
  link: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M10 14a3.5 3.5 0 0 0 5 0l2-2a3.5 3.5 0 0 0-5-5l-1 1"/><path d="M14 10a3.5 3.5 0 0 0-5 0l-2 2a3.5 3.5 0 0 0 5 5l1-1"/></svg>',
  close: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M7 7l10 10M17 7 7 17"/></svg>',
  clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
  progress: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 3a9 9 0 0 1 7.8 4.5"/></svg>',
  check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="m8 12.2 2.2 2.2L16.5 8.5"/></svg>',
};

function iconHtml(name, extraClass = '') {
  const svg = ICONS[name] || ICONS.other;
  return `<span class="ui-icon ${extraClass}">${svg}</span>`;
}

function categoryLabelHtml(cat) {
  if (!cat) return '—';
  return `${iconHtml(cat.icon, 'ui-icon--sm')}<span>${escapeHtml(cat.label)}</span>`;
}

function attachIconHtml(type) {
  if (type === 'image') return iconHtml('image', 'ui-icon--sm');
  if (type === 'video') return iconHtml('video', 'ui-icon--sm');
  return iconHtml('link', 'ui-icon--sm');
}

function statusIcon(status) {
  return `<span class="status-dot ${status}" aria-hidden="true"></span>`;
}

function showToast(msg) {
  const el = $('#toast');
  el.textContent = msg;
  el.classList.remove('hidden');
  clearTimeout(showToast._t);
  showToast._t = setTimeout(() => el.classList.add('hidden'), 2800);
}

function closeUi() {
  nui('close');
}

function setView(name) {
  $$('.view').forEach((v) => v.classList.remove('active'));
  if (name === 'create') $('#viewCreate').classList.add('active');
  if (name === 'mine') $('#viewMine').classList.add('active');
  if (name === 'admin') $('#viewAdmin').classList.add('active');

  $$('#playerNav .nav-btn').forEach((b) => b.classList.toggle('active', b.dataset.view === name));
}

function renderCategories() {
  const grid = $('#categoryGrid');
  grid.innerHTML = '';
  const cats = state.bootstrap?.categories || [];
  const prio = state.bootstrap?.priorityLabels || {};
  cats.forEach((cat) => {
    const card = document.createElement('button');
    card.type = 'button';
    card.className = 'cat-card' + (state.form.category === cat.id ? ' selected' : '');
    card.innerHTML = `
      <div class="icon">${iconHtml(cat.icon)}</div>
      <div class="label">${cat.label}</div>
      <div class="prio">Prioritetas: ${prio[cat.priority] || cat.priority}</div>
    `;
    card.addEventListener('click', () => {
      state.form.category = cat.id;
      renderCategories();
    });
    grid.appendChild(card);
  });
}

function updateStepUi() {
  $$('.wizard-step').forEach((s) => s.classList.toggle('active', Number(s.dataset.step) === state.step));
  $$('.step-dot').forEach((dot) => {
    const n = Number(dot.dataset.step);
    dot.classList.toggle('active', n === state.step);
    dot.classList.toggle('done', n < state.step);
  });
  $('#prevStepBtn').disabled = state.step <= 1;
  $('#nextStepBtn').textContent = state.step >= 5 ? 'Pateikti' : 'Toliau';
  if (state.step === 5) renderSummary();
}

function renderSummary() {
  const cat = (state.bootstrap?.categories || []).find((c) => c.id === state.form.category);
  const prio = cat?.priority || 'medium';
  const pl = state.bootstrap?.priorityLabels?.[prio] || prio;
  $('#summaryCard').innerHTML = `
    <div class="summary-row"><span class="k">Kategorija</span><span class="summary-cat">${categoryLabelHtml(cat)}</span></div>
    <div class="summary-row"><span class="k">Pavadinimas</span><span>${escapeHtml(state.form.title)}</span></div>
    <div class="summary-row"><span class="k">Aprašymas</span><span>${escapeHtml(state.form.message)}</span></div>
    <div class="summary-row"><span class="k">Priedai</span><span>${state.form.attachments.length ? state.form.attachments.length + ' vnt.' : 'Nėra'}</span></div>
  `;
  const pill = $('#priorityPreview');
  pill.className = `priority-pill ${prio}`;
  pill.textContent = `Prioritetas: ${pl}`;
}

function escapeHtml(str) {
  return String(str || '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[c]);
}

function validateStep() {
  if (state.step === 1 && !state.form.category) {
    showToast('Pasirinkite kategoriją.');
    return false;
  }
  if (state.step === 2 && state.form.title.trim().length < 4) {
    showToast('Pavadinimas per trumpas (min. 4 simboliai).');
    return false;
  }
  if (state.step === 3 && state.form.message.trim().length < 10) {
    showToast('Aprašymas per trumpas (min. 10 simbolių).');
    return false;
  }
  return true;
}

function renderAttachments() {
  const list = $('#attachmentsList');
  list.innerHTML = '';
  state.form.attachments.forEach((a, idx) => {
    const row = document.createElement('div');
    row.className = 'attach-row';
    row.innerHTML = `${attachIconHtml(a.type)}<span>${escapeHtml(a.label || a.url)}</span>`;
    const btn = document.createElement('button');
    btn.textContent = '×';
    btn.addEventListener('click', () => {
      state.form.attachments.splice(idx, 1);
      renderAttachments();
    });
    row.appendChild(btn);
    list.appendChild(row);
  });
}

function openConfirmModal() {
  const cat = (state.bootstrap?.categories || []).find((c) => c.id === state.form.category);
  $('#confirmBody').innerHTML = `
    <p><strong>Kategorija:</strong> ${cat ? cat.label : '—'}</p>
    <p><strong>Pavadinimas:</strong> ${escapeHtml(state.form.title)}</p>
    <p>Ar tikrai norite pateikti reportą?</p>
  `;
  $('#confirmModal').classList.remove('hidden');
}

async function submitReport() {
  $('#confirmModal').classList.add('hidden');
  const payload = {
    category: state.form.category,
    title: state.form.title.trim(),
    message: state.form.message.trim(),
    attachments: state.form.attachments,
  };
  const res = await nui('submit', payload);
  if (res?.ok) {
    showToast(`Report #${res.report?.id} pateiktas!`);
    state.form = { category: null, title: '', message: '', attachments: [] };
    state.step = 1;
    $('#titleInput').value = '';
    $('#messageInput').value = '';
    updateStepUi();
    renderCategories();
    renderAttachments();
    if (res.rows) renderMyReports(res.rows);
    setView('mine');
    $$('#playerNav .nav-btn').forEach((b) => b.classList.toggle('active', b.dataset.view === 'mine'));
  }
}

function filterReports(rows, filter) {
  if (!rows) return [];
  if (filter === 'all') return rows;
  if (filter === 'active') return rows.filter((r) => r.status === 'waiting' || r.status === 'in_progress');
  if (filter === 'waiting') return rows.filter((r) => r.status === 'waiting');
  if (filter === 'in_progress') return rows.filter((r) => r.status === 'in_progress');
  if (filter === 'closed') return rows.filter((r) => r.status === 'resolved' || r.status === 'rejected');
  return rows;
}

function reportCardHtml(r, activeId) {
  return `
    <div class="report-card ${activeId === r.id ? 'active' : ''}" data-id="${r.id}">
      <div class="top">
        <span class="id">#${r.id}</span>
        <span class="badge ${r.status}">${statusIcon(r.status)} ${r.statusLabel}</span>
      </div>
      <div class="title">${escapeHtml(r.title)}</div>
      <div class="meta">
        <span class="meta-cat">${iconHtml(r.categoryIcon, 'ui-icon--sm')}<span>${escapeHtml(r.categoryLabel)}</span></span>
        <span class="badge p-${r.priority}">${r.priorityLabel}</span>
        <span>${fmtTime(r.createdAt)}</span>
      </div>
    </div>
  `;
}

function detailHtml(r, admin) {
  const att = (r.attachments || []).map((a) => {
    return `<a class="attach-link" href="#" data-url="${escapeHtml(a.url)}">${attachIconHtml(a.type)} ${escapeHtml(a.label || a.url)}</a>`;
  }).join('') || '<p class="muted">Nėra priedų</p>';

  const replies = (r.replies || []).map((rep) => `
    <div class="reply-bubble">
      <div class="who">${escapeHtml(rep.staffName)} · ${fmtTime(rep.at)}</div>
      <div>${escapeHtml(rep.text)}</div>
    </div>
  `).join('') || '<p class="muted">Atsakymų dar nėra.</p>';

  let adminBlock = '';
  if (admin && r.canManage) {
    adminBlock = `
      <div class="admin-actions">
        <button class="btn secondary" data-action="status" data-status="in_progress">Nagrinėti</button>
        <button class="btn secondary" data-action="status" data-status="resolved">Išspręsti</button>
        <button class="btn secondary" data-action="status" data-status="rejected">Atmesti</button>
        <button class="btn secondary" data-action="status" data-status="waiting">Grąžinti į laukiamus</button>
      </div>
      <div class="admin-reply">
        <textarea id="adminReplyInput" rows="3" placeholder="Atsakymas žaidėjui..."></textarea>
        <button class="btn primary" data-action="reply">Siųsti atsakymą</button>
      </div>
    `;
  }

  return `
    <div class="detail-head">
      <div>
        <h3>#${r.id} · ${escapeHtml(r.title)}</h3>
        <p class="muted detail-cat">${categoryLabelHtml({ icon: r.categoryIcon, label: r.categoryLabel })} · ${fmtTime(r.createdAt)}</p>
      </div>
      <div>
        <span class="badge ${r.status}">${statusIcon(r.status)} ${r.statusLabel}</span>
        <span class="badge p-${r.priority}">${r.priorityLabel}</span>
      </div>
    </div>
    ${admin ? `<div class="detail-block"><h4>Žaidėjas</h4><p>${escapeHtml(r.name)} · ID ${r.source} · <span class="online-pill ${r.playerOnline ? 'on' : 'off'}">${r.playerOnline ? 'Online' : 'Offline'}</span></p></div>` : ''}
    <div class="detail-block"><h4>Aprašymas</h4><p>${escapeHtml(r.message)}</p></div>
    <div class="detail-block"><h4>Priedai</h4>${att}</div>
    <div class="detail-block"><h4>Admin atsakymai</h4><div class="replies">${replies}</div></div>
    ${adminBlock}
  `;
}

function bindDetailActions(container, reportId, admin) {
  container.querySelectorAll('[data-action="status"]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      await nui('setStatus', { reportId, status: btn.dataset.status });
      const res = await nui('refresh', { mode: 'admin' });
      if (res.rows) {
        state.bootstrap.adminReports = res.rows;
        renderAdminReports(res.rows);
      }
    });
  });
  const replyBtn = container.querySelector('[data-action="reply"]');
  if (replyBtn) {
    replyBtn.addEventListener('click', async () => {
      const text = $('#adminReplyInput')?.value?.trim();
      if (!text) return showToast('Įrašykite atsakymą.');
      await nui('reply', { reportId, text });
      const res = await nui('refresh', { mode: 'admin' });
      if (res.rows) {
        state.bootstrap.adminReports = res.rows;
        renderAdminReports(res.rows);
      }
    });
  }
  container.querySelectorAll('.attach-link').forEach((a) => {
    a.addEventListener('click', (e) => {
      e.preventDefault();
      showToast('Nuoroda: ' + a.dataset.url);
    });
  });
}

function renderMyReports(rows) {
  const filtered = filterReports(rows, state.mineFilter);
  const list = $('#myReportsList');
  if (!filtered.length) {
    list.innerHTML = '<div class="empty-state"><p>Reportų nėra.</p></div>';
    $('#myReportDetail').innerHTML = `<div class="empty-state">${iconHtml('inbox', 'empty-icon')}<p>Pasirinkite reportą</p></div>`;
    return;
  }
  list.innerHTML = filtered.map((r) => reportCardHtml(r, state.selectedMineId)).join('');
  list.querySelectorAll('.report-card').forEach((card) => {
    card.addEventListener('click', () => {
      state.selectedMineId = Number(card.dataset.id);
      const r = filtered.find((x) => x.id === state.selectedMineId);
      const detail = $('#myReportDetail');
      detail.innerHTML = r ? detailHtml(r, false) : '';
      renderMyReports(rows);
    });
  });
  if (!state.selectedMineId && filtered[0]) {
    state.selectedMineId = filtered[0].id;
    $('#myReportDetail').innerHTML = detailHtml(filtered[0], false);
    renderMyReports(rows);
  }
}

function renderAdminReports(rows) {
  const filtered = filterReports(rows, state.adminFilter);
  const list = $('#adminReportsList');
  const stats = {
    total: rows.length,
    waiting: rows.filter((r) => r.status === 'waiting').length,
    active: rows.filter((r) => r.status === 'waiting' || r.status === 'in_progress').length,
    high: rows.filter((r) => r.priority === 'high' && (r.status === 'waiting' || r.status === 'in_progress')).length,
  };
  $('#adminStats').innerHTML = `
    <div class="stat-pill">Viso: <strong>${stats.total}</strong></div>
    <div class="stat-pill">Laukia: <strong>${stats.waiting}</strong></div>
    <div class="stat-pill">Aktyvūs: <strong>${stats.active}</strong></div>
    <div class="stat-pill">Aukšto prioriteto: <strong>${stats.high}</strong></div>
  `;

  if (!filtered.length) {
    list.innerHTML = '<div class="empty-state"><p>Reportų nėra.</p></div>';
    return;
  }
  list.innerHTML = filtered.map((r) => reportCardHtml(r, state.selectedAdminId)).join('');
  list.querySelectorAll('.report-card').forEach((card) => {
    card.addEventListener('click', () => {
      state.selectedAdminId = Number(card.dataset.id);
      const r = rows.find((x) => x.id === state.selectedAdminId);
      const detail = $('#adminReportDetail');
      detail.innerHTML = r ? detailHtml(r, true) : '';
      bindDetailActions(detail, state.selectedAdminId, true);
      renderAdminReports(rows);
    });
  });
  if (state.selectedAdminId) {
    const r = rows.find((x) => x.id === state.selectedAdminId);
    if (r) {
      const detail = $('#adminReportDetail');
      detail.innerHTML = detailHtml(r, true);
      bindDetailActions(detail, state.selectedAdminId, true);
    }
  }
}

function showStaffNav(mode) {
  const isAdmin = mode === 'admin';
  $('#openAdminBtn').classList.toggle('hidden', isAdmin || !state.isStaff);
  $('#openPlayerBtn').classList.toggle('hidden', !isAdmin || !state.isStaff);
  $('#playerNav').classList.toggle('hidden', isAdmin);
  $('#adminNav').classList.toggle('hidden', !isAdmin);
  $('#staffBadge').hidden = !isAdmin;
}

function openBootstrap(data, view) {
  state.bootstrap = data;
  state.isStaff = !!data.isStaff;
  renderCategories();
  renderMyReports(data.myReports || []);
  if (data.isStaff) {
    renderAdminReports(data.adminReports || []);
    if (view === 'admin') {
      showStaffNav('admin');
      setView('admin');
    } else {
      showStaffNav('player');
      setView(view === 'mine' ? 'mine' : 'create');
    }
  } else {
    showStaffNav('player');
    setView(view === 'mine' ? 'mine' : 'create');
  }
  app.classList.remove('hidden');
  updateStepUi();
}

// Events
window.addEventListener('message', (e) => {
  const msg = e.data || {};
  if (msg.action === 'open') openBootstrap(msg.data, msg.view);
  if (msg.action === 'close') app.classList.add('hidden');
  if (msg.action === 'myReports') renderMyReports(msg.rows || []);
  if (msg.action === 'adminReports') renderAdminReports(msg.rows || []);
  if (msg.action === 'submitted' && msg.rows) renderMyReports(msg.rows);
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') closeUi();
});

$('#closeBtn').addEventListener('click', closeUi);

$('#openAdminBtn').addEventListener('click', () => {
  showStaffNav('admin');
  setView('admin');
  renderAdminReports(state.bootstrap?.adminReports || []);
});

$('#openPlayerBtn').addEventListener('click', () => {
  showStaffNav('player');
  setView('create');
});

$$('#playerNav .nav-btn').forEach((btn) => {
  btn.addEventListener('click', () => setView(btn.dataset.view));
});

$$('#adminNav .nav-btn').forEach((btn) => {
  btn.addEventListener('click', () => {
    state.adminFilter = btn.dataset.adminFilter;
    $$('#adminNav .nav-btn').forEach((b) => b.classList.toggle('active', b === btn));
    renderAdminReports(state.bootstrap?.adminReports || []);
  });
});

$$('#mineFilters .filter').forEach((btn) => {
  btn.addEventListener('click', () => {
    state.mineFilter = btn.dataset.filter;
    $$('#mineFilters .filter').forEach((b) => b.classList.toggle('active', b === btn));
    renderMyReports(state.bootstrap?.myReports || []);
  });
});

$('#prevStepBtn').addEventListener('click', () => {
  if (state.step > 1) { state.step -= 1; updateStepUi(); }
});

$('#nextStepBtn').addEventListener('click', () => {
  if (!validateStep()) return;
  if (state.step >= 5) {
    openConfirmModal();
    return;
  }
  state.step += 1;
  updateStepUi();
});

$('#titleInput').addEventListener('input', (e) => {
  state.form.title = e.target.value;
  $('#titleCount').textContent = state.form.title.length;
});

$('#messageInput').addEventListener('input', (e) => {
  state.form.message = e.target.value;
  $('#messageCount').textContent = state.form.message.length;
});

$$('.chip-btn[data-attach]').forEach((btn) => {
  btn.addEventListener('click', () => {
    state.pendingAttachType = btn.dataset.attach;
    const titles = { image: 'Nuotraukos nuoroda', video: 'Video nuoroda', link: 'Nuoroda' };
    $('#attachModalTitle').textContent = titles[state.pendingAttachType] || 'Pridėti nuorodą';
    $('#attachUrlInput').value = '';
    $('#attachLabelInput').value = '';
    $('#attachModal').classList.remove('hidden');
  });
});

$('#attachCancel').addEventListener('click', () => $('#attachModal').classList.add('hidden'));
$('#attachSave').addEventListener('click', () => {
  const url = $('#attachUrlInput').value.trim();
  const label = $('#attachLabelInput').value.trim();
  if (!url) return showToast('Įveskite nuorodą.');
  if (state.form.attachments.length >= 5) return showToast('Max. 5 priedai.');
  state.form.attachments.push({ type: state.pendingAttachType, url, label });
  renderAttachments();
  $('#attachModal').classList.add('hidden');
});

$('#confirmCancel').addEventListener('click', () => $('#confirmModal').classList.add('hidden'));
$('#confirmSubmit').addEventListener('click', submitReport);

function initStaticIcons() {
  document.querySelectorAll('[data-icon]').forEach((el) => {
    const key = el.dataset.icon;
    if (!key || !ICONS[key]) return;
    el.innerHTML = ICONS[key];
    el.classList.add('ui-icon');
    if (el.classList.contains('nav-ico')) el.classList.add('ui-icon--nav');
    if (el.classList.contains('empty-icon')) el.classList.add('ui-icon--empty');
    if (el.classList.contains('brand-icon')) el.classList.add('ui-icon--brand');
  });
}

initStaticIcons();
