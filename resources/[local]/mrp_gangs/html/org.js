/* ═══════════════════════════════════════════════════════════════════
   mrp_gangs — Organizacijos valdymo panelė (NUI logika, vanilla JS)
   Klientas TIK atvaizduoja; visa teisių/validacijos logika serveryje.
   ═══════════════════════════════════════════════════════════════════ */
(function () {
  'use strict';
  const RES = 'mrp_gangs';
  const PALETTE = ['#EF4444','#DC2626','#F97316','#F59E0B','#EAB308','#84CC16','#22C55E','#15803D',
    '#14B8A6','#06B6D4','#3B82F6','#6366F1','#7C3AED','#A855F7','#EC4899','#DB2777','#64748B','#0A0A0A'];
  const ICONS = { crown:'♛', star:'★', shield:'⛨', user:'•', 'user-clock':'◔', skull:'☠', bolt:'⚡', eye:'◉' };

  // ── DOM refs ──
  const root = document.getElementById('gangOrg');
  const elBrand = document.getElementById('orgBrand');
  const elNav = document.getElementById('orgNav');
  const elFoot = document.getElementById('orgSideFoot');
  const elTitle = document.getElementById('orgViewTitle');
  const elSub = document.getElementById('orgViewSub');
  const elTools = document.getElementById('orgTools');
  const elContent = document.getElementById('orgContent');
  const elDrawer = document.getElementById('orgDrawer');
  const elDrawerBg = document.getElementById('orgDrawerBackdrop');
  const elModal = document.getElementById('orgModal');
  const elToast = document.getElementById('orgToast');
  const elInvite = document.getElementById('orgInvite');

  // ── State ──
  let S = null;                 // getState rezultatas
  let view = 'structure';
  let permByKey = {};
  let respByKey = {};
  const tree = { x: 20, y: 20, scale: 1 };
  const collapsed = new Set();
  const logState = { page: 1, action: 'all', search: '' };
  let inviteTimer = null;

  const NAV = [
    { id: 'structure', label: 'Struktūra', ico: '⛬' },
    { id: 'members', label: 'Nariai', ico: '👤' },
    { id: 'turfs', label: 'Turfai', ico: '⌖' },
    { id: 'ranks', label: 'Rangai ir teisės', ico: '⛨' },
    { id: 'associates', label: 'Asocijuoti', ico: '🤝' },
    { id: 'relations', label: 'Santykiai', ico: '⚔' },
    { id: 'logs', label: 'Veiklos žurnalas', ico: '🗒' },
    { id: 'settings', label: 'Nustatymai', ico: '⚙' },
  ];
  const NAV_READONLY = new Set(['structure', 'members', 'turfs', 'ranks']);

  const LOG_ACTIONS = {
    member_joined: 'Narys priimtas', member_kicked: 'Narys išmestas', member_rank_changed: 'Pakeistas rangas',
    member_status_changed: 'Pakeistas statusas', member_notes_edited: 'Redaguota pastaba',
    member_responsibilities_changed: 'Pakeistos atsakomybės', member_overrides_changed: 'Pakeistos individualios teisės',
    rank_created: 'Sukurtas rangas', rank_edited: 'Redaguotas rangas', rank_deleted: 'Ištrintas rangas',
    rank_moved: 'Perkeltas rangas', rank_permissions_changed: 'Pakeistos rango teisės', rank_members_moved: 'Perkelti nariai',
    associate_added: 'Pridėtas asocijuotas', associate_edited: 'Redaguotas asocijuotas', associate_removed: 'Pašalintas asocijuotas',
    associate_promotion_offered: 'Pasiūlyta narystė', relation_offer_sent: 'Išsiųstas pasiūlymas', relation_set: 'Nustatytas santykis',
    relation_accepted: 'Priimtas santykis', relation_declined: 'Atmestas pasiūlymas', relation_broken: 'Nutrauktas santykis',
    ownership_transferred: 'Perduota nuosavybė', settings_changed: 'Pakeisti nustatymai',
  };

  // ── Helpers ──
  function el(tag, cls, html) { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; }
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c])); }
  function initials(name) { const p = String(name || '?').trim().split(/\s+/); return ((p[0]||'?')[0] + (p[1]||'')[0] || '?').toUpperCase(); }
  function fmtDate(v) { if (!v) return '—'; const d = new Date(String(v).replace(' ', 'T')); return isNaN(d) ? String(v) : d.toLocaleString('lt-LT'); }
  function hasPerm(k) { return !!(S && S.me && (S.me.wildcard || (S.me.permissions || []).indexOf(k) >= 0)); }
  function isReadOnly() { return !!(S && S.me && S.me.readOnly); }

  async function post(cb, data) {
    try {
      const r = await fetch(`https://${RES}/${cb}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}) });
      return await r.json();
    } catch (e) { return { ok: false, msg: 'Ryšio klaida.' }; }
  }
  function call(name, payload) { return post('org:call', { name, payload: payload || {} }); }

  let toastT = null;
  function toast(msg, ok) {
    elToast.textContent = msg || '';
    elToast.className = 'org-toast show ' + (ok === false ? 'err' : 'ok');
    clearTimeout(toastT);
    toastT = setTimeout(() => { elToast.className = 'org-toast'; }, 2600);
  }

  // ── Open / close / refresh ──
  async function openMenu() {
    root.classList.remove('hidden');
    await refresh();
  }
  function closeMenu() { post('org:close'); root.classList.add('hidden'); closeDrawer(); closeModal(); }

  let refreshing = false, refreshQueued = false;
  async function refresh() {
    if (refreshing) { refreshQueued = true; return; }
    refreshing = true;
    const res = await call('getState');
    refreshing = false;
    if (refreshQueued) { refreshQueued = false; setTimeout(refresh, 60); }
    if (!res || !res.ok) { toast((res && res.msg) || 'Klaida.', false); if (!S) closeMenu(); return; }
    S = res;
    permByKey = {}; (S.catalog.permissionGroups || []).forEach(g => g.perms.forEach(p => permByKey[p.key] = p.label));
    respByKey = {}; (S.catalog.responsibilities || []).forEach(r => respByKey[r.id] = r.label);
    renderShell();
    renderView();
  }

  function renderShell() {
    const g = S.gang;
    const ro = isReadOnly();
    elBrand.innerHTML = '';
    const em = el('div', 'org-emblem'); em.style.background = `linear-gradient(135deg, ${g.color||'#e11d48'}, ${g.secondaryColor||g.color||'#7c3aed'})`;
    em.textContent = initials(g.label || g.name);
    const brandSub = ro
      ? `Tik peržiūra · ${S.members.length} narių`
      : `${esc(g.gangType || '')} · ${S.members.length} narių`;
    const bt = el('div', 'org-brand-text', `<h3>${esc(g.label || g.name)}</h3><span>${brandSub}</span>`);
    elBrand.append(em, bt);

    elNav.innerHTML = '';
    NAV.forEach(n => {
      if (ro && !NAV_READONLY.has(n.id)) return;
      if (!ro && n.id === 'turfs' && !(S.turfs && S.turfs.length)) {
        /* turfų skirtuką rodome visada read-only; savo gaujai — jei yra turfų arba visada */
      }
      if (n.id === 'logs' && !hasPerm('gang.view_logs')) return;
      if (n.id === 'relations' && !hasPerm('diplomacy.view')) return;
      const item = el('div', 'org-nav-item' + (view === n.id ? ' active' : ''));
      item.innerHTML = `<span class="ico">${n.ico}</span><span>${n.label}</span>`;
      const cnt = n.id === 'members' ? S.members.length
        : n.id === 'associates' ? S.associates.length
        : n.id === 'ranks' ? S.ranks.length
        : n.id === 'turfs' ? (S.turfs || []).length
        : null;
      if (cnt != null) item.append(el('span', 'badge', String(cnt)));
      item.onclick = () => { view = n.id; renderShell(); renderView(); };
      elNav.append(item);
    });

    if (ro && !NAV_READONLY.has(view)) view = 'structure';

    elFoot.innerHTML = '';
    const me = el('div', 'org-me');
    me.innerHTML = `<span class="org-me-dot"></span><div><div style="font-size:12.5px">${esc(S.me.rankLabel || 'Narys')}</div><small>${ro ? 'Svetima planšetė' : (S.me.isOwner ? 'Savininkas' : 'Tavo rangas')}</small></div>`;
    const close = el('button', 'obtn obtn-ghost', 'Uždaryti (ESC)'); close.style.marginTop = '4px'; close.onclick = closeMenu;
    elFoot.append(me, close);
  }

  function setTools(nodes) { elTools.innerHTML = ''; (nodes || []).forEach(n => elTools.append(n)); }

  function renderView() {
    const meta = NAV.find(n => n.id === view) || {};
    elTitle.textContent = meta.label || '';
    elSub.textContent = isReadOnly() ? 'Tik peržiūra — keisti negalima' : '';
    elContent.innerHTML = '';
    setTools([]);
    ({ structure: viewStructure, members: viewMembers, turfs: viewTurfs, ranks: viewRanks, associates: viewAssociates, relations: viewRelations, logs: viewLogs, settings: viewSettings }[view] || viewStructure)();
  }

  // ═══ STRUCTURE (hierarchy tree) ═══
  function viewStructure() {
    elSub.textContent = isReadOnly()
      ? 'Hierarchija (tik peržiūra)'
      : 'Vizuali organizacijos hierarchija';
    const btnExpand = el('button', 'obtn obtn-ghost sm', 'Išskleisti'); btnExpand.onclick = () => { collapsed.clear(); viewStructure(); };
    const btnCollapse = el('button', 'obtn obtn-ghost sm', 'Suskleisti'); btnCollapse.onclick = () => { S.ranks.forEach(r => { if (childrenOf(r.id).length) collapsed.add(r.id); }); viewStructure(); };
    const zi = el('button', 'obtn obtn-ghost sm', '＋'); zi.onclick = () => { tree.scale = Math.min(1.8, tree.scale + 0.15); applyTree(); };
    const zo = el('button', 'obtn obtn-ghost sm', '－'); zo.onclick = () => { tree.scale = Math.max(0.4, tree.scale - 0.15); applyTree(); };
    const zr = el('button', 'obtn obtn-ghost sm', '↺'); zr.onclick = () => { tree.x = 20; tree.y = 20; tree.scale = 1; applyTree(); };
    setTools([btnExpand, btnCollapse, zi, zo, zr]);

    const wrap = el('div', 'org-tree-wrap');
    const canvas = el('div', 'org-tree-canvas');
    const treeEl = el('div', 'org-tree');
    const roots = S.ranks.filter(r => !r.parentRankId || !S.ranks.some(x => x.id === r.parentRankId));
    roots.sort((a, b) => b.priority - a.priority);
    const ul = el('ul');
    roots.forEach(r => ul.append(renderTreeNode(r)));
    treeEl.append(ul);
    canvas.append(treeEl);
    wrap.append(canvas);
    elContent.style.padding = '0';
    elContent.append(wrap);
    elContent.style.height = 'calc(100% - 0px)';
    bindPanZoom(wrap, canvas);
    applyTree(canvas);
  }

  function childrenOf(id) { return S.ranks.filter(r => r.parentRankId === id).sort((a, b) => b.priority - a.priority); }

  function renderTreeNode(rank) {
    const li = el('li');
    const node = el('div', 'rank-node' + (rank.isOwnerRank ? ' owner' : ''));
    const bar = el('div', 'rn-bar'); bar.style.background = rank.color; node.append(bar);
    const body = el('div', 'rn-body');
    const perms = (rank.permissions || []);
    const permTxt = isReadOnly()
      ? `${rank.memberCount} narių`
      : (perms[0] === '*' ? 'Visos teisės' : perms.slice(0, 3).map(p => permByKey[p] || p).join(', ') + (perms.length > 3 ? ` +${perms.length - 3}` : ''));
    body.innerHTML =
      `<div class="rn-top"><span class="rn-name">${ICONS[rank.icon] || '◆'} ${esc(rank.label)}</span><span class="rn-prio">P${rank.priority}</span></div>` +
      `<div class="rn-meta"><span>${rank.memberCount} narių</span>${rank.canHaveChildren ? '<span>· gali turėti pavaldžių</span>' : ''}</div>` +
      `<div class="rn-perms"><span class="miniperm">${esc(permTxt || '—')}</span></div>`;
    node.append(body);
    node.onclick = (e) => { e.stopPropagation(); if (isReadOnly()) openRankDrawerView(rank); else openRankDrawer(rank); };
    li.append(node);

    // Nariai + asocijuoti (dashed) po rangu.
    const mem = S.members.filter(m => m.rankId === rank.id);
    const assoc = S.associates.filter(a => a.handlerCitizenid && S.members.some(m => m.citizenid === a.handlerCitizenid && m.rankId === rank.id));
    if (mem.length || assoc.length) {
      const box = el('div', 'rn-members');
      mem.slice(0, 8).forEach(m => {
        const c = el('div', 'rn-member');
        c.innerHTML = `<span class="mdot ${m.online ? 'on' : ''}"></span>${esc(m.name)}${m.isOwner ? ' ♛' : ''}`;
        c.onclick = (e) => { e.stopPropagation(); openMemberDrawer(m); };
        box.append(c);
      });
      if (mem.length > 8) box.append(el('div', 'rn-member', `+${mem.length - 8} daugiau`));
      assoc.slice(0, 5).forEach(a => {
        const c = el('div', 'rn-member assoc');
        c.innerHTML = `<span class="mdot ${a.online ? 'on' : ''}"></span>${esc(a.name)} · assoc`;
        c.onclick = (e) => { e.stopPropagation(); openAssociateDrawer(a); };
        box.append(c);
      });
      li.append(box);
    }

    const kids = childrenOf(rank.id);
    if (kids.length) {
      const toggle = el('div', 'rn-collapse', collapsed.has(rank.id) ? '+' : '−');
      toggle.onclick = (e) => { e.stopPropagation(); collapsed.has(rank.id) ? collapsed.delete(rank.id) : collapsed.add(rank.id); viewStructure(); };
      node.style.position = 'relative'; node.append(toggle);
      if (!collapsed.has(rank.id)) {
        const cul = el('ul');
        kids.forEach(k => cul.append(renderTreeNode(k)));
        li.append(cul);
      }
    }
    return li;
  }

  function applyTree(canvas) { canvas = canvas || document.querySelector('.org-tree-canvas'); if (canvas) canvas.style.transform = `translate(${tree.x}px, ${tree.y}px) scale(${tree.scale})`; }
  function bindPanZoom(wrap, canvas) {
    let dragging = false, sx = 0, sy = 0, ox = 0, oy = 0;
    wrap.addEventListener('mousedown', e => { if (e.target.closest('.rank-node') || e.target.closest('.rn-member')) return; dragging = true; wrap.classList.add('grabbing'); sx = e.clientX; sy = e.clientY; ox = tree.x; oy = tree.y; });
    window.addEventListener('mousemove', e => { if (!dragging) return; tree.x = ox + (e.clientX - sx); tree.y = oy + (e.clientY - sy); applyTree(canvas); });
    window.addEventListener('mouseup', () => { dragging = false; wrap.classList.remove('grabbing'); });
    wrap.addEventListener('wheel', e => { e.preventDefault(); tree.scale = Math.max(0.4, Math.min(1.8, tree.scale + (e.deltaY < 0 ? 0.1 : -0.1))); applyTree(canvas); }, { passive: false });
  }

  // ═══ MEMBERS ═══
  let memberFilter = { search: '', rank: 'all', status: 'all' };
  function viewMembers() {
    elSub.textContent = `${S.members.length} narių`;
    const search = el('input', 'oinput osearch'); search.placeholder = 'Ieškoti nario…'; search.value = memberFilter.search;
    search.oninput = () => { memberFilter.search = search.value.toLowerCase(); renderMemberCards(grid); };
    const rankSel = el('select', 'oselect'); rankSel.style.maxWidth = '170px';
    rankSel.innerHTML = '<option value="all">Visi rangai</option>' + S.ranks.map(r => `<option value="${r.id}">${esc(r.label)}</option>`).join('');
    rankSel.value = memberFilter.rank; rankSel.onchange = () => { memberFilter.rank = rankSel.value; renderMemberCards(grid); };
    const statSel = el('select', 'oselect'); statSel.style.maxWidth = '150px';
    statSel.innerHTML = '<option value="all">Visi statusai</option><option value="online">Prisijungę</option>' + (S.catalog.memberStatuses || []).map(s => `<option value="${s}">${s}</option>`).join('');
    statSel.value = memberFilter.status; statSel.onchange = () => { memberFilter.status = statSel.value; renderMemberCards(grid); };
    const tools = [search, rankSel, statSel];
    if (!isReadOnly() && hasPerm('members.invite')) { const b = el('button', 'obtn obtn-primary sm', '＋ Pakviesti'); b.onclick = openInviteForm; tools.push(b); }
    setTools(tools);
    const grid = el('div', 'org-cards');
    elContent.append(grid);
    renderMemberCards(grid);
  }
  function renderMemberCards(grid) {
    grid.innerHTML = '';
    const list = S.members.filter(m => {
      if (memberFilter.search && !(m.name.toLowerCase().includes(memberFilter.search) || (m.citizenid||'').toLowerCase().includes(memberFilter.search))) return false;
      if (memberFilter.rank !== 'all' && String(m.rankId) !== memberFilter.rank) return false;
      if (memberFilter.status === 'online' && !m.online) return false;
      else if (memberFilter.status !== 'all' && memberFilter.status !== 'online' && m.status !== memberFilter.status) return false;
      return true;
    }).sort((a, b) => b.priority - a.priority);
    if (!list.length) { grid.append(el('div', 'org-empty', 'Narių nerasta.')); return; }
    list.forEach(m => {
      const card = el('div', 'org-card');
      const av = el('div', 'org-avatar'); av.style.background = m.rankColor; av.textContent = initials(m.name);
      av.append(el('span', 'dot ' + (m.online ? 'on' : '')));
      const head = el('div', 'org-card-head');
      head.append(av, el('div', 'org-card-title', `<strong>${esc(m.name)}${m.isOwner ? ' ♛' : ''}</strong><span>${esc(m.citizenid)}${m.online ? ' · ID ' + m.serverId : ''}</span>`));
      const chips = el('div', 'org-chiprow');
      const rc = el('span', 'chip rank' + (m.isOwner ? ' owner' : '')); rc.style.borderColor = m.rankColor + '66'; rc.textContent = m.rankLabel; chips.append(rc);
      chips.append(el('span', 'chip status-' + m.status, m.status));
      (m.responsibilities || []).forEach(r => chips.append(el('span', 'chip', respByKey[r] || r)));
      card.append(head, chips);
      card.onclick = () => openMemberDrawer(m);
      grid.append(card);
    });
  }

  function openMemberDrawer(m) {
    if (isReadOnly()) {
      const body = el('div');
      body.innerHTML =
        row('Citizen ID', m.citizenid) + row('Statusas', m.status) +
        row('Būsena', m.online ? 'Prisijungęs · ID ' + m.serverId : 'Atsijungęs') +
        row('Rangas', m.rankLabel) + row('Prisijungė', fmtDate(m.joinedAt)) +
        row('Pask. aktyvumas', fmtDate(m.lastActive));
      openDrawer(`${m.name}${m.isOwner ? ' ♛' : ''}`, body, []);
      return;
    }
    const body = el('div');
    const dl = el('div');
    dl.innerHTML =
      row('Citizen ID', m.citizenid) + row('Statusas', m.status) + row('Būsena', m.online ? 'Prisijungęs · ID ' + m.serverId : 'Atsijungęs') +
      row('Rangas', m.rankLabel) + row('Prisijungė', fmtDate(m.joinedAt)) + row('Pask. aktyvumas', fmtDate(m.lastActive)) +
      row('Priėmė', m.invitedByName || m.invitedBy || '—');
    body.append(dl);

    // Pastaba
    if (hasPerm('members.edit_notes')) {
      const f = el('div', 'ofield'); f.append(el('label', null, 'Vidinė pastaba'));
      const ta = el('textarea', 'otext'); ta.value = m.notes || ''; f.append(ta);
      const b = el('button', 'obtn sm', 'Išsaugoti pastabą'); b.onclick = async () => { const r = await call('setMemberNotes', { citizenid: m.citizenid, notes: ta.value }); after(r); };
      f.append(b); body.append(f);
    } else if (m.notes) { body.append(el('div', 'ofield', `<label>Pastaba</label><div class="small" style="font-size:12.5px;color:var(--org-muted)">${esc(m.notes)}</div>`)); }

    const foot = [];
    if (!m.isOwner && m.manageable) {
      // Rangas
      if (hasPerm('members.promote') || hasPerm('members.demote') || hasPerm('members.move_rank')) {
        const f = el('div', 'ofield'); f.append(el('label', null, 'Keisti rangą'));
        const sel = el('select', 'oselect');
        sel.innerHTML = S.ranks.filter(r => !r.isOwnerRank).sort((a,b)=>b.priority-a.priority).map(r => `<option value="${r.id}" ${r.id===m.rankId?'selected':''}>${esc(r.label)} (P${r.priority})</option>`).join('');
        f.append(sel);
        const b = el('button', 'obtn sm', 'Taikyti rangą'); b.onclick = async () => { const r = await call('setMemberRank', { citizenid: m.citizenid, rankId: Number(sel.value) }); after(r); };
        f.append(b); body.append(f);
      }
      // Statusas
      if (hasPerm('members.suspend')) {
        const f = el('div', 'ofield'); f.append(el('label', null, 'Statusas'));
        const sel = el('select', 'oselect');
        sel.innerHTML = (S.catalog.memberStatuses||[]).map(s => `<option value="${s}" ${s===m.status?'selected':''}>${s}</option>`).join('');
        f.append(sel);
        const b = el('button', 'obtn sm', 'Taikyti statusą'); b.onclick = async () => { const r = await call('setMemberStatus', { citizenid: m.citizenid, status: sel.value }); after(r); };
        f.append(b); body.append(f);
      }
      // Atsakomybės
      if (hasPerm('members.assign_resp')) {
        const f = el('div', 'ofield'); f.append(el('label', null, 'Atsakomybės'));
        const box = el('div');
        (S.catalog.responsibilities || []).forEach(rp => {
          const lbl = el('label', 'perm-check'); const cb = el('input'); cb.type = 'checkbox'; cb.value = rp.id; cb.checked = (m.responsibilities||[]).indexOf(rp.id) >= 0;
          lbl.append(cb, document.createTextNode(rp.label)); box.append(lbl);
        });
        f.append(box);
        const b = el('button', 'obtn sm', 'Išsaugoti atsakomybes'); b.onclick = async () => {
          const chosen = [...box.querySelectorAll('input:checked')].map(i => i.value);
          const r = await call('setMemberResponsibilities', { citizenid: m.citizenid, responsibilities: chosen }); after(r);
        };
        f.append(b); body.append(f);
      }
      if (hasPerm('members.kick')) { const b = el('button', 'obtn obtn-danger', 'Išmesti narį'); b.onclick = () => confirmModal(`Išmesti ${m.name}?`, async () => { const r = await call('kickMember', { citizenid: m.citizenid }); after(r, true); }); foot.push(b); }
    }
    if (S.me.isOwner && !m.isOwner) {
      const b = el('button', 'obtn obtn-danger', 'Perduoti nuosavybę'); b.onclick = () => confirmModal(`Perduoti gaujos nuosavybę nariui ${m.name}? Šis veiksmas negrįžtamas.`, async () => { const r = await call('transferOwnership', { citizenid: m.citizenid, confirm: true }); after(r, true); }); foot.push(b);
    }
    openDrawer(`${m.name}${m.isOwner ? ' ♛' : ''}`, body, foot);
  }

  // ═══ TURFS ═══
  function viewTurfs() {
    const list = S.turfs || [];
    elSub.textContent = list.length ? `${list.length} užimtų teritorijų` : 'Nėra užimtų teritorijų';
    if (!list.length) {
      elContent.append(el('div', 'org-empty', 'Ši gauja šiuo metu nekontroliuoja jokių turfų.'));
      return;
    }
    const tbl = el('table', 'org-table');
    tbl.innerHTML = '<thead><tr><th>Teritorija</th><th>Įtaka</th><th>Heat</th><th>Pardavimai</th><th>Pelnas</th></tr></thead>';
    const tb = el('tbody');
    list.forEach(t => {
      const tr = el('tr');
      tr.innerHTML = `<td>${esc(t.label || t.id)}</td><td>${Number(t.influence || 0)}%</td><td>${Number(t.heat || 0)}</td><td>${Number(t.salesCount || 0)}</td><td>$${Number(t.profit || 0).toLocaleString()}</td>`;
      tb.append(tr);
    });
    tbl.append(tb);
    elContent.append(tbl);
  }

  // ═══ RANKS ═══
  function viewRanks() {
    elSub.textContent = isReadOnly()
      ? `${S.ranks.length} rangų (tik peržiūra)`
      : `${S.ranks.length} / ${S.catalog.maxRanks} rangų`;
    if (!isReadOnly() && hasPerm('ranks.create')) { const b = el('button', 'obtn obtn-primary sm', '＋ Naujas rangas'); b.onclick = () => openRankDrawer(null); setTools([b]); }
    const tbl = el('table', 'org-table');
    tbl.innerHTML = '<thead><tr><th>Rangas</th><th>Prioritetas</th><th>Viršesnis</th><th>Nariai</th>' + (isReadOnly() ? '' : '<th>Teisės</th>') + '</tr></thead>';
    const tb = el('tbody');
    S.ranks.slice().sort((a,b)=>b.priority-a.priority).forEach(r => {
      const tr = el('tr'); tr.style.cursor = 'pointer';
      const parent = S.ranks.find(x => x.id === r.parentRankId);
      const permCount = (r.permissions||[])[0] === '*' ? 'Visos' : (r.permissions||[]).length;
      tr.innerHTML = `<td><span style="color:${r.color}">${ICONS[r.icon]||'◆'}</span> ${esc(r.label)}${r.isOwnerRank?' <span class="chip owner">owner</span>':''}</td><td>P${r.priority}</td><td>${parent?esc(parent.label):'—'}</td><td>${r.memberCount}</td>` + (isReadOnly() ? '' : `<td>${permCount}</td>`);
      tr.onclick = () => { if (isReadOnly()) openRankDrawerView(r); else openRankDrawer(r); };
      tb.append(tr);
    });
    tbl.append(tb); elContent.append(tbl);
  }

  function openRankDrawerView(rank) {
    const body = el('div');
    body.innerHTML =
      row('Rangas', rank.label) +
      row('Prioritetas', 'P' + rank.priority) +
      row('Nariai', String(rank.memberCount || 0)) +
      row('Savininko rangas', rank.isOwnerRank ? 'Taip' : 'Ne') +
      row('Gali turėti pavaldžių', rank.canHaveChildren ? 'Taip' : 'Ne');
    openDrawer(rank.label, body, []);
  }

  function openRankDrawer(rank) {
    const isNew = !rank;
    const r = rank || { label: '', name: '', priority: 30, color: '#64748B', icon: 'user', parentRankId: null, canHaveChildren: true, permissions: [], isOwnerRank: false };
    const body = el('div');
    const fLabel = field('Pavadinimas', inputEl(r.label, 'text'));
    const fPrio = field('Prioritetas (0-99)', inputEl(r.priority, 'number'));
    const fIcon = (() => { const s = el('select','oselect'); s.innerHTML = Object.keys(ICONS).map(k=>`<option value="${k}" ${k===r.icon?'selected':''}>${ICONS[k]} ${k}</option>`).join(''); return field('Ikona', s); })();
    const fParent = (() => {
      const s = el('select', 'oselect');
      s.innerHTML = '<option value="">— šaknis —</option>' + S.ranks.filter(x => x.id !== r.id && x.canHaveChildren).map(x => `<option value="${x.id}" ${x.id===r.parentRankId?'selected':''}>${esc(x.label)}</option>`).join('');
      return field('Viršesnis rangas', s);
    })();
    const cbChildren = el('input'); cbChildren.type = 'checkbox'; cbChildren.checked = r.canHaveChildren;
    const fChildren = el('label', 'perm-check'); fChildren.append(cbChildren, document.createTextNode('Gali turėti pavaldžių rangų'));
    body.append(fLabel.wrap, fPrio.wrap, fIcon.wrap, fParent.wrap, fChildren);

    // Spalva
    const fc = el('div', 'ofield'); fc.append(el('label', null, 'Spalva'));
    const sw = el('div', 'swatches'); let chosenColor = r.color;
    PALETTE.forEach(hex => { const s = el('div', 'swatch' + (hex.toUpperCase()===String(r.color).toUpperCase()?' sel':'')); s.style.background = hex; s.onclick = () => { chosenColor = hex; sw.querySelectorAll('.swatch').forEach(x=>x.classList.remove('sel')); s.classList.add('sel'); }; sw.append(s); });
    fc.append(sw); body.append(fc);

    // Teisės
    if (!r.isOwnerRank) {
      body.append(el('div', 'org-section-title', 'Teisės'));
      const permWrap = el('div');
      const chosen = new Set((r.permissions||[])[0] === '*' ? [] : (r.permissions||[]));
      (S.catalog.permissionGroups || []).forEach(g => {
        const grp = el('div', 'perm-group'); grp.append(el('h4', null, g.label));
        g.perms.forEach(p => {
          const canAssign = S.me.wildcard || (S.me.permissions||[]).indexOf(p.key) >= 0;
          const lbl = el('label', 'perm-check' + (canAssign ? '' : ' disabled'));
          const cb = el('input'); cb.type = 'checkbox'; cb.value = p.key; cb.checked = chosen.has(p.key); cb.disabled = !canAssign;
          lbl.append(cb, document.createTextNode(p.label)); grp.append(lbl);
        });
        permWrap.append(grp);
      });
      body.append(permWrap);
      body._permWrap = permWrap;
    } else {
      body.append(el('div', 'org-empty', 'Savininko rangas turi visas teises.'));
    }

    const foot = [];
    const gather = () => ({
      rankId: r.id, label: fLabel.input.value, priority: Number(fPrio.input.value),
      color: chosenColor, icon: fIcon.wrap.querySelector('select').value,
      parentRankId: fParent.wrap.querySelector('select').value ? Number(fParent.wrap.querySelector('select').value) : null,
      canHaveChildren: cbChildren.checked,
    });
    const gatherPerms = () => body._permWrap ? [...body._permWrap.querySelectorAll('input:checked')].map(i => i.value) : [];

    if (isNew && hasPerm('ranks.create')) {
      const b = el('button', 'obtn obtn-primary', 'Sukurti'); b.onclick = async () => { const d = gather(); d.permissions = gatherPerms(); const res = await call('createRank', d); after(res, true); }; foot.push(b);
    } else if (!isNew) {
      if (hasPerm('ranks.edit')) { const b = el('button', 'obtn obtn-primary', 'Išsaugoti'); b.onclick = async () => { const res = await call('editRank', gather()); after(res); }; foot.push(b); }
      if (!r.isOwnerRank && hasPerm('ranks.edit_permissions')) { const b = el('button', 'obtn', 'Išsaugoti teises'); b.onclick = async () => { const res = await call('setRankPermissions', { rankId: r.id, permissions: gatherPerms() }); after(res); }; foot.push(b); }
      if (!r.isOwnerRank && hasPerm('ranks.reorder')) { const b = el('button', 'obtn', 'Perkelti'); b.onclick = async () => { const res = await call('setRankParent', { rankId: r.id, parentRankId: fParent.wrap.querySelector('select').value ? Number(fParent.wrap.querySelector('select').value) : null }); after(res, true); }; foot.push(b); }
      if (!r.isOwnerRank && r.memberCount > 0 && (hasPerm('ranks.reorder') || hasPerm('members.move_rank'))) {
        const b = el('button', 'obtn', 'Perkelti narius'); b.onclick = () => moveMembersModal(r); foot.push(b);
      }
      if (!r.isOwnerRank && hasPerm('ranks.delete')) { const b = el('button', 'obtn obtn-danger', 'Ištrinti'); b.onclick = () => confirmModal(`Ištrinti rangą „${r.label}"? Rangas turi būti tuščias.`, async () => { const res = await call('deleteRank', { rankId: r.id }); after(res, true); }); foot.push(b); }
    }
    openDrawer(isNew ? 'Naujas rangas' : r.label, body, foot);
  }

  function moveMembersModal(fromRank) {
    const b = el('div');
    const f = field('Perkelti visus narius į', (() => { const s = el('select','oselect'); s.innerHTML = S.ranks.filter(x => !x.isOwnerRank && x.id !== fromRank.id).map(x=>`<option value="${x.id}">${esc(x.label)}</option>`).join(''); return s; })());
    b.append(f.wrap);
    openModal('Perkelti narius', b, [okBtn('Perkelti', async () => { const to = f.wrap.querySelector('select').value; const res = await call('moveRankMembers', { fromRankId: fromRank.id, toRankId: Number(to) }); closeModal(); after(res, true); })]);
  }

  // ═══ ASSOCIATES ═══
  function viewAssociates() {
    elSub.textContent = `${S.associates.length} asocijuotų civilių`;
    const tools = [];
    if (hasPerm('associates.add')) { const b = el('button', 'obtn obtn-primary sm', '＋ Pridėti'); b.onclick = openAssociateForm; tools.push(b); }
    setTools(tools);
    if (!hasPerm('associates.view_info') && !S.me.wildcard) { elContent.append(el('div','org-empty','Neturi teisės matyti asocijuotų.')); return; }
    const grid = el('div', 'org-cards');
    if (!S.associates.length) grid.append(el('div', 'org-empty', 'Asocijuotų civilių nėra.'));
    S.associates.forEach(a => {
      const typ = (S.catalog.associateTypes.find(t => t.id === a.associateType) || {}).label || a.associateType;
      const card = el('div', 'org-card');
      const av = el('div', 'org-avatar'); av.style.background = '#334155'; av.textContent = initials(a.name); av.append(el('span', 'dot ' + (a.online ? 'on' : '')));
      const head = el('div', 'org-card-head');
      head.append(av, el('div', 'org-card-title', `<strong>${esc(a.name)}</strong><span>${esc(typ)}</span>`));
      const chips = el('div', 'org-chiprow');
      chips.append(el('span', 'chip dashed status-' + a.status, a.status));
      if (a.handlerName) chips.append(el('span', 'chip', 'Kontaktas: ' + esc(a.handlerName)));
      card.append(head, chips);
      card.onclick = () => openAssociateDrawer(a);
      grid.append(card);
    });
    elContent.append(grid);
  }

  function openAssociateForm() {
    const body = el('div');
    const fId = field('Žaidėjo server ID', inputEl('', 'number'));
    const fType = field('Tipas', selectEl(S.catalog.associateTypes.map(t => ({ v: t.id, t: t.label }))));
    const fHandler = field('Atsakingas narys (nebūtina)', selectEl([{ v: '', t: '— aš pats —' }].concat(S.members.map(m => ({ v: m.citizenid, t: m.name })))));
    const fNotes = field('Pastaba', textEl(''));
    body.append(fId.wrap, fType.wrap, fHandler.wrap, fNotes.wrap);
    body.append(el('div','org-section-title','Ribotos prieigos'));
    const accBox = el('div');
    (S.catalog.associateAccess || []).forEach(a => { const l = el('label','perm-check'); const cb=el('input'); cb.type='checkbox'; cb.value=a.key; l.append(cb, document.createTextNode(a.label)); accBox.append(l); });
    body.append(accBox);
    openDrawer('Pridėti asocijuotą', body, [okBtn('Pridėti', async () => {
      const res = await call('addAssociate', {
        targetServerId: Number(fId.input.value), associateType: fType.wrap.querySelector('select').value,
        handlerCitizenid: fHandler.wrap.querySelector('select').value, notes: fNotes.wrap.querySelector('textarea').value,
        permissions: [...accBox.querySelectorAll('input:checked')].map(i => i.value),
      }); after(res, true);
    })]);
  }

  function openAssociateDrawer(a) {
    const body = el('div');
    const dl = el('div'); dl.innerHTML = row('Citizen ID', a.citizenid) + row('Būsena', a.online ? 'Prisijungęs · ID '+a.serverId : 'Atsijungęs') + row('Kontaktas', a.handlerName || '—');
    body.append(dl);
    const canEdit = hasPerm('associates.edit_status');
    const fType = field('Tipas', selectEl(S.catalog.associateTypes.map(t => ({ v: t.id, t: t.label })), a.associateType));
    const fStatus = field('Statusas', selectEl((S.catalog.associateStatuses||[]).map(s => ({ v: s, t: s })), a.status));
    const fHandler = field('Atsakingas narys', selectEl([{ v: '', t: '—' }].concat(S.members.map(m => ({ v: m.citizenid, t: m.name }))), a.handlerCitizenid || ''));
    const fNotes = field('Pastaba', textEl(a.notes || ''));
    body.append(fType.wrap, fStatus.wrap, fHandler.wrap, fNotes.wrap);
    body.append(el('div','org-section-title','Ribotos prieigos'));
    const accBox = el('div');
    (S.catalog.associateAccess || []).forEach(ac => { const l = el('label','perm-check'); const cb=el('input'); cb.type='checkbox'; cb.value=ac.key; cb.checked=(a.permissions||[]).indexOf(ac.key)>=0; l.append(cb, document.createTextNode(ac.label)); accBox.append(l); });
    body.append(accBox);
    if (!canEdit) body.querySelectorAll('select, textarea, input').forEach(i => i.disabled = true);

    const foot = [];
    if (canEdit) foot.push(okBtn('Išsaugoti', async () => {
      const res = await call('editAssociate', {
        citizenid: a.citizenid, associateType: fType.wrap.querySelector('select').value, status: fStatus.wrap.querySelector('select').value,
        handlerCitizenid: fHandler.wrap.querySelector('select').value, notes: fNotes.wrap.querySelector('textarea').value,
        permissions: [...accBox.querySelectorAll('input:checked')].map(i => i.value),
      }); after(res);
    }));
    if (hasPerm('associates.promote')) { const b = el('button', 'obtn', 'Paaukštinti į narį'); b.onclick = () => promoteModal(a); foot.push(b); }
    if (hasPerm('associates.remove')) { const b = el('button', 'obtn obtn-danger', 'Pašalinti'); b.onclick = () => confirmModal(`Pašalinti asocijuotą ${a.name}?`, async () => { const res = await call('removeAssociate', { citizenid: a.citizenid }); after(res, true); }); foot.push(b); }
    openDrawer(a.name, body, foot);
  }

  function promoteModal(a) {
    const b = el('div');
    b.append(el('p', null, `Paaukštinimas išsiųs pakvietimą — ${esc(a.name)} turi būti prisijungęs ir priimti.`));
    const f = field('Siūlomas rangas', selectEl(S.ranks.filter(r=>!r.isOwnerRank).sort((x,y)=>x.priority-y.priority).map(r=>({v:r.id,t:r.label}))));
    b.append(f.wrap);
    openModal('Paaukštinti į narį', b, [okBtn('Siųsti pasiūlymą', async () => { const res = await call('promoteAssociate', { citizenid: a.citizenid, rankId: Number(f.wrap.querySelector('select').value) }); closeModal(); after(res, true); })]);
  }

  // ═══ RELATIONS ═══
  function viewRelations() {
    elSub.textContent = 'Diplomatija su kitomis gaujomis';
    const d = S.diplomacy || { relations: [], incomingOffers: [] };
    if (hasPerm('diplomacy.send_offer') || hasPerm('diplomacy.set_hostile') || hasPerm('diplomacy.set_neutral')) {
      const b = el('button', 'obtn obtn-primary sm', '＋ Naujas santykis'); b.onclick = openRelationForm; setTools([b]);
    }
    if (d.incomingOffers && d.incomingOffers.length) {
      elContent.append(el('div', 'org-section-title', 'Neatsakyti pasiūlymai'));
      const grid = el('div', 'org-cards');
      d.incomingOffers.forEach(o => {
        const rt = (S.catalog.relationTypes.find(t => t.id === o.relation_type) || {}).label || o.relation_type;
        const card = el('div', 'org-card'); card.style.cursor = 'default';
        card.innerHTML = `<div class="org-card-head"><div class="org-avatar" style="background:${o.from_color||'#334155'}">${initials(o.from_label||o.from_name)}</div><div class="org-card-title"><strong>${esc(o.from_label||o.from_name)}</strong><span>siūlo: ${esc(rt)}</span></div></div>`;
        const rowB = el('div', 'org-invite-actions');
        if (hasPerm('diplomacy.accept_offer')) {
          const acc = el('button', 'obtn obtn-primary sm', 'Priimti'); acc.onclick = async () => { const r = await call('acceptRelation', { fromGangId: o.from_gang_id }); after(r, true); };
          const dec = el('button', 'obtn obtn-danger sm', 'Atmesti'); dec.onclick = async () => { const r = await call('declineRelation', { fromGangId: o.from_gang_id }); after(r, true); };
          rowB.append(acc, dec);
        }
        card.append(rowB); grid.append(card);
      });
      elContent.append(grid);
    }
    elContent.append(el('div', 'org-section-title', 'Santykiai'));
    const grid = el('div', 'org-cards');
    if (!d.relations || !d.relations.length) grid.append(el('div', 'org-empty', 'Santykių nėra.'));
    (d.relations || []).forEach(r => {
      const rt = (S.catalog.relationTypes.find(t => t.id === r.relation_type) || {}).label || r.relation_type;
      const card = el('div', 'org-card'); card.style.cursor = 'default';
      card.innerHTML = `<div class="org-card-head"><div class="org-avatar" style="background:${r.target_color||'#334155'}">${initials(r.target_label||r.target_name)}</div><div class="org-card-title"><strong>${esc(r.target_label||r.target_name)}</strong><span>${esc(rt)} · ${r.status==='pending'?'laukiama':'aktyvu'}</span></div></div>`;
      const chips = el('div', 'org-chiprow');
      chips.append(el('span', 'chip', 'Nuo: ' + fmtDate(r.created_at)));
      if (r.note) chips.append(el('span', 'chip', esc(r.note)));
      card.append(chips);
      if (hasPerm('diplomacy.break')) { const foot = el('div','org-invite-actions'); const b = el('button', 'obtn obtn-danger sm', 'Nutraukti'); b.onclick = () => confirmModal(`Nutraukti santykį su ${r.target_label||r.target_name}?`, async () => { const res = await call('breakRelation', { targetGangId: r.target_gang_id }); after(res, true); }); foot.append(b); card.append(foot); }
      grid.append(card);
    });
    elContent.append(grid);
  }

  function openRelationForm() {
    const body = el('div');
    const fGang = field('Kita gauja', selectEl((S.otherGangs||[]).map(g => ({ v: g.id, t: g.label || g.name }))));
    const types = (S.catalog.relationTypes || []).filter(t => !t.restricted);
    const fType = field('Santykio tipas', selectEl(types.map(t => ({ v: t.id, t: t.label }))));
    const fNote = field('Pastaba (nebūtina)', inputEl('', 'text'));
    body.append(fGang.wrap, fType.wrap, fNote.wrap);
    body.append(el('p', null, '<span class="small" style="color:var(--org-muted);font-size:12px">Draugystei ir sąjungai reikia kitos gaujos sutikimo. Priešiškumas — vienašalis.</span>'));
    openDrawer('Naujas santykis', body, [okBtn('Nustatyti', async () => {
      const res = await call('setRelation', { targetGangId: Number(fGang.wrap.querySelector('select').value), relationType: fType.wrap.querySelector('select').value, note: fNote.input.value }); after(res, true);
    })]);
  }

  // ═══ LOGS ═══
  async function viewLogs() {
    elSub.textContent = 'Veiklos žurnalas';
    const search = el('input', 'oinput osearch'); search.placeholder = 'Ieškoti (vardas / ID)…'; search.value = logState.search;
    const actSel = el('select', 'oselect'); actSel.style.maxWidth = '200px';
    actSel.innerHTML = '<option value="all">Visi veiksmai</option>' + Object.keys(LOG_ACTIONS).map(k => `<option value="${k}" ${logState.action===k?'selected':''}>${LOG_ACTIONS[k]}</option>`).join('');
    const go = () => { logState.search = search.value; logState.action = actSel.value; logState.page = 1; loadLogs(); };
    search.onkeydown = e => { if (e.key === 'Enter') go(); };
    actSel.onchange = go;
    setTools([search, actSel]);
    const holder = el('div'); holder.id = 'orgLogHolder'; elContent.append(holder);
    loadLogs();
  }
  async function loadLogs() {
    const res = await call('getLogs', { page: logState.page, action: logState.action, search: logState.search });
    const holder = document.getElementById('orgLogHolder'); if (!holder) return;
    holder.innerHTML = '';
    if (!res || !res.ok) { holder.append(el('div', 'org-empty', (res && res.msg) || 'Klaida.')); return; }
    if (!res.logs.length) { holder.append(el('div', 'org-empty', 'Įrašų nėra.')); return; }
    const tbl = el('table', 'org-table');
    tbl.innerHTML = '<thead><tr><th>Laikas</th><th>Veiksmas</th><th>Atlikėjas</th><th>Objektas</th><th>Detalės</th></tr></thead>';
    const tb = el('tbody');
    res.logs.forEach(l => {
      const tr = el('tr');
      const detail = [l.old_value ? 'Iš: ' + l.old_value : '', l.new_value ? 'Į: ' + l.new_value : ''].filter(Boolean).join(' · ');
      tr.innerHTML = `<td>${fmtDate(l.created_at)}</td><td>${esc(LOG_ACTIONS[l.action] || l.action)}</td><td>${esc(l.actor_name || '—')}${l.actor_rank?` <span class="chip">${esc(l.actor_rank)}</span>`:''}</td><td>${esc(l.target_id || '—')}</td><td style="color:var(--org-muted)">${esc(detail).slice(0,120)}</td>`;
      tb.append(tr);
    });
    tbl.append(tb); holder.append(tbl);
    const pages = Math.max(1, Math.ceil(res.total / res.perPage));
    const pager = el('div', 'org-pager');
    const prev = el('button', 'obtn sm', '‹ Ankstesnis'); prev.disabled = logState.page <= 1; prev.onclick = () => { logState.page--; loadLogs(); };
    const next = el('button', 'obtn sm', 'Kitas ›'); next.disabled = logState.page >= pages; next.onclick = () => { logState.page++; loadLogs(); };
    pager.append(prev, el('span', null, `${logState.page} / ${pages} · ${res.total} įrašų`), next);
    holder.append(pager);
  }

  // ═══ SETTINGS ═══
  function viewSettings() {
    elSub.textContent = 'Gaujos nustatymai';
    const g = S.gang;
    const wrap = el('div'); wrap.style.maxWidth = '560px';
    const fLabel = field('Rodomas pavadinimas', inputEl(g.label || g.name, 'text'));
    const fEmblem = field('Emblema (tekstas/nuoroda)', inputEl(g.emblem || '', 'text'));
    wrap.append(fLabel.wrap, fEmblem.wrap);
    // spalvos
    let c1 = g.color, c2 = g.secondaryColor;
    const mkSw = (label, cur, setFn) => {
      const f = el('div', 'ofield'); f.append(el('label', null, label)); const sw = el('div', 'swatches');
      PALETTE.forEach(hex => { const s = el('div', 'swatch' + (hex.toUpperCase()===String(cur).toUpperCase()?' sel':'')); s.style.background = hex; s.onclick = () => { setFn(hex); sw.querySelectorAll('.swatch').forEach(x=>x.classList.remove('sel')); s.classList.add('sel'); }; sw.append(s); });
      f.append(sw); return f;
    };
    wrap.append(mkSw('Pagrindinė spalva', c1, h => c1 = h), mkSw('Antrinė spalva', c2, h => c2 = h));
    const save = el('button', 'obtn obtn-primary', 'Išsaugoti'); save.disabled = !hasPerm('gang.edit_info');
    save.onclick = async () => { const res = await call('saveSettings', { label: fLabel.input.value, emblem: fEmblem.input.value, color: c1, secondaryColor: c2 }); after(res); };
    wrap.append(save);
    if (S.me.isOwner) {
      wrap.append(el('div', 'org-section-title', 'Pavojinga zona'));
      const f = field('Perduoti nuosavybę nariui', selectEl(S.members.filter(m=>!m.isOwner).map(m=>({v:m.citizenid,t:m.name}))));
      const tb = el('button', 'obtn obtn-danger', 'Perduoti nuosavybę');
      tb.onclick = () => { const cid = f.wrap.querySelector('select').value; if (!cid) return toast('Pasirink narį.', false); const nm = (S.members.find(m=>m.citizenid===cid)||{}).name; confirmModal(`Perduoti nuosavybę nariui ${nm}? Negrįžtama.`, async () => { const res = await call('transferOwnership', { citizenid: cid, confirm: true }); after(res, true); }); };
      wrap.append(f.wrap, tb);
    }
    elContent.append(wrap);
  }

  // ═══ Invite form (send) ═══
  function openInviteForm() {
    const body = el('div');
    const fId = field('Žaidėjo server ID', inputEl('', 'number'));
    const fRank = field('Siūlomas rangas', selectEl(S.ranks.filter(r=>!r.isOwnerRank).sort((a,b)=>a.priority-b.priority).map(r=>({v:r.id,t:r.label}))));
    body.append(fId.wrap, fRank.wrap);
    openDrawer('Pakviesti narį', body, [okBtn('Siųsti pakvietimą', async () => {
      await post('org:invitePlayer', { targetServerId: Number(fId.input.value), rankId: Number(fRank.wrap.querySelector('select').value) });
      toast('Pakvietimas išsiųstas.'); closeDrawer();
    })]);
  }

  // ═══ Invite prompt (receive) ═══
  function showInvitePrompt(p) {
    clearInterval(inviteTimer);
    elInvite.classList.remove('hidden');
    let sec = Math.max(5, Number(p.expirySec) || 60);
    const card = el('div', 'org-invite-card');
    const em = el('div', 'ic-emblem'); em.style.background = 'linear-gradient(135deg,#e11d48,#7c3aed)'; em.textContent = initials(p.gangName); card.append(em);
    card.append(el('h2', null, esc(p.gangName || 'Gauja')));
    card.append(el('p', null, `${esc(p.fromName || 'Narys')} kviečia tave prisijungti`));
    card.append(el('p', 'ic-rank', 'Rangas: ' + esc(p.rankLabel || '—')));
    const timer = el('div', 'org-invite-timer', `Galioja: ${sec}s`);
    const actions = el('div', 'org-invite-actions');
    const acc = el('button', 'obtn obtn-primary', 'Priimti'); acc.onclick = () => respondInvite(true);
    const dec = el('button', 'obtn obtn-danger', 'Atmesti'); dec.onclick = () => respondInvite(false);
    actions.append(dec, acc);
    card.append(timer, actions);
    elInvite.innerHTML = ''; elInvite.append(card);
    inviteTimer = setInterval(() => { sec--; timer.textContent = `Galioja: ${sec}s`; if (sec <= 0) { clearInterval(inviteTimer); hideInvitePrompt(); } }, 1000);
  }
  function hideInvitePrompt() { clearInterval(inviteTimer); elInvite.classList.add('hidden'); elInvite.innerHTML = ''; }
  function respondInvite(accept) { post('org:respondInvite', { accept: !!accept }); hideInvitePrompt(); }

  // ── Drawer / modal / form helpers ──
  function openDrawer(title, body, footNodes) {
    elDrawer.innerHTML = '';
    const head = el('div', 'org-drawer-head'); head.append(el('h2', null, esc(title))); const x = el('button', 'xclose', '✕'); x.onclick = closeDrawer; head.append(x);
    const b = el('div', 'org-drawer-body'); b.append(body);
    elDrawer.append(head, b);
    if (footNodes && footNodes.length) { const f = el('div', 'org-drawer-foot'); footNodes.forEach(n => f.append(n)); elDrawer.append(f); }
    elDrawer.classList.remove('hidden'); elDrawerBg.classList.remove('hidden');
    elDrawerBg.onclick = closeDrawer;
  }
  function closeDrawer() { elDrawer.classList.add('hidden'); elDrawerBg.classList.add('hidden'); }
  function openModal(title, body, footNodes) {
    elModal.innerHTML = '';
    const m = el('div', 'org-modal');
    m.append(el('div', 'org-modal-head', esc(title)));
    const b = el('div', 'org-modal-body'); b.append(body); m.append(b);
    const f = el('div', 'org-modal-foot'); const cancel = el('button', 'obtn obtn-ghost', 'Atšaukti'); cancel.onclick = closeModal; f.append(cancel); (footNodes||[]).forEach(n => f.append(n)); m.append(f);
    elModal.append(m); elModal.classList.remove('hidden');
    elModal.onclick = e => { if (e.target === elModal) closeModal(); };
  }
  function closeModal() { elModal.classList.add('hidden'); elModal.innerHTML = ''; }
  function confirmModal(text, onYes) { const b = el('div'); b.append(el('p', null, esc(text))); openModal('Patvirtinti', b, [okBtn('Taip', onYes)]); }

  function okBtn(label, fn) { const b = el('button', 'obtn obtn-primary', label); b.onclick = fn; return b; }
  function field(label, control) { const wrap = el('div', 'ofield'); wrap.append(el('label', null, label), control); return { wrap, input: control }; }
  function inputEl(val, type) { const i = el('input', 'oinput'); i.type = type || 'text'; i.value = val == null ? '' : val; return i; }
  function textEl(val) { const t = el('textarea', 'otext'); t.value = val || ''; return t; }
  function selectEl(opts, sel) { const s = el('select', 'oselect'); s.innerHTML = opts.map(o => `<option value="${esc(o.v)}" ${String(o.v)===String(sel)?'selected':''}>${esc(o.t)}</option>`).join(''); return s; }
  function row(k, v) { return `<div class="dl-row"><span>${esc(k)}</span><strong>${esc(v)}</strong></div>`; }

  // after action: toast + refresh; closeDrawer/closeModal if requested
  function after(res, closeUi) {
    if (!res) return;
    toast(res.msg || (res.ok ? 'Atlikta.' : 'Klaida.'), res.ok);
    if (res.ok) { if (closeUi) { closeDrawer(); closeModal(); } refresh(); }
  }

  // ── Keyboard (ESC) ──
  window.addEventListener('keydown', e => {
    if (e.key !== 'Escape') return;
    if (!elInvite.classList.contains('hidden')) { respondInvite(false); return; }
    if (!elModal.classList.contains('hidden')) { closeModal(); return; }
    if (!elDrawer.classList.contains('hidden')) { closeDrawer(); return; }
    if (!root.classList.contains('hidden')) closeMenu();
  });

  // ── Message bus ──
  window.addEventListener('message', e => {
    const d = e.data || {};
    if (d.action === 'orgOpen') openMenu();
    else if (d.action === 'orgClose') { root.classList.add('hidden'); hideInvitePrompt(); }
    else if (d.action === 'orgRefresh') { if (!root.classList.contains('hidden')) refresh(); }
    else if (d.action === 'orgInvite') showInvitePrompt(d.payload || {});
  });
})();
