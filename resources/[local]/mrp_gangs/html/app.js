const tablet = document.querySelector('#tablet');
const nav = document.querySelector('#nav');
const content = document.querySelector('#content');
const title = document.querySelector('#page-title');
const identity = document.querySelector('#identity');
const modalRoot = document.querySelector('#modal-root');
const toastRoot = document.querySelector('#toast-root');

const state = {
  payload: null,
  page: 'overview',
  missionDifficulty: {},
  map: null,
  mapLayer: null,
};

const pages = [
  ['overview', '⌂', 'Overview'],
  ['members', '♟', 'Nariai'],
  ['progression', '↗', 'Progresija'],
  ['territories', '◇', 'Teritorijos'],
  ['missions', '◎', 'Misijos'],
  ['diplomacy', '⇄', 'Diplomatija'],
  ['wars', '⚔', 'Karai'],
  ['activity', '≡', 'Veikla'],
];

const esc = (value) => String(value ?? '')
  .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;').replaceAll("'", '&#039;');
const money = (value) => `$${Number(value || 0).toLocaleString('en-US')}`;
const date = (value) => value ? new Date(value).toLocaleString('lt-LT') : '—';
const hasPermission = (permission) => {
  const permissions = state.payload?.organization?.permissions;
  return permissions === '*' || (Array.isArray(permissions) && permissions.includes(permission));
};

async function api(name, data = {}) {
  const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  });
  return response.json();
}

function toast(message, type = '') {
  const node = document.createElement('div');
  node.className = `toast ${type}`;
  node.textContent = message;
  toastRoot.append(node);
  setTimeout(() => node.remove(), 4200);
}

function pill(text, tone = '') {
  return `<span class="pill ${tone}">${esc(text)}</span>`;
}

function empty(message) {
  return `<div class="empty"><div><strong>Duomenų nėra</strong><p>${esc(message)}</p></div></div>`;
}

function renderNav() {
  const organization = state.payload?.organization;
  const available = organization ? pages : [['overview', '⌂', 'Kvietimai']];
  if (state.payload?.admin) available.push(['admin', '⚙', 'Administravimas']);
  if (!available.some(([key]) => key === state.page)) state.page = available[0][0];
  nav.innerHTML = available.map(([key, icon, label]) => `
    <button class="nav-button ${state.page === key ? 'is-active' : ''}" data-page="${key}">
      <span class="nav-icon">${icon}</span><span>${label}</span>
      ${key === 'wars' && state.payload?.wars?.length ? `<span class="nav-badge">${state.payload.wars.length}</span>` : ''}
    </button>
  `).join('');
  const gang = organization?.gang;
  identity.innerHTML = gang
    ? `<strong>${esc(gang.label)}</strong><span>${esc(gang.role_key)} · Lv. ${esc(gang.level)}</span>`
    : `<strong>Neprisijungęs</strong><span>Peržiūrėk kvietimus</span>`;
}

function metric(label, value, tone = '') {
  return `<article class="card ${tone}"><div class="metric">${esc(value)}</div><div class="metric-label">${esc(label)}</div></article>`;
}

function renderOverview() {
  const org = state.payload.organization;
  if (!org) {
    const invites = state.payload.invites || [];
    return `<div class="stack">
      <div class="card is-accent"><h2>Gaujos tinklas</h2><p>Šiuo metu nepriklausai gaujai. Priimk galiojantį kvietimą.</p></div>
      <div class="list">${invites.length ? invites.map(invite => `
        <div class="list-item"><div class="list-item-main"><strong>${esc(invite.gang_label)}</strong>
        <small>${esc(invite.gang_type)} · ${esc(invite.role_key)} · iki ${date(invite.expires_at)}</small></div>
        <button class="button primary" data-action="accept-invite" data-id="${invite.id}">Priimti</button></div>
      `).join('') : empty('Aktyvių kvietimų nėra.')}</div>
    </div>`;
  }
  const gang = org.gang;
  const controlled = (state.payload.territories || []).filter(t => Number(t.ownerGangId) === Number(gang.gang_id));
  const activeWars = (state.payload.wars || []).filter(w => ['preparation','active','settlement'].includes(w.state));
  const progression = state.payload.progression;
  const progress = progression.nextRequired
    ? Math.min(100, Math.round((progression.reputation / progression.nextRequired) * 100)) : 100;
  return `<div class="stack">
    <div class="grid grid-4">
      ${metric('Reputacija', Number(gang.reputation || 0).toLocaleString())}
      ${metric('Iždas', money(gang.treasury))}
      ${metric('Teritorijos', controlled.length)}
      ${metric('Aktyvūs karai', activeWars.length)}
    </div>
    <div class="grid grid-2">
      <article class="card is-accent"><div class="card-header"><div><h2>${esc(gang.label)}</h2>
        <p>${esc(gang.gang_type)} · Level ${esc(progression.level)}</p></div>${pill(gang.member_status, 'success')}</div>
        <div class="progress"><span style="width:${progress}%"></span></div>
        <p class="muted" style="margin:9px 0 0">${progression.nextRequired ? `${progression.reputation} / ${progression.nextRequired} REP` : 'Maksimalus dabartinis lygis'}</p>
      </article>
      <article class="card"><div class="card-header"><h2>Greiti veiksmai</h2></div>
        <div class="button-row">
          <button class="button primary" data-page="missions">Mission Board</button>
          <button class="button" data-page="territories">Žemėlapis</button>
          <button class="button" data-page="members">Struktūra</button>
        </div>
      </article>
    </div>
    <article class="card"><div class="card-header"><h2>Kontroliuojamos teritorijos</h2>${pill(`${controlled.length}`)}</div>
      <div class="list">${controlled.length ? controlled.map(t => `
        <div class="list-item"><div class="list-item-main"><strong>${esc(t.label)}</strong>
        <small>${esc(t.type)} · stabilumas ${esc(t.stability)}%</small></div>${pill(t.state, t.state === 'controlled' ? 'success' : 'warning')}</div>
      `).join('') : empty('Kol kas teritorijų nekontroliuojate.')}</div>
    </article>
  </div>`;
}

function renderMembers() {
  const org = state.payload.organization;
  const canInvite = hasPermission('members.invite');
  const canManage = hasPermission('members.set_role');
  return `<div class="stack">
    <div class="card-header"><div><h2>Organizacijos struktūra</h2><p class="muted">${org.members.length} / 60 narių</p></div>
      ${canInvite ? '<button class="button primary" data-action="invite-modal">Pakviesti narį</button>' : ''}</div>
    <div class="table-wrap"><table><thead><tr><th>Narys</th><th>Rangas</th><th>Statusas</th><th>Indėlis</th><th>Prisijungė</th><th></th></tr></thead>
      <tbody>${org.members.map(member => `<tr><td><strong>${esc(member.display_name)}</strong><br><span class="muted">${esc(member.citizenid)}</span></td>
        <td>${esc(member.role_key)}</td><td>${pill(member.status, member.status === 'active' ? 'success' : 'warning')}</td>
        <td>${Number(member.contribution || 0).toLocaleString()}</td><td>${date(member.joined_at)}</td>
        <td><div class="button-row">${canManage ? `<button class="button" data-action="role-modal" data-citizen="${esc(member.citizenid)}">Rangas</button>` : ''}
        ${hasPermission('members.kick') ? `<button class="button danger" data-action="kick-member" data-citizen="${esc(member.citizenid)}">Pašalinti</button>` : ''}</div></td></tr>`).join('')}</tbody>
    </table></div>
    ${hasPermission('finance.view') ? `<article class="card"><div class="card-header"><h2>Iždas</h2><span class="metric">${money(org.gang.treasury)}</span></div>
      <div class="button-row">${hasPermission('finance.deposit') ? '<button class="button" data-action="treasury-modal" data-operation="deposit">Įnešti</button>' : ''}
      ${hasPermission('finance.withdraw') ? '<button class="button" data-action="treasury-modal" data-operation="withdraw">Išimti</button>' : ''}</div></article>` : ''}
    ${hasPermission('roles.manage') ? `<article class="card"><div class="card-header"><h2>Rangai ir teisės</h2><button class="button primary" data-action="role-config-modal">Naujas rangas</button></div>
      <div class="grid grid-3">${org.roles.map(role => `<div class="list-item"><div class="list-item-main"><strong>${esc(role.label)}</strong>
      <small>${esc(role.role_key)} · priority ${esc(role.priority)}</small></div><button class="button" data-action="role-config-modal" data-role-key="${esc(role.role_key)}">Redaguoti</button></div>`).join('')}</div></article>` : ''}
  </div>`;
}

function renderProgression() {
  const progression = state.payload.progression;
  return `<div class="stack"><article class="card is-accent"><h2>Ilgalaikė progresija</h2>
    <div class="metric">Level ${esc(progression.level)}</div><p>${Number(progression.reputation).toLocaleString()} reputacijos</p></article>
    <div class="grid grid-3">${progression.levels.map(level => `<article class="card">
      <div class="card-header"><h3>Level ${level.level}</h3>${pill(progression.reputation >= level.required ? 'Atrakinta' : `${level.required} REP`, progression.reputation >= level.required ? 'success' : '')}</div>
      <p>${esc(level.unlock)}</p></article>`).join('')}</div></div>`;
}

function renderTerritories() {
  setTimeout(initMap, 0);
  return `<div class="stack"><div class="map-legend">
    <span><i class="legend-dot" style="background:#22c55e"></i>Gang Turf</span>
    <span><i class="legend-dot" style="background:#ef4444"></i>PvP Turf</span>
    <span><i class="legend-dot" style="background:#f59e0b"></i>Reketo Turf</span></div>
    <div id="territory-map"></div></div>`;
}

function initMap() {
  const node = document.querySelector('#territory-map');
  if (!node || typeof L === 'undefined') return;
  if (state.map) { state.map.remove(); state.map = null; }
  const bounds = [[-4000, -4000], [6625, 4500]];
  state.map = L.map(node, { crs: L.CRS.Simple, minZoom: -3, maxZoom: 1, zoomControl: true, attributionControl: false });
  L.imageOverlay('asset/gtav_satellite_2048.png', bounds).addTo(state.map);
  state.map.fitBounds([[-2500, -2000], [5200, 3000]]);
  (state.payload.territories || []).forEach(territory => {
    const fallback = territory.type === 'gang' ? '#22c55e' : territory.type === 'pvp' ? '#ef4444' : '#f59e0b';
    const color = territory.ownerColor || fallback;
    const polygon = L.polygon(territory.vertices.map(v => [v.y, v.x]), {
      color, fillColor: color, fillOpacity: territory.ownerGangId ? .27 : .10, weight: 2,
    }).addTo(state.map);
    polygon.bindPopup(`<strong>${esc(territory.label)}</strong><br>${esc(territory.type)}<br>
      Savininkas: ${esc(territory.ownerLabel || 'Neutralu')}<br>Stabilumas: ${esc(territory.stability)}%`);
  });
}

function renderMissions() {
  const board = state.payload.missions || {};
  return `<div class="stack"><div class="card-header"><div><h2>Mission Board</h2><p class="muted">Misijos nekeičia turf kontrolės.</p></div>
    <button class="button" data-action="ready-modal">Party pasiruošimas</button></div>
    <div class="grid grid-3">${(board.missions || []).map(mission => {
      const selected = state.missionDifficulty[mission.id] || mission.difficulties[0];
      return `<article class="card mission-card"><div class="card-header"><div><h3>${esc(mission.label)}</h3>
        ${pill(mission.category, mission.category === 'universal' ? 'info' : '')}</div>${mission.hasInterior ? pill('Interior') : ''}</div>
        <p>${esc(mission.description)}</p><div class="mission-meta">${pill(`Base ${money(mission.baseReward)}`)}${pill(`REP ${mission.baseReputation}`)}</div>
        <select data-mission-difficulty="${esc(mission.id)}">${mission.difficulties.map(key =>
          `<option value="${esc(key)}" ${key === selected ? 'selected' : ''}>${esc(board.difficulties[key]?.label || key)} ×${board.difficulties[key]?.rewardMultiplier || 1}</option>`
        ).join('')}</select>
        <button class="button primary" data-action="start-mission" data-mission="${esc(mission.id)}">Pradėti</button></article>`;
    }).join('')}</div></div>`;
}

function renderDiplomacy() {
  const rows = state.payload.diplomacy || [];
  return `<div class="stack"><div class="card-header"><div><h2>Diplomatija</h2><p class="muted">Sutartys turi realų karo ir ekonominį poveikį.</p></div>
    ${hasPermission('diplomacy.propose') ? '<button class="button primary" data-action="treaty-modal">Nauja sutartis</button>' : ''}</div>
    <div class="list">${rows.length ? rows.map(row => {
      const ownId = Number(state.payload.organization.gang.gang_id);
      const other = Number(row.gang_a_id) === ownId ? row.gang_b_label : row.gang_a_label;
      const incoming = row.status === 'pending' && Number(row.proposed_by_gang_id) !== ownId;
      return `<div class="list-item"><div class="list-item-main"><strong>${esc(other)}</strong>
        <small>${esc(row.treaty_type)} · ${esc(row.status)} · iki ${date(row.expires_at)}</small></div>
        <div class="button-row">${incoming && hasPermission('diplomacy.accept') ? `<button class="button primary" data-action="resolve-treaty" data-id="${row.id}" data-accept="true">Priimti</button>
        <button class="button" data-action="resolve-treaty" data-id="${row.id}" data-accept="false">Atmesti</button>` : ''}
        ${row.status === 'active' && hasPermission('diplomacy.break') ? `<button class="button danger" data-action="break-treaty" data-id="${row.id}">Nutraukti</button>` : ''}</div></div>`;
    }).join('') : empty('Aktyvių santykių nėra.')}</div></div>`;
}

function renderWars() {
  const wars = state.payload.wars || [];
  return `<div class="stack"><div class="card-header"><div><h2>Karo kampanijos</h2><p class="muted">Objective score, roster lock ir gynėjo pranašumas.</p></div>
    ${hasPermission('wars.declare') ? '<button class="button primary" data-action="war-modal">Skelbti karą</button>' : ''}</div>
    <div class="grid grid-2">${wars.length ? wars.map(war => `<article class="card ${war.state === 'active' ? 'is-accent' : ''}">
      <div class="card-header"><div><h3>${esc(war.attacker_label)} vs ${esc(war.defender_label)}</h3><p>${esc(war.territory_id)}</p></div>${pill(war.state, war.state === 'active' ? 'danger' : 'warning')}</div>
      <div class="grid grid-2">${metric('Puolėjai', war.attacker_score)}${metric('Gynėjai', war.defender_score)}</div>
      <p class="muted">Aktyvus: ${date(war.active_starts_at)} — ${date(war.active_ends_at)}</p>
      <button class="button" data-action="war-details" data-id="${war.id}">Detaliau</button></article>`).join('') : empty('Karo kampanijų nėra.')}</div></div>`;
}

function renderActivity() {
  const rows = state.payload.activity || [];
  return `<div class="stack"><h2>Veiklos žurnalas</h2><div class="table-wrap"><table>
    <thead><tr><th>Laikas</th><th>Veiksmas</th><th>Aktorius</th><th>Taikinys</th></tr></thead>
    <tbody>${rows.map(row => `<tr><td>${date(row.created_at)}</td><td>${esc(row.action)}</td>
      <td>${esc(row.actor_citizenid || 'Sistema')}</td><td>${esc(row.target_type || '')} ${esc(row.target_id || '')}</td></tr>`).join('')}</tbody>
  </table></div></div>`;
}

function renderAdmin() {
  const admin = state.payload.admin;
  return `<div class="stack"><div class="grid grid-4">
    ${metric('Gaujos', admin.gangs.length)}${metric('Aktyvūs karai', admin.activeWars.length)}
    ${metric('Quota kategorijos', admin.quotas.length)}${metric('Audit įrašai', admin.recentAudit.length)}</div>
    <article class="card"><h2>Gaujų valdymas</h2><div class="table-wrap"><table><thead><tr><th>ID</th><th>Gauja</th><th>Tipas</th><th>REP</th><th>Iždas</th><th>Statusas</th></tr></thead>
      <tbody>${admin.gangs.map(g => `<tr><td>${g.id}</td><td>${esc(g.label)}</td><td>${esc(g.gang_type)}</td>
      <td>${g.reputation}</td><td>${money(g.treasury)}</td><td><select data-admin-gang-status="${g.id}">
      ${['active','suspended','archived'].map(s => `<option ${s === g.status ? 'selected' : ''}>${s}</option>`).join('')}</select></td></tr>`).join('')}</tbody></table></div></article>
    <article class="card"><h2>Supply quota</h2><div class="table-wrap"><table><thead><tr><th>Raktas</th><th>Išduota</th><th>Limitas</th><th>Langas</th></tr></thead>
      <tbody>${admin.quotas.map(q => `<tr><td>${esc(q.quota_key)}</td><td>${q.issued_count}</td><td>${q.global_cap}</td><td>${q.window_days} d.</td></tr>`).join('')}</tbody></table></div></article>
    <article class="card"><h2>Teritorijų kontrolė</h2><div class="table-wrap"><table><thead><tr><th>Teritorija</th><th>Tipas</th><th>Savininkas</th><th>Stabilumas</th></tr></thead>
      <tbody>${(state.payload.territories || []).map(t => `<tr><td>${esc(t.label)}</td><td>${esc(t.type)}</td>
      <td><select data-admin-territory-owner="${esc(t.id)}"><option value="">Neutralu</option>${admin.gangs.filter(g => g.status === 'active').map(g =>
        `<option value="${g.id}" ${Number(g.id) === Number(t.ownerGangId) ? 'selected' : ''}>${esc(g.label)}</option>`).join('')}</select></td>
      <td>${esc(t.stability)}%</td></tr>`).join('')}</tbody></table></div></article>
    <article class="card"><h2>Aktyvūs karai</h2><div class="list">${admin.activeWars.map(w => `<div class="list-item"><div class="list-item-main">
      <strong>#${w.id} · ${esc(w.territory_id)}</strong><small>${esc(w.state)} · ${w.attacker_score}:${w.defender_score}</small></div>
      <button class="button danger" data-action="admin-cancel-war" data-id="${w.id}">Atšaukti</button></div>`).join('') || empty('Aktyvių karų nėra.')}</div></article>
    <article class="card"><h2>Mission toggles</h2><div class="grid grid-3">${(admin.missions || []).map(m =>
      `<label class="list-item"><span>${esc(m.label)}</span><input type="checkbox" data-admin-mission="${esc(m.id)}" ${m.enabled ? 'checked' : ''}></label>`).join('')}</div></article>
  </div>`;
}

function render() {
  if (!state.payload) return;
  renderNav();
  const pageTitle = pages.find(([key]) => key === state.page)?.[2] || (state.page === 'admin' ? 'Administravimas' : 'Overview');
  title.textContent = pageTitle;
  const renderers = {
    overview: renderOverview, members: renderMembers, progression: renderProgression,
    territories: renderTerritories, missions: renderMissions, diplomacy: renderDiplomacy,
    wars: renderWars, activity: renderActivity, admin: renderAdmin,
  };
  content.innerHTML = (renderers[state.page] || renderOverview)();
}

function modal(html) {
  modalRoot.innerHTML = `<div class="modal-backdrop" data-action="dismiss-modal"><div class="modal" role="dialog">${html}</div></div>`;
}
function closeModal() { modalRoot.innerHTML = ''; }

function inviteModal() {
  const roles = state.payload.organization.roles || [];
  modal(`<div class="modal-header"><h2>Pakviesti narį</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
    <form id="invite-form" class="stack"><div class="field"><label>Server ID</label><input name="targetSource" type="number" min="1" required></div>
    <div class="field"><label>Pradinis rangas</label><select name="roleKey">${roles.map(r => `<option value="${esc(r.role_key)}">${esc(r.label)}</option>`).join('')}</select></div>
    <button class="button primary">Siųsti kvietimą</button></form>`);
}
function roleModal(citizenid) {
  const roles = state.payload.organization.roles || [];
  modal(`<div class="modal-header"><h2>Keisti rangą</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
    <form id="role-form" class="stack"><input type="hidden" name="citizenid" value="${esc(citizenid)}">
    <div class="field"><label>Rangas</label><select name="roleKey">${roles.map(r => `<option value="${esc(r.role_key)}">${esc(r.label)}</option>`).join('')}</select></div>
    <button class="button primary">Išsaugoti</button></form>`);
}
function roleConfigModal(roleKey = '') {
  const role = (state.payload.organization.roles || []).find(entry => entry.role_key === roleKey);
  const selected = role?.permissions?.wildcard ? new Set(['*']) : new Set(Object.keys(role?.permissions?.set || {}).filter(key => role.permissions.set[key]));
  const groups = state.payload.permissionGroups || {};
  modal(`<div class="modal-header"><h2>${role ? 'Redaguoti rangą' : 'Naujas rangas'}</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
    <form id="role-config-form" class="stack"><div class="grid grid-2">
    <div class="field"><label>Raktas</label><input name="roleKey" value="${esc(role?.role_key || '')}" ${role ? 'readonly' : ''} required></div>
    <div class="field"><label>Pavadinimas</label><input name="label" value="${esc(role?.label || '')}" required></div></div>
    <div class="field"><label>Prioritetas</label><input name="priority" type="number" min="0" max="99" value="${esc(role?.priority || 10)}" required></div>
    <div class="stack">${Object.entries(groups).map(([groupKey, group]) => `<div class="card"><h3>${esc(group.label || groupKey)}</h3>
      <div class="grid grid-2">${(group.permissions || []).map(permission => `<label class="list-item"><span>${esc(permission)}</span>
      <input type="checkbox" name="permission" value="${esc(permission)}" ${selected.has(permission) || selected.has('*') ? 'checked' : ''}></label>`).join('')}</div></div>`).join('')}</div>
    <div class="button-row"><button class="button primary">Išsaugoti</button>
    ${role && !['boss','underboss','lieutenant','member','prospect'].includes(role.role_key) ? `<button type="button" class="button danger" data-action="delete-role" data-role-key="${esc(role.role_key)}">Pašalinti</button>` : ''}</div></form>`);
}
function treasuryModal(operation) {
  modal(`<div class="modal-header"><h2>${operation === 'deposit' ? 'Įnešti į iždą' : 'Išimti iš iždo'}</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
    <form id="treasury-form" class="stack"><input type="hidden" name="operation" value="${esc(operation)}">
    <div class="field"><label>Suma</label><input name="amount" type="number" min="1" max="1000000" required></div>
    <button class="button primary">Patvirtinti</button></form>`);
}
function readyModal() {
  modal(`<div class="modal-header"><h2>Party rolė</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
    <div class="grid grid-2">${Object.entries(state.payload.missionRoles || {}).filter(([key]) => key !== 'leader').map(([key, role]) =>
      `<button class="button" data-action="toggle-ready" data-role="${esc(key)}">${esc(role.label)}</button>`).join('')}</div>`);
}
function treatyModal() {
  const ownId = Number(state.payload.organization.gang.gang_id);
  modal(`<div class="modal-header"><h2>Nauja sutartis</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
    <form id="treaty-form" class="stack"><div class="field"><label>Kita gauja</label><select name="targetGangId">
    ${state.payload.gangs.filter(g => Number(g.id) !== ownId).map(g => `<option value="${g.id}">${esc(g.label)}</option>`).join('')}</select></div>
    <div class="field"><label>Tipas</label><select name="treatyType">${Object.entries(state.payload.treatyTypes || {}).map(([key, def]) =>
      `<option value="${esc(key)}">${esc(def.label)}</option>`).join('')}</select></div>
    <div class="field"><label>Trukmė valandomis</label><input name="durationHours" type="number" min="0" max="720" value="72"></div>
    <button class="button primary">Siūlyti</button></form>`);
}
function warModal() {
  const ownId = Number(state.payload.organization.gang.gang_id);
  const territories = (state.payload.territories || []).filter(t => t.ownerGangId && Number(t.ownerGangId) !== ownId && t.type !== 'racket');
  modal(`<div class="modal-header"><h2>Skelbti karą</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
    <form id="war-form" class="stack"><div class="field"><label>Teritorija ir gynėjas</label><select name="territory">
    ${territories.map(t => `<option value="${esc(t.id)}" data-owner="${t.ownerGangId}">${esc(t.label)} · ${esc(t.ownerLabel)}</option>`).join('')}</select></div>
    <p class="muted">Reikalingas aktyvus Enemy statusas. Roster užrakinamas pasibaigus pasiruošimui.</p>
    <button class="button primary">Skelbti kampaniją</button></form>`);
}

document.addEventListener('click', async (event) => {
  const target = event.target.closest('[data-page],[data-action]');
  if (!target) return;
  if (target.dataset.page) { state.page = target.dataset.page; render(); return; }
  const action = target.dataset.action;
  if (action === 'close') return api('close');
  if (action === 'refresh') return api('refresh');
  if (action === 'dismiss-modal') { if (event.target === target || target.classList.contains('close-button')) closeModal(); return; }
  if (action === 'invite-modal') return inviteModal();
  if (action === 'role-modal') return roleModal(target.dataset.citizen);
  if (action === 'role-config-modal') return roleConfigModal(target.dataset.roleKey || '');
  if (action === 'treasury-modal') return treasuryModal(target.dataset.operation);
  if (action === 'ready-modal') return readyModal();
  if (action === 'treaty-modal') return treatyModal();
  if (action === 'war-modal') return warModal();
  if (action === 'accept-invite') {
    const result = await api('acceptInvite', { inviteId: Number(target.dataset.id) }); toast(result.ok ? 'Kvietimas priimtas.' : result.reason, result.ok ? 'success' : 'error');
  } else if (action === 'kick-member') {
    const result = await api('kickMember', { citizenid: target.dataset.citizen }); toast(result.ok ? 'Narys pašalintas.' : result.reason, result.ok ? 'success' : 'error');
  } else if (action === 'delete-role') {
    const result = await api('deleteRole', { roleKey: target.dataset.roleKey }); toast(result.ok ? 'Rangas pašalintas.' : result.reason, result.ok ? 'success' : 'error');
    if (result.ok) closeModal();
  } else if (action === 'toggle-ready') {
    const result = await api('toggleMissionReady', { roleKey: target.dataset.role }); toast(result.ready ? 'Party būsena aktyvi.' : 'Party būsena išjungta.', result.ok ? 'success' : 'error'); closeModal();
  } else if (action === 'start-mission') {
    const difficulty = state.missionDifficulty[target.dataset.mission] || document.querySelector(`[data-mission-difficulty="${CSS.escape(target.dataset.mission)}"]`)?.value || 'easy';
    const result = await api('startMission', { missionKey: target.dataset.mission, difficulty }); toast(result.ok ? 'Operacija pradėta.' : (result.result || result.reason), result.ok ? 'success' : 'error');
  } else if (action === 'resolve-treaty') {
    const result = await api('resolveTreaty', { treatyId: Number(target.dataset.id), accept: target.dataset.accept === 'true' }); toast(result.ok ? 'Sutartis atnaujinta.' : result.reason, result.ok ? 'success' : 'error');
  } else if (action === 'break-treaty') {
    const result = await api('breakTreaty', { treatyId: Number(target.dataset.id) }); toast(result.ok ? 'Sutartis nutraukta.' : result.reason, result.ok ? 'success' : 'error');
  } else if (action === 'admin-cancel-war') {
    const result = await api('adminCancelWar', { warId: Number(target.dataset.id) }); toast(result.ok ? 'Karas atšauktas.' : result.reason, result.ok ? 'success' : 'error');
  } else if (action === 'war-details') {
    const result = await api('getWarDetails', { warId: Number(target.dataset.id) });
    modal(`<div class="modal-header"><h2>Karo #${target.dataset.id}</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
      <pre class="muted">${esc(JSON.stringify(result, null, 2))}</pre>`);
  }
});

document.addEventListener('change', async (event) => {
  if (event.target.matches('[data-mission-difficulty]')) state.missionDifficulty[event.target.dataset.missionDifficulty] = event.target.value;
  if (event.target.matches('[data-admin-gang-status]')) {
    const result = await api('adminSetGangStatus', { gangId: Number(event.target.dataset.adminGangStatus), status: event.target.value });
    toast(result.ok ? 'Statusas pakeistas.' : result.reason, result.ok ? 'success' : 'error');
  }
  if (event.target.matches('[data-admin-mission]')) {
    const result = await api('adminSetMissionState', { missionKey: event.target.dataset.adminMission, enabled: event.target.checked });
    toast(result.ok ? 'Misijos būsena pakeista.' : result.reason, result.ok ? 'success' : 'error');
  }
  if (event.target.matches('[data-admin-territory-owner]')) {
    const result = await api('adminSetTerritoryOwner', {
      territoryId: event.target.dataset.adminTerritoryOwner,
      gangId: event.target.value === '' ? null : Number(event.target.value),
    });
    toast(result.ok ? 'Teritorijos kontrolė pakeista.' : result.reason, result.ok ? 'success' : 'error');
  }
});

document.addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.target;
  const data = Object.fromEntries(new FormData(form).entries());
  let result;
  if (form.id === 'invite-form') result = await api('inviteMember', { targetSource: Number(data.targetSource), roleKey: data.roleKey });
  if (form.id === 'role-form') result = await api('setMemberRole', data);
  if (form.id === 'role-config-form') result = await api('saveRole', {
    roleKey: data.roleKey,
    label: data.label,
    priority: Number(data.priority),
    permissions: new FormData(form).getAll('permission'),
  });
  if (form.id === 'treasury-form') result = await api('treasury', { operation: data.operation, amount: Number(data.amount) });
  if (form.id === 'treaty-form') result = await api('proposeTreaty', { targetGangId: Number(data.targetGangId), treatyType: data.treatyType, durationHours: Number(data.durationHours), terms: {} });
  if (form.id === 'war-form') {
    const option = form.elements.territory.selectedOptions[0];
    result = await api('declareWar', { territoryId: option.value, defenderGangId: Number(option.dataset.owner) });
  }
  if (result) toast(result.ok ? 'Veiksmas atliktas.' : (result.reason || result.result), result.ok ? 'success' : 'error');
  if (result?.ok) closeModal();
});

window.addEventListener('message', (event) => {
  const message = event.data || {};
  if (message.action === 'open') {
    state.payload = message.payload;
    tablet.classList.remove('is-hidden');
    tablet.setAttribute('aria-hidden', 'false');
    document.documentElement.style.background = 'transparent';
    document.body.style.background = 'transparent';
    render();
  } else if (message.action === 'close') {
    tablet.classList.add('is-hidden');
    tablet.setAttribute('aria-hidden', 'true');
    document.documentElement.style.background = 'transparent';
    document.body.style.background = 'transparent';
    closeModal();
  } else if (message.action === 'territoriesUpdated' && state.payload) {
    state.payload.territories = message.territories;
    if (state.page === 'territories') render();
  }
});

window.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') api('close');
});

// Boot: ui_page visada aktyvus — užtikrinam, kad niekas nedažo pilko fono.
document.documentElement.style.background = 'transparent';
document.body.style.background = 'transparent';
tablet.classList.add('is-hidden');
tablet.setAttribute('aria-hidden', 'true');
closeModal();
