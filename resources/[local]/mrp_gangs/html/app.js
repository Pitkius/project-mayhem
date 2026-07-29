/* ============================================================
   Mayhem Syndicate — Gang Tablet UI
   Dark neon-purple redesign. All existing NUI callback names
   are preserved so the Lua wiring stays intact.
   ============================================================ */

const tablet = document.querySelector('#tablet');
const nav = document.querySelector('#nav');
const content = document.querySelector('#content');
const title = document.querySelector('#page-title');
const eyebrow = document.querySelector('#eyebrow');
const identity = document.querySelector('#identity');
const modalRoot = document.querySelector('#modal-root');
const toastRoot = document.querySelector('#toast-root');
const clockEl = document.querySelector('#clock');

const PALETTE = [
  '#A855F7', '#C084FC', '#D946EF', '#EC4899', '#F43F5E', '#F97316',
  '#F59E0B', '#EAB308', '#84CC16', '#22C55E', '#14B8A6', '#06B6D4',
  '#3B82F6', '#6366F1', '#7C3AED', '#4C1D95', '#64748B', '#0F172A',
];

const state = {
  payload: null,
  page: 'overview',
  adminOnly: false,
  adminTab: 'gangs',
  missionDifficulty: {},
  map: null,
  adminMap: null,
  adminMapLayers: {},
  adminDrawLayer: null,
  selectedTerritoryId: null,
  turfEditor: {
    id: '',
    label: '',
    type: 'gang',
    ownerGangId: '',
    vertices: [],
    allowsDrugSales: false,
    drugProduct: '',
    hourlyIncome: '',
    isNew: true,
  },
  territoryFilters: { gang: true, pvp: true, racket: true },
  mapLayers: {},
  mapMarkers: {},
  createColor: '#A855F7',
  createType: null,
  createLabel: '',
  createName: '',
  createTouchedName: false,
  settingsTab: 'general',
  warsTab: 'wars',
  clockTimer: null,
};

/* ------------------------------------------------------------
   ICONS (inline SVG so no external assets needed)
   ------------------------------------------------------------ */
const ICONS = {
  home: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 10l9-7 9 7v10a2 2 0 0 1-2 2h-4v-6H9v6H5a2 2 0 0 1-2-2z"/></svg>',
  missions: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4"/><circle cx="12" cy="12" r="1" fill="currentColor"/></svg>',
  territory: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 2l6 3 6-3v17l-6 3-6-3-6 3V5z"/><line x1="9" y1="2" x2="9" y2="19"/><line x1="15" y1="5" x2="15" y2="22"/></svg>',
  members: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
  stash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 8L12 3 3 8v8l9 5 9-5V8z"/><path d="M3.27 8L12 13l8.73-5"/><line x1="12" y1="22" x2="12" y2="13"/></svg>',
  finance: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="6" width="20" height="12" rx="2"/><circle cx="12" cy="12" r="2"/><path d="M6 12h.01M18 12h.01"/></svg>',
  wars: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 17.5L3 6V3h3l11.5 11.5"/><path d="M13 19l6-6"/><path d="M16 16l4 4"/><path d="M19 21l2-2"/><path d="M14.5 6.5L18 3l3 3-3.5 3.5"/></svg>',
  top: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="18 8 22 8 22 12"/><path d="M2 12l6-6 5 5 8-8"/></svg>',
  settings: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>',
  admin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="M9 12l2 2 4-4"/></svg>',
  plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>',
  mail: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>',
  chevron: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>',
  bolt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>',
  crown: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 20h20l-2-11-5 3-3-8-3 8-5-3z"/></svg>',
  shield: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>',
  arrowUp: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="19" x2="12" y2="5"/><polyline points="5 12 12 5 19 12"/></svg>',
  arrowDown: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><polyline points="19 12 12 19 5 12"/></svg>',
  drugs: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.5 20.5l10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7z"/><line x1="8.5" y1="8.5" x2="15.5" y2="15.5"/></svg>',
  weapon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 6l-1.5-1.5a2.12 2.12 0 0 0-3 3L11 9l-6 6v3h3l6-6 1.5 1.5a2.12 2.12 0 0 0 3-3L17 9l4-4-3-3z"/></svg>',
  ammo: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 2v6l3 3 3-3V2z"/><path d="M9 8l3 12 3-12"/></svg>',
  cash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>',
  box: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><line x1="3.27" y1="6.96" x2="12" y2="12.01"/><line x1="20.73" y1="6.96" x2="12" y2="12.01"/><line x1="12" y1="22.08" x2="12" y2="12"/></svg>',
  lock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>',
  history: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"/><polyline points="12 7 12 12 15 15"/></svg>',
  alert: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
  users: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/></svg>',
  target: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/></svg>',
  edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4z"/></svg>',
  handshake: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 11l3-3 3 3v6l-3 3-3-3z"/><path d="M9 8l-3 3v6l3 3 3-3v-6z"/><path d="M9 8l3-3 3 3"/></svg>',
};

/* ------------------------------------------------------------
   PAGE DEFINITIONS
   ------------------------------------------------------------ */
const pagesInGang = [
  { key: 'overview',    icon: ICONS.home,      label: 'Pagrindinis' },
  { key: 'missions',    icon: ICONS.missions,  label: 'Misijos' },
  { key: 'territories', icon: ICONS.territory, label: 'Teritorijos' },
  { key: 'members',     icon: ICONS.members,   label: 'Nariai' },
  { key: 'finance',     icon: ICONS.finance,   label: 'Finansai' },
  { key: 'wars',        icon: ICONS.wars,      label: 'Gaujų karai' },
  { key: 'top',         icon: ICONS.top,       label: 'Reitingai' },
  { key: 'settings',    icon: ICONS.settings,  label: 'Nustatymai' },
];

const pagesGuest = [
  { key: 'overview',    icon: ICONS.mail,      label: 'Kvietimai' },
  { key: 'register',    icon: ICONS.plus,      label: 'Registracija' },
  { key: 'territories', icon: ICONS.territory, label: 'Teritorijos' },
  { key: 'top',         icon: ICONS.top,       label: 'Reitingai' },
];

const reasonLt = {
  already_in_gang: 'Jau priklausai gaujai.',
  create_disabled: 'Gaujos kūrimas išjungtas.',
  rate_limited: 'Per greitai — palauk.',
  not_enough_money: 'Nepakanka pinigų.',
  permission_denied: 'Nėra teisių.',
  invalid_id: 'Neteisingas ID.',
  invalid_vertices: 'Poligonui reikia bent 3 taškų.',
  stock_territory: 'Stock turfų trinti negalima.',
  territory_not_found: 'Teritorija nerasta.',
  confirm_required: 'Reikia teisingo DELETE patvirtinimo.',
  gang_not_found: 'Gauja nerasta.',
  invalid_gang: 'Neteisingas gaujos ID.',
  apply_failed: 'Nepavyko pritaikyti turf.',
  invalid_type: 'Neteisingas gaujos tipas.',
  invalid_name: 'Techninis pavadinimas per trumpas (min. 3).',
  invalid_label: 'Rodomas pavadinimas per trumpas (min. 3).',
  name_taken: 'Toks techninis pavadinimas jau užimtas.',
  create_failed: 'Nepavyko sukurti gaujos.',
  create_disabled: 'Gaujų kūrimas išjungtas.',
  rate_limited: 'Per greitai — palauk.',
  permission_denied: 'Neturi teisės.',
  empty_response: 'Tuščias atsakymas.',
  not_enough_money: 'Neužtenka pinigų registracijos mokesčiui.',
  not_enough_cash: 'Neužtenka grynųjų.',
  not_enough_bank: 'Neužtenka pinigų banke.',
  not_enough_treasury: 'Neužtenka lėšų ižde.',
  invalid_avatar: 'Netinkama profilinės nuoroda (reikia http/https URL).',
  invalid_amount: 'Neteisinga suma.',
  member_limit: 'Pasiektas narių limitas.',
  role_too_high: 'Rangas per aukštas.',
  target_already_in_gang: 'Žaidėjas jau priklauso gaujai.',
  role_not_found: 'Rangas nerastas.',
  member_not_found: 'Narys nerastas.',
  protected_member: 'Nario negalima pašalinti.',
  owner_role_locked: 'Bosas negali būti keičiamas.',
  invite_not_found: 'Kvietimas nerastas arba baigėsi.',
  already_processed: 'Jau apdorota.',
  invalid_color: 'Neteisinga spalva.',
  war_not_found: 'Karas nerastas.',
  mission_not_found: 'Misija nerasta.',
};

/* ------------------------------------------------------------
   HELPERS
   ------------------------------------------------------------ */
const esc = (value) => String(value ?? '')
  .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;').replaceAll("'", '&#039;');

const money = (value) => {
  const n = Number(value || 0);
  return `$${n.toLocaleString('en-US')}`;
};

const num = (value) => Number(value || 0).toLocaleString('en-US');

const date = (value) => value ? new Date(String(value).replace(' ', 'T')).toLocaleString('lt-LT') : '—';

const timeAgo = (value) => {
  if (!value) return '—';
  const d = new Date(String(value).replace(' ', 'T'));
  const diff = Date.now() - d.getTime();
  if (Number.isNaN(diff)) return '—';
  const s = Math.floor(diff / 1000);
  if (s < 60) return `${s} s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m} min`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h} h`;
  const dd = Math.floor(h / 24);
  if (dd < 30) return `${dd} d`;
  return d.toLocaleDateString('lt-LT');
};

const fail = (result) => reasonLt[result?.reason] || result?.reason || result?.result || 'Klaida';
const gangTypeLabel = (key) => state.payload?.gangTypes?.[key]?.label || key || '—';

function initials(text) {
  const clean = String(text || '').trim();
  if (!clean) return '?';
  const parts = clean.split(/\s+/).slice(0, 2);
  return parts.map((p) => p[0] || '').join('').toUpperCase().slice(0, 2) || clean.slice(0, 2).toUpperCase();
}

function contrastColor(hex) {
  const c = String(hex || '#a855f7').replace('#', '');
  if (c.length !== 6) return '#fff';
  const r = parseInt(c.slice(0, 2), 16);
  const g = parseInt(c.slice(2, 4), 16);
  const b = parseInt(c.slice(4, 6), 16);
  const yiq = (r * 299 + g * 587 + b * 114) / 1000;
  return yiq > 155 ? '#0a0a13' : '#ffffff';
}

function hasPermission(permission) {
  const permissions = state.payload?.organization?.permissions;
  return permissions === '*' || (Array.isArray(permissions) && permissions.includes(permission));
}

function slugify(label) {
  return String(label || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '')
    .slice(0, 32);
}

function territoryCenter(territory) {
  if (territory?.anchor?.x != null && territory?.anchor?.y != null) {
    return { x: Number(territory.anchor.x), y: Number(territory.anchor.y) };
  }
  const verts = territory?.vertices || [];
  if (!verts.length) return null;
  let sx = 0, sy = 0;
  verts.forEach((v) => { sx += Number(v.x) || 0; sy += Number(v.y) || 0; });
  return { x: sx / verts.length, y: sy / verts.length };
}

function turfTypeColor(type) {
  if (type === 'pvp') return '#B91C1C';
  if (type === 'racket') return '#B45309';
  return '#15803D';
}

function turfDisplayColor(territory) {
  return territory.ownerColor || turfTypeColor(territory.type);
}

function hexToRgb(hex) {
  const h = String(hex || '#64748B').replace('#', '');
  const full = h.length === 3 ? h.split('').map((c) => c + c).join('') : h.padEnd(6, '0');
  return {
    r: parseInt(full.slice(0, 2), 16) || 0,
    g: parseInt(full.slice(2, 4), 16) || 0,
    b: parseInt(full.slice(4, 6), 16) || 0,
  };
}

function rgbToHex({ r, g, b }) {
  const to = (n) => Math.max(0, Math.min(255, Math.round(n))).toString(16).padStart(2, '0');
  return `#${to(r)}${to(g)}${to(b)}`;
}

function lerpColor(fromHex, toHex, t) {
  const a = hexToRgb(fromHex);
  const b = hexToRgb(toHex);
  return rgbToHex({
    r: a.r + (b.r - a.r) * t,
    g: a.g + (b.g - a.g) * t,
    b: a.b + (b.b - a.b) * t,
  });
}

function turfBaseStyle(territory, selected) {
  const color = turfDisplayColor(territory);
  const owned = Boolean(territory.ownerGangId);
  return {
    color,
    fillColor: color,
    fillOpacity: selected ? 0.48 : (owned ? 0.32 : 0.14),
    weight: selected ? 2.5 : 1.6,
    opacity: selected ? 0.95 : 0.82,
    className: `turf-poly${territory.state === 'contested' ? ' turf-contested' : ''}${selected ? ' is-selected' : ''}`,
  };
}

function animatePolygonStyle(polygon, toStyle, ms = 520) {
  if (!polygon) return;
  const fromColor = polygon.options.fillColor || toStyle.fillColor;
  const fromFill = Number(polygon.options.fillOpacity ?? 0.2);
  const fromWeight = Number(polygon.options.weight ?? 2);
  const start = performance.now();
  const tick = (now) => {
    const t = Math.min(1, (now - start) / ms);
    const eased = 1 - (1 - t) * (1 - t);
    polygon.setStyle({
      ...toStyle,
      fillColor: lerpColor(fromColor, toStyle.fillColor, eased),
      color: lerpColor(fromColor, toStyle.color, eased),
      fillOpacity: fromFill + (toStyle.fillOpacity - fromFill) * eased,
      weight: fromWeight + (toStyle.weight - fromWeight) * eased,
    });
    if (t < 1) requestAnimationFrame(tick);
    else polygon.setStyle(toStyle);
  };
  requestAnimationFrame(tick);
}

function durationHeld(since) {
  if (!since) return '—';
  const d = new Date(String(since).replace(' ', 'T'));
  const diff = Date.now() - d.getTime();
  if (Number.isNaN(diff) || diff < 0) return '—';
  const h = Math.floor(diff / 3600000);
  if (h < 24) return `${h} h`;
  return `${Math.floor(h / 24)} d`;
}

function lastWarLabel(territory) {
  const war = (territory.recentWars || [])[0];
  if (!war) return 'Nėra';
  const when = war.settledAt || war.createdAt;
  return `${war.attackerLabel || '?'} vs ${war.defenderLabel || '?'} · ${timeAgo(when)}`;
}

function upcomingAttackLabel(territory) {
  if (!territory.lockedUntil) return 'Nėra lock';
  const d = new Date(String(territory.lockedUntil).replace(' ', 'T'));
  if (Number.isNaN(d.getTime())) return '—';
  if (d.getTime() <= Date.now()) return 'Lock pasibaigė';
  return `Iki ${date(territory.lockedUntil)}`;
}

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

function empty(strong, message) {
  return `<div class="empty"><div><strong>${esc(strong || 'Duomenų nėra')}</strong><p>${esc(message || '')}</p></div></div>`;
}

function iconTile(icon) {
  return `<div class="icon-tile">${icon}</div>`;
}

function emblemHtml(color, name, size = 'md', avatarUrl = '') {
  const fg = contrastColor(color);
  const img = avatarUrl
    ? `<img class="emblem-img" src="${esc(avatarUrl)}" alt="" referrerpolicy="no-referrer" onerror="this.parentElement.classList.remove('has-img');this.remove()">`
    : '';
  return `<div class="emblem ${size}${avatarUrl ? ' has-img' : ''}" style="background:${esc(color)};color:${fg}">${img}<span>${esc(initials(name))}</span></div>`;
}

function avatarHtml(color, name, size = '', avatarUrl = '') {
  const fg = contrastColor(color);
  if (avatarUrl) {
    return `<div class="avatar ${size} has-img" style="background:${esc(color)};color:${fg}"><img src="${esc(avatarUrl)}" alt="" referrerpolicy="no-referrer" onerror="this.parentElement.classList.remove('has-img');this.remove()">${esc(initials(name))}</div>`;
  }
  return `<div class="avatar ${size}" style="background:${esc(color)};color:${fg}">${esc(initials(name))}</div>`;
}

function warningMeter(warnings) {
  const level = Number(warnings?.level || 0);
  const max = Number(warnings?.max || 5);
  const cells = Array.from({ length: max }, (_, i) =>
    `<i class="warn-cell ${i < level ? (level >= 5 ? 'crit' : level >= 3 ? 'hot' : 'warm') : ''}"></i>`
  ).join('');
  return `<div class="warn-panel">
    <div class="warn-head"><span>Įspėjimai</span><strong>${level}/${max}</strong></div>
    <div class="warn-meter">${cells}</div>
    <p class="muted small">${esc(warnings?.hint || '')}</p>
  </div>`;
}

/* ------------------------------------------------------------
   NAV
   ------------------------------------------------------------ */
function availablePages() {
  if (state.adminOnly && state.payload?.admin) {
    return [{ key: 'admin', icon: ICONS.admin, label: 'Administravimas' }];
  }
  const organization = state.payload?.organization;
  const list = organization ? [...pagesInGang] : [...pagesGuest];
  if (!organization && state.payload?.allowCreate === false) {
    return list.filter((p) => p.key !== 'register');
  }
  if (state.payload?.admin) list.push({ key: 'admin', icon: ICONS.admin, label: 'Administravimas' });
  return list;
}

function renderNav() {
  const available = availablePages();
  if (!available.some((p) => p.key === state.page)) state.page = available[0].key;

  const wars = (state.payload?.wars || []).filter((w) => ['preparation', 'active', 'settlement'].includes(w.state));
  const invites = state.payload?.invites || [];
  const organization = state.payload?.organization;

  const adminPage = available.find((p) => p.key === 'admin');
  const playerPages = available.filter((p) => p.key !== 'admin');

  let html = playerPages.map((p) => {
    let badge = '';
    if (p.key === 'wars' && wars.length) badge = `<span class="nav-badge">${wars.length}</span>`;
    if (p.key === 'overview' && !organization && invites.length) badge = `<span class="nav-badge">${invites.length}</span>`;
    return `
      <button class="nav-button ${state.page === p.key ? 'is-active' : ''}" data-page="${p.key}">
        <span class="nav-icon">${p.icon}</span>
        <span class="nav-label">${esc(p.label)}</span>
        ${badge}
      </button>`;
  }).join('');

  if (adminPage) {
    html += `<div class="nav-section-label">Administravimas</div>
      <button class="nav-button ${state.page === 'admin' ? 'is-active' : ''}" data-page="admin">
        <span class="nav-icon">${adminPage.icon}</span>
        <span class="nav-label">${esc(adminPage.label)}</span>
      </button>`;
  }

  nav.innerHTML = html;

  const gang = organization?.gang;
  if (gang) {
    const level = state.payload?.progression?.level ?? gang.level ?? 1;
    identity.innerHTML = `
      <strong>${esc(gang.label)}</strong>
      <span>${esc(gang.role_key || '—').toUpperCase()} · LV ${esc(level)}</span>`;
  } else {
    identity.innerHTML = `
      <strong>Neprisijungęs</strong>
      <span>${state.payload?.allowCreate ? 'Sukurk arba priimk kvietimą' : 'Peržiūrėk kvietimus'}</span>`;
  }
}

/* ------------------------------------------------------------
   OVERVIEW (Pagrindinis)
   ------------------------------------------------------------ */
function renderOverview() {
  const org = state.payload.organization;

  if (!org) return renderGuestOverview();

  const gang = org.gang;
  const color = gang.color_hex || '#A855F7';
  const territories = (state.payload.territories || []).filter((t) => Number(t.ownerGangId) === Number(gang.gang_id));
  const activeWars = (state.payload.wars || []).filter((w) => ['preparation', 'active', 'settlement'].includes(w.state));
  const progression = state.payload.progression;
  const progress = progression?.nextRequired
    ? Math.min(100, Math.round((progression.reputation / progression.nextRequired) * 100))
    : 100;
  const online = (org.members || []).filter((m) => m.online).length;
  const total = (org.members || []).length;

  const board = state.payload.missions?.missions || [];
  const featured = board[0];

  const activity = state.payload.activity || [];
  const recentActivity = activity.slice(0, 5);

  return `
    <div class="stack">
      <section class="hero-card">
        <div class="hero-head">
          ${emblemHtml(color, gang.label, 'md', gang.avatar_url)}
          <div class="hero-body">
            <h1>${esc(gang.label)}</h1>
            <p>${esc(gangTypeLabel(gang.gang_type))} · Level ${esc(progression?.level ?? gang.level ?? 1)} · ${esc((gang.role_key || '').toUpperCase())}</p>
            <div class="hero-badges">
              ${pill(gang.member_status || 'active', gang.member_status === 'active' ? 'success' : 'warning')}
              ${pill('Reputacija ' + num(gang.reputation), 'neon')}
              ${activeWars.length ? pill(activeWars.length + ' aktyvus karas', 'danger') : ''}
            </div>
          </div>
        </div>

        <div class="hero-stats">
          <div class="hero-stat"><strong>${num(gang.reputation)}</strong><small>Reputacija</small></div>
          <div class="hero-stat"><strong>${money(gang.treasury)}</strong><small>Iždas</small></div>
          <div class="hero-stat"><strong>${online}<span class="muted" style="font-size:14px;font-weight:600"> / ${total}</span></strong><small>Nariai online</small></div>
        </div>

        <div class="progress-header">
          <span>Progresas iki Level ${esc((progression?.level ?? 1) + 1)}</span>
          <strong>${progression?.nextRequired ? `${num(progression.reputation)} / ${num(progression.nextRequired)} REP` : 'MAX'}</strong>
        </div>
        <div class="progress"><span style="width:${progress}%"></span></div>
      </section>

      <div class="grid grid-hero">
        <article class="mission-featured">
          <div class="card-header">
            <div class="title">
              <h2>Aktyvus kontraktas</h2>
              <p>Rekomenduojama misija tavo gaujai</p>
            </div>
            ${pill('Featured', 'neon')}
          </div>
          ${featured ? `
            ${featured.imageUrl ? `<div class="mission-featured-media" style="background-image:url('${esc(featured.imageUrl)}')"></div>` : ''}
            <div style="display:flex;align-items:flex-start;gap:14px">
              <div class="icon-tile" style="width:44px;height:44px;border-radius:12px">${ICONS.target}</div>
              <div style="flex:1;min-width:0">
                <h3 style="font-size:14px">${esc(featured.label)}</h3>
                <p class="muted" style="margin:2px 0 0;font-size:11.5px">${esc(featured.description || '')}</p>
              </div>
            </div>
            <div class="tag-row">
              ${pill('Base ' + money(featured.baseReward), 'success')}
              ${pill('REP ' + featured.baseReputation, 'neon')}
              ${featured.hasCompound ? pill('Laukas', 'info') : featured.hasInterior ? pill('Interior', 'info') : ''}
              ${pill(featured.category || 'universal')}
            </div>
            <div class="button-row">
              <button class="button primary" data-page="missions">${ICONS.bolt}Peržiūrėti visas misijas</button>
              ${hasPermission('missions.start') ? `<button class="button" data-action="quick-start-mission" data-mission="${esc(featured.id)}">Pradėti Easy</button>` : ''}
            </div>` : empty('Misijų sąrašas tuščias', 'Grįžk vėliau — kontraktai atsiranda dinamiškai.')}
        </article>

        <article class="card">
          ${warningMeter(state.payload.warnings)}
        </article>
      </div>

      <div class="quick-actions">
        <button class="quick-action" data-page="missions">
          ${iconTile(ICONS.missions)}
          <strong>Misijos</strong><small>Kontraktai ir party</small>
        </button>
        <button class="quick-action" data-page="territories">
          ${iconTile(ICONS.territory)}
          <strong>Teritorijos</strong><small>Turf žemėlapis</small>
        </button>
        <button class="quick-action" data-page="finance">
          ${iconTile(ICONS.finance)}
          <strong>Finansai</strong><small>Iždas ir istorija</small>
        </button>
        <button class="quick-action" data-page="wars">
          ${iconTile(ICONS.wars)}
          <strong>Karai</strong><small>${activeWars.length} aktyv.</small>
        </button>
      </div>

      <div class="grid grid-hero">
        <article class="card">
          <div class="card-header"><div class="title"><h2>Kontroliuojamos teritorijos</h2><p class="muted">Kiek turf laiko gauja</p></div>${pill(String(territories.length), 'neon')}</div>
          <div class="list">
            ${territories.length ? territories.slice(0, 6).map((t) => `
              <div class="list-item">
                <div class="list-item-main">
                  <strong>${esc(t.label)}</strong>
                  <small>${esc(t.type)} · stabilumas ${esc(t.stability)}%</small>
                </div>
                ${pill(t.state, t.state === 'controlled' ? 'success' : 'warning')}
              </div>`).join('') : empty('Nėra turf', 'Užimk pirmąją teritoriją per karą.')}
          </div>
        </article>

        <article class="card">
          <div class="card-header"><div class="title"><h2>Paskutinė veikla</h2><p class="muted">Įvykiai gaujoje</p></div></div>
          <div class="activity-feed">
            ${recentActivity.length ? recentActivity.map((row) => `
              <div class="activity-row">
                ${iconTile(ICONS.history)}
                <div>
                  <strong>${esc(activityLabel(row.action))}</strong>
                  <small>${esc(row.actor_citizenid || 'Sistema')} · ${esc(row.target_type || '')} ${esc(row.target_id || '')}</small>
                </div>
                <time>${esc(timeAgo(row.created_at))}</time>
              </div>`).join('') : empty('Nėra įrašų', hasPermission('gang.logs') ? 'Kol kas ramu — būkite akyli.' : 'Reikia gang.logs teisės.')}
          </div>
        </article>
      </div>
    </div>`;
}

function activityLabel(action) {
  const map = {
    treasury_deposit: 'Iždas · įnašas',
    treasury_withdraw: 'Iždas · išėmimas',
    member_joined: 'Prisijungė narys',
    member_kicked: 'Pašalintas narys',
    member_invited: 'Pakviestas narys',
    member_role_changed: 'Pakeistas rangas',
    gang_created: 'Sukurta gauja',
    gang_info_updated: 'Redaguota info',
    role_created: 'Sukurtas rangas',
    role_updated: 'Redaguotas rangas',
    racket_income: 'Reketo pajamos',
    tribute_paid: 'Duoklė sumokėta',
    mission_completed: 'Užbaigta misija',
    mission_settled: 'Misijos atsiskaitymas',
    war_declared: 'Paskelbtas karas',
  };
  return map[action] || action || 'Įvykis';
}

function renderGuestOverview() {
  const invites = state.payload.invites || [];
  return `
    <div class="stack">
      <section class="hero-card">
        <div class="hero-head">
          <div class="emblem md" style="background:linear-gradient(135deg,#a855f7,#7c3aed);"><span>?</span></div>
          <div class="hero-body">
            <h1>Neprisijungęs prie gaujos</h1>
            <p>Priimk kvietimą arba${state.payload.allowCreate ? ' sukurk savo gaują' : ' palauk kol pakvies'}.</p>
            <div class="hero-badges">
              ${pill('Guest mode')}
              ${pill(invites.length + ' kvietimai', invites.length ? 'neon' : '')}
            </div>
          </div>
        </div>
        <div class="button-row" style="margin-top:8px">
          ${state.payload.allowCreate ? '<button class="button primary" data-page="register">' + ICONS.plus + 'Registracija</button>' : ''}
          <button class="button" data-page="top">${ICONS.top}Reitingai</button>
          <button class="button" data-page="territories">${ICONS.territory}Žemėlapis</button>
        </div>
      </section>

      <article class="card">
        <div class="card-header"><div class="title"><h2>Kvietimai</h2><p class="muted">Aktyvūs pasiūlymai iš gaujų</p></div>${pill(String(invites.length), 'neon')}</div>
        <div class="list">
          ${invites.length ? invites.map((invite) => `
            <div class="list-item">
              <div class="list-item-main">
                <strong>${esc(invite.gang_label)}</strong>
                <small>${esc(gangTypeLabel(invite.gang_type))} · ${esc(invite.role_key)} · iki ${date(invite.expires_at)}</small>
              </div>
              <button class="button primary" data-action="accept-invite" data-id="${invite.id}">Priimti</button>
            </div>`).join('') : empty('Aktyvių kvietimų nėra', 'Palauk kol tave pakvies arba sukurk savo gaują.')}
        </div>
      </article>
    </div>`;
}

/* ------------------------------------------------------------
   MISSIONS (Misijos)
   ------------------------------------------------------------ */
function renderMissions() {
  const board = state.payload.missions || {};
  if (!state.payload.organization) return empty('Nėra prieigos', 'Misijos prieinamos tik gaujos nariams.');

  const missions = board.missions || [];
  const readyRoles = state.payload.missionReady || [];

  return `
    <div class="stack">
      <div class="card-header">
        <div class="title">
          <h2>Kontraktų lenta</h2>
          <p class="muted">Misijos kelia reputaciją ir atlygį. ${missions.length} prieinamų kontraktų.</p>
        </div>
        <div class="button-row">
          <button class="button" data-action="ready-modal">${ICONS.users}Party pasiruošimas</button>
        </div>
      </div>

      <div class="mission-grid">
        ${missions.length ? missions.map((mission) => {
          const selected = state.missionDifficulty[mission.id] || mission.difficulties[0];
          const diffDef = board.difficulties?.[selected] || {};
          const reward = Math.round((Number(mission.baseReward) || 0) * (Number(diffDef.rewardMultiplier) || 1));
          return `
            <article class="mission-card">
              <div class="mission-card-media" style="background-image:url('${esc(mission.imageUrl || `images/missions/${mission.image || 'raid'}.png`)}')"></div>
              <div class="mission-card-body">
              <div class="mission-card-head">
                <div style="min-width:0">
                  <h3 style="font-size:14px">${esc(mission.label)}</h3>
                  <div class="tag-row" style="margin-top:6px">
                    ${pill(mission.category || 'universal', mission.category === 'universal' ? 'info' : 'neon')}
                    ${mission.hasCompound ? pill('Laukas') : mission.hasInterior ? pill('Interior') : ''}
                  </div>
                </div>
                ${iconTile(ICONS.target)}
              </div>
              <p>${esc(mission.description || '')}</p>
              <div class="mission-reward">${money(reward)}<small>· REP ${mission.baseReputation}</small></div>
              <div class="difficulty-select">
                <label>Sudėtingumas</label>
                <select data-mission-difficulty="${esc(mission.id)}">
                  ${mission.difficulties.map((key) =>
                    `<option value="${esc(key)}" ${key === selected ? 'selected' : ''}>${esc(board.difficulties?.[key]?.label || key)} ×${board.difficulties?.[key]?.rewardMultiplier || 1}</option>`
                  ).join('')}
                </select>
              </div>
              <button class="button primary wide" data-action="start-mission" data-mission="${esc(mission.id)}" ${hasPermission('missions.start') ? '' : 'disabled'}>
                ${ICONS.bolt}Pradėti operaciją
              </button>
              </div>
            </article>`;
        }).join('') : empty('Misijų nėra', 'Šiuo metu visi kontraktai išjungti.')}
      </div>
    </div>`;
}

/* ------------------------------------------------------------
   TERRITORIES (Teritorijos)
   ------------------------------------------------------------ */
function renderTerritories() {
  const mapAlreadyLive = Boolean(state.map);
  if (!mapAlreadyLive) setTimeout(initMap, 0);
  else setTimeout(() => {
    syncMapVisibility();
    (state.payload.territories || []).forEach((t) => {
      const poly = state.mapLayers[t.id];
      if (poly) animatePolygonStyle(poly, turfBaseStyle(t, t.id === state.selectedTerritoryId), 360);
    });
    state.map?.invalidateSize();
  }, 0);
  const selected = (state.payload.territories || []).find((t) => t.id === state.selectedTerritoryId);
  const ownId = Number(state.payload?.organization?.gang?.gang_id || 0);
  const ownColor = state.payload?.organization?.gang?.color_hex || '#A855F7';
  const owned = (state.payload.territories || []).filter((t) => Number(t.ownerGangId) === ownId).length;
  const filters = state.territoryFilters;
  const list = (state.payload.territories || []).filter((t) => filters[t.type] !== false);

  return `
    <div class="stack">
      <div class="map-legend">
        <button type="button" class="legend-toggle ${filters.gang ? 'is-on' : ''}" data-action="toggle-turf-filter" data-type="gang">
          <i class="legend-dot" style="background:#15803D"></i>Gang
        </button>
        <button type="button" class="legend-toggle ${filters.pvp ? 'is-on' : ''}" data-action="toggle-turf-filter" data-type="pvp">
          <i class="legend-dot" style="background:#B91C1C"></i>PvP
        </button>
        <button type="button" class="legend-toggle ${filters.racket ? 'is-on' : ''}" data-action="toggle-turf-filter" data-type="racket">
          <i class="legend-dot" style="background:#B45309"></i>Reketas
        </button>
        ${ownId ? `<span class="legend-own"><i class="legend-dot" style="background:${esc(ownColor)}"></i>Tavo gauja · ${owned}</span>` : ''}
      </div>
      <div class="map-workspace">
        <div id="territory-map"></div>
        <aside class="map-side">
          <article class="card turf-detail-card">
            <div class="card-header">
              <div class="title"><h3>${selected ? esc(selected.label) : 'Pasirink teritoriją'}</h3>
                ${selected ? `<p class="muted small">${esc(selected.type)} · ${esc(selected.id)}</p>` : ''}
              </div>
              ${selected ? pill(selected.state, selected.state === 'controlled' ? 'success' : selected.state === 'contested' ? 'danger' : 'warning') : ''}
            </div>
            ${selected ? `
              <dl class="turf-dl">
                <div><dt>Savininkas</dt><dd>${esc(selected.ownerLabel || 'Neutralu')}</dd></div>
                <div><dt>Reputacija</dt><dd>${selected.ownerReputation != null ? esc(selected.ownerReputation) : '—'}</dd></div>
                <div><dt>Valdoma</dt><dd>${esc(durationHeld(selected.controlledSince))}</dd></div>
                <div><dt>Pajamos / h</dt><dd>${selected.hourlyIncome ? money(selected.hourlyIncome) : '—'}</dd></div>
                <div><dt>Aktyvūs nariai</dt><dd>${esc(selected.activeMembersNearby ?? 0)}</dd></div>
                <div><dt>Stabilumas</dt><dd>${esc(selected.stability)}%</dd></div>
                <div><dt>Heat / aktyvumas</dt><dd>${esc(selected.heat || 0)}</dd></div>
                <div><dt>Kitas lock / puolimas</dt><dd>${esc(upcomingAttackLabel(selected))}</dd></div>
                <div><dt>Paskutinis karas</dt><dd>${esc(lastWarLabel(selected))}</dd></div>
              </dl>
              ${(selected.recentWars || []).length ? `
                <div class="turf-wars-mini">
                  <strong class="muted small">Paskutiniai karai</strong>
                  ${(selected.recentWars || []).map((w) => `
                    <div class="turf-war-row">
                      <span>${esc(w.attackerLabel || '?')} → ${esc(w.defenderLabel || '?')}</span>
                      <small>${esc(w.state)} · ${esc(timeAgo(w.settledAt || w.createdAt))}</small>
                    </div>`).join('')}
                </div>` : ''}
              <button class="button primary wide" data-action="set-waypoint" data-id="${esc(selected.id)}">Nustatyti GPS</button>`
              : '<p class="muted small">Užvesk pelę ant rajono — hover tipas. Spustelėk detalioms kortelės.</p>'}
          </article>
          <article class="card">
            <div class="card-header"><div class="title"><h3>Rajonai</h3></div>${pill(String(list.length), 'neon')}</div>
            <div class="list compact turf-list">
              ${list.length ? list.map((t) => `
                <button class="list-item list-button ${state.selectedTerritoryId === t.id ? 'is-active' : ''}" data-action="select-territory" data-id="${esc(t.id)}">
                  <div class="list-item-main">
                    <strong>${esc(t.label)}</strong>
                    <small>${esc(t.ownerLabel || 'Neutralu')} · ${esc(t.stability)}%</small>
                  </div>
                  <i class="legend-dot" style="background:${esc(turfDisplayColor(t))}"></i>
                </button>`).join('') : empty('Nėra', 'Įjunk filtrus legendoje.')}
            </div>
          </article>
        </aside>
      </div>
    </div>`;
}

function syncMapVisibility() {
  const filters = state.territoryFilters;
  Object.entries(state.mapLayers || {}).forEach(([id, polygon]) => {
    const territory = (state.payload.territories || []).find((t) => t.id === id);
    if (!territory || !polygon) return;
    const show = filters[territory.type] !== false;
    if (show) {
      if (!state.map.hasLayer(polygon)) polygon.addTo(state.map);
      const marker = state.mapMarkers[id];
      if (marker && !state.map.hasLayer(marker)) marker.addTo(state.map);
    } else {
      if (state.map.hasLayer(polygon)) state.map.removeLayer(polygon);
      const marker = state.mapMarkers[id];
      if (marker && state.map.hasLayer(marker)) state.map.removeLayer(marker);
    }
  });
}

function initMap() {
  const node = document.querySelector('#territory-map');
  if (!node || typeof L === 'undefined') return;

  const bounds = [[-4000, -4000], [6625, 4500]];
  const rebuild = !state.map || !node._leaflet_id;

  if (rebuild) {
    if (state.map) {
      try { state.map.remove(); } catch (_) { /* ignore */ }
      state.map = null;
    }
    state.mapLayers = {};
    state.mapMarkers = {};
    state.map = L.map(node, {
      crs: L.CRS.Simple, minZoom: -3, maxZoom: 1.25, zoomControl: true, attributionControl: false,
    });
    L.imageOverlay('asset/gtav_satellite_2048.png', bounds).addTo(state.map);
    state.map.fitBounds([[-2500, -2000], [5200, 3000]]);
  }

  const tip = document.querySelector('#turf-hover-tip') || (() => {
    const el = document.createElement('div');
    el.id = 'turf-hover-tip';
    el.className = 'turf-hover-tip is-hidden';
    document.body.appendChild(el);
    return el;
  })();

  const showTip = (territory, event) => {
    tip.innerHTML = `
      <strong>${esc(territory.label)}</strong>
      <span>${esc(territory.ownerLabel || 'Neutralu')}</span>
      <span>Rep: ${territory.ownerReputation != null ? esc(territory.ownerReputation) : '—'} · Heat ${esc(territory.heat || 0)}</span>
      <span>${esc(lastWarLabel(territory))}</span>`;
    tip.classList.remove('is-hidden');
    const rect = tip.getBoundingClientRect();
    const x = Math.min(window.innerWidth - rect.width - 12, (event?.originalEvent?.clientX || 0) + 14);
    const y = Math.min(window.innerHeight - rect.height - 12, (event?.originalEvent?.clientY || 0) + 14);
    tip.style.left = `${Math.max(8, x)}px`;
    tip.style.top = `${Math.max(8, y)}px`;
  };
  const hideTip = () => tip.classList.add('is-hidden');

  (state.payload.territories || []).forEach((territory) => {
    if (!territory.vertices?.length) return;
    const selected = territory.id === state.selectedTerritoryId;
    const style = turfBaseStyle(territory, selected);
    const latlngs = territory.vertices.map((v) => [v.y, v.x]);

    let polygon = state.mapLayers[territory.id];
    if (!polygon) {
      polygon = L.polygon(latlngs, style);
      state.mapLayers[territory.id] = polygon;
      polygon.on('click', () => {
        state.selectedTerritoryId = territory.id;
        hideTip();
        render();
      });
      polygon.on('mouseover', (e) => {
        polygon.setStyle({
          ...turfBaseStyle(territory, territory.id === state.selectedTerritoryId),
          fillOpacity: 0.55,
          weight: 2.8,
          className: `turf-poly is-hover${territory.state === 'contested' ? ' turf-contested' : ''}`,
        });
        if (polygon._path) polygon._path.classList.add('is-hover');
        showTip(territory, e);
      });
      polygon.on('mousemove', (e) => showTip(territory, e));
      polygon.on('mouseout', () => {
        animatePolygonStyle(polygon, turfBaseStyle(territory, territory.id === state.selectedTerritoryId), 280);
        if (polygon._path) polygon._path.classList.remove('is-hover');
        hideTip();
      });
    } else {
      polygon.setLatLngs(latlngs);
      animatePolygonStyle(polygon, style, 520);
    }

    const center = territoryCenter(territory);
    if (center) {
      let marker = state.mapMarkers[territory.id];
      const iconHtml = `<div class="turf-marker" style="--turf:${esc(turfDisplayColor(territory))}"><span></span></div>`;
      const icon = L.divIcon({ className: 'turf-marker-wrap', html: iconHtml, iconSize: [14, 14], iconAnchor: [7, 7] });
      if (!marker) {
        marker = L.marker([center.y, center.x], { icon, interactive: false });
        state.mapMarkers[territory.id] = marker;
      } else {
        marker.setLatLng([center.y, center.x]);
        marker.setIcon(icon);
      }
    }
  });

  syncMapVisibility();
  setTimeout(() => state.map?.invalidateSize(), 40);
}

/* ------------------------------------------------------------
   MEMBERS (Nariai)
   ------------------------------------------------------------ */
function roleLabel(roleKey) {
  const role = (state.payload?.organization?.roles || []).find((r) => r.role_key === roleKey);
  return role?.label || roleKey;
}

function memberSecondary(member) {
  const bits = [];
  bits.push(roleLabel(member.role_key));
  if (member.online) bits.push('Online');
  else if (member.last_seen_at) bits.push('Paskutinį kartą ' + timeAgo(member.last_seen_at));
  else bits.push('Offline');
  return bits.join(' · ');
}

function renderMembers() {
  const org = state.payload.organization;
  if (!org) return empty('Nėra prieigos', 'Nepriklausai gaujai.');

  const canInvite = hasPermission('members.invite');
  const canManage = hasPermission('members.set_role');
  const canResp = hasPermission('members.set_role') || hasPermission('roles.manage');
  const canKick = hasPermission('members.kick');
  const color = org.gang.color_hex || '#A855F7';
  const members = [...(org.members || [])].sort((a, b) => {
    const priorityA = (org.roles.find((r) => r.role_key === a.role_key)?.priority) || 0;
    const priorityB = (org.roles.find((r) => r.role_key === b.role_key)?.priority) || 0;
    return priorityB - priorityA;
  });
  const online = members.filter((m) => m.online).length;

  const respByCitizen = {};
  (org.responsibilities || []).forEach((row) => {
    (respByCitizen[row.citizenid] = respByCitizen[row.citizenid] || []).push(row.responsibility_key);
  });

  return `
    <div class="stack">
      <div class="card-header">
        <div class="title">
          <h2>Nariai</h2>
          <p class="muted">${members.length} narių · ${online} online</p>
        </div>
        ${canInvite ? `<button class="button primary" data-action="invite-modal">${ICONS.plus}Pakviesti narį</button>` : ''}
      </div>

      <div class="member-grid">
        ${members.map((member) => {
          const roleTone = member.role_key === 'boss' ? 'is-leader'
            : member.role_key === 'underboss' ? 'is-under' : '';
          const resps = respByCitizen[member.citizenid] || [];
          return `
            <article class="member-card ${roleTone}">
              ${avatarHtml(color, member.display_name, 'lg')}
              <div class="member-info">
                <strong>
                  ${esc(member.display_name)}
                  <span class="online-dot ${member.online ? 'is-online' : ''}"></span>
                </strong>
                <small>${esc(memberSecondary(member))}</small>
                ${resps.length ? `<div class="tag-row" style="margin-top:6px">${resps.map((k) => pill(org.responsibilityCatalog?.[k]?.label || k, 'info')).join('')}</div>` : ''}
              </div>
              <div class="member-actions">
                ${canManage && member.role_key !== 'boss' ? `<button class="button" data-action="role-modal" data-citizen="${esc(member.citizenid)}">Rangas</button>` : ''}
                ${canResp ? `<button class="button" data-action="resp-modal" data-citizen="${esc(member.citizenid)}">Atsak.</button>` : ''}
                ${canKick && member.role_key !== 'boss' ? `<button class="button danger" data-action="kick-member" data-citizen="${esc(member.citizenid)}">×</button>` : ''}
              </div>
            </article>`;
        }).join('')}
      </div>

      ${hasPermission('roles.manage') ? `
      <article class="card">
        <div class="card-header">
          <div class="title"><h2>Rangai ir teisės</h2><p class="muted">${org.roles.length} rangų sukonfigūruota</p></div>
          <button class="button primary" data-action="role-config-modal">${ICONS.plus}Naujas rangas</button>
        </div>
        <div class="grid grid-3">
          ${org.roles.map((role) => `
            <div class="list-item">
              <div class="list-item-main">
                <strong>${esc(role.label)}</strong>
                <small>${esc(role.role_key)} · priority ${esc(role.priority)}</small>
              </div>
              <button class="button" data-action="role-config-modal" data-role-key="${esc(role.role_key)}">${ICONS.edit}</button>
            </div>`).join('')}
        </div>
      </article>` : ''}
    </div>`;
}

/* ------------------------------------------------------------
   FINANCE (Finansai)
   ------------------------------------------------------------ */
function renderFinance() {
  const org = state.payload.organization;
  if (!org) return empty('Nėra prieigos', 'Finansai prieinami tik gaujos nariams.');

  const canView = hasPermission('finance.view');
  const canDeposit = hasPermission('finance.deposit');
  const canWithdraw = hasPermission('finance.withdraw');
  const history = state.payload.financeHistory || [];

  return `
    <div class="stack">
      <section class="finance-hero">
        <div class="amount">
          <small>Gaujos iždas</small>
          <strong>${money(org.gang.treasury)}</strong>
          <p class="muted small" style="margin-top:8px">${canView ? 'Įnašai nuskaičiuojami iš banko. Visos operacijos loginamos apačioje.' : 'Reikia finance.view teisės norint matyti istoriją.'}</p>
        </div>
        <div class="button-row" style="flex-direction:column;gap:8px;align-items:stretch;min-width:180px">
          ${canDeposit ? `<button class="button primary" data-action="treasury-modal" data-operation="deposit">${ICONS.arrowUp}Įnešti iš banko</button>` : ''}
          ${canWithdraw ? `<button class="button" data-action="treasury-modal" data-operation="withdraw">${ICONS.arrowDown}Išimti į banką</button>` : ''}
        </div>
      </section>

      <article class="card">
        <div class="card-header">
          <div class="title"><h2>Transakcijų istorija</h2><p class="muted">Paskutinės ~30 operacijų (treasury, reketas, duoklės, misijos)</p></div>
          ${pill(history.length + ' įrašai', 'neon')}
        </div>
        <div class="list">
          ${history.length ? history.map(renderTxRow).join('') : empty('Nėra įrašų', canView ? 'Kol kas judesio ižde nebuvo.' : 'Reikia finance.view teisės.')}
        </div>
      </article>
    </div>`;
}

function renderTxRow(row) {
  const action = row.action || '';
  let meta = null;
  try { meta = row.metadata_json ? JSON.parse(row.metadata_json) : null; } catch (e) { meta = null; }
  const amount = Number(meta?.amount || 0);
  let sign = 0;
  let icon = ICONS.history;
  if (action === 'treasury_deposit') { sign = 1; icon = ICONS.arrowUp; }
  else if (action === 'treasury_withdraw') { sign = -1; icon = ICONS.arrowDown; }
  else if (action === 'racket_income' || action === 'mission_completed' || action === 'mission_settled') { sign = 1; icon = ICONS.cash; }
  else if (action === 'tribute_paid') { sign = -1; icon = ICONS.handshake; }

  const label = activityLabel(action);
  return `
    <div class="tx-row">
      ${iconTile(icon)}
      <div>
        <strong>${esc(label)}</strong>
        <small>${esc(row.actor_citizenid || 'Sistema')}${row.target_type ? ' · ' + esc(row.target_type) : ''}</small>
      </div>
      <span class="tx-amount ${sign > 0 ? 'pos' : sign < 0 ? 'neg' : ''}">${sign >= 0 ? '+' : '−'}${money(Math.abs(amount || 0))}</span>
      <span class="tx-time">${esc(timeAgo(row.created_at))}</span>
    </div>`;
}

/* ------------------------------------------------------------
   WARS (Gaujų karai)
   ------------------------------------------------------------ */
function renderWars() {
  const org = state.payload.organization;
  if (!org) return empty('Nėra prieigos', 'Karai prieinami tik gaujos nariams.');

  const tab = state.warsTab || 'wars';
  const wars = state.payload.wars || [];
  const diplomacy = state.payload.diplomacy || [];
  const activeWars = wars.filter((w) => ['preparation', 'active', 'settlement'].includes(w.state));

  return `
    <div class="stack">
      <div class="card-header">
        <div class="title">
          <h2>Karai ir diplomatija</h2>
          <p class="muted">${activeWars.length} aktyvūs karai · ${diplomacy.length} diplomatinių įrašų</p>
        </div>
        <div class="button-row">
          <button class="button ${tab === 'wars' ? 'primary' : ''}" data-tab="wars">${ICONS.wars}Karai</button>
          <button class="button ${tab === 'diplomacy' ? 'primary' : ''}" data-tab="diplomacy">${ICONS.handshake}Diplomatija</button>
          ${tab === 'wars' && hasPermission('wars.declare') ? `<button class="button primary" data-action="war-modal">${ICONS.plus}Skelbti karą</button>` : ''}
          ${tab === 'diplomacy' && hasPermission('diplomacy.propose') ? `<button class="button primary" data-action="treaty-modal">${ICONS.plus}Nauja sutartis</button>` : ''}
        </div>
      </div>

      ${tab === 'wars' ? renderWarsList(wars) : renderDiplomacyList(diplomacy)}
    </div>`;
}

function renderWarsList(wars) {
  if (!wars.length) return empty('Karo kampanijų nėra', 'Kai paskelbsi karą — jis atsiras čia.');
  return `<div class="grid grid-2">
    ${wars.map((war) => {
      const stateName = war.state;
      const isActive = stateName === 'active';
      return `
        <article class="war-card ${isActive ? 'is-active' : ''}">
          <div class="card-header">
            <div class="title">
              <h3>Karas #${esc(war.id)}</h3>
              <p class="muted small">${esc(war.territory_id)}</p>
            </div>
            ${pill(stateName, isActive ? 'danger' : stateName === 'settlement' ? 'warning' : 'info')}
          </div>
          <div class="war-teams">
            <div class="war-team">
              ${avatarHtml('#f43f5e', war.attacker_label, '')}
              <div><strong>${esc(war.attacker_label)}</strong><small>Puolėjai</small></div>
            </div>
            <span class="war-vs">VS</span>
            <div class="war-team right">
              ${avatarHtml('#a855f7', war.defender_label, '')}
              <div><strong>${esc(war.defender_label)}</strong><small>Gynėjai</small></div>
            </div>
          </div>
          <div class="war-score">
            <div class="n">${esc(war.attacker_score)}</div>
            <div class="sep">:</div>
            <div class="n">${esc(war.defender_score)}</div>
          </div>
          <p class="muted small" style="margin:12px 0 10px;text-align:center">Aktyvus: ${esc(date(war.active_starts_at))} — ${esc(date(war.active_ends_at))}</p>
          <button class="button wide" data-action="war-details" data-id="${war.id}">Detaliau / Roster</button>
        </article>`;
    }).join('')}
  </div>`;
}

function renderDiplomacyList(rows) {
  const ownId = Number(state.payload.organization.gang.gang_id);
  if (!rows.length) return empty('Diplomatija tuščia', 'Sudaryk sąjungą, nepuolimo paktą arba duoklę.');
  return `<div class="list">
    ${rows.map((row) => {
      const other = Number(row.gang_a_id) === ownId ? row.gang_b_label : row.gang_a_label;
      const incoming = row.status === 'pending' && Number(row.proposed_by_gang_id) !== ownId;
      const typeLabel = state.payload.treatyTypes?.[row.treaty_type]?.label || row.treaty_type;
      return `
        <div class="list-item">
          <div class="list-item-main">
            <strong>${esc(other)}</strong>
            <small>${esc(typeLabel)} · ${esc(row.status)} · iki ${esc(date(row.expires_at))}</small>
          </div>
          <div class="button-row">
            ${incoming && hasPermission('diplomacy.accept') ? `
              <button class="button primary" data-action="resolve-treaty" data-id="${row.id}" data-accept="true">Priimti</button>
              <button class="button" data-action="resolve-treaty" data-id="${row.id}" data-accept="false">Atmesti</button>` : ''}
            ${row.status === 'active' && hasPermission('diplomacy.break')
              ? `<button class="button danger" data-action="break-treaty" data-id="${row.id}">Nutraukti</button>` : ''}
          </div>
        </div>`;
    }).join('')}
  </div>`;
}

/* ------------------------------------------------------------
   TOP + PROGRESSION LADDER (Reitingai)
   ------------------------------------------------------------ */
function renderTop() {
  const rows = state.payload.topGangs || [];
  const progression = state.payload.progression;

  return `
    <div class="stack">
      <section class="hero-card">
        <div class="hero-head">
          ${iconTile(ICONS.top)}
          <div class="hero-body">
            <h1>Reitingai</h1>
            <p>Top gaujos ir gaujos progresijos lygiai</p>
          </div>
        </div>
      </section>

      <article class="card">
        <div class="card-header"><div class="title"><h2>Top gaujos</h2><p class="muted">Pagal reputaciją, lygį ir turf</p></div></div>
        <ol class="top-list">
          ${rows.length ? rows.map((g, i) => `
            <li class="top-item ${i === 0 ? 'is-first' : ''}">
              <span class="top-rank">#${i + 1}</span>
              ${emblemHtml(g.color_hex || '#A855F7', g.label, 'sm', g.avatar_url)}
              <div class="list-item-main">
                <strong>${esc(g.label)}</strong>
                <small>${esc(gangTypeLabel(g.gang_type))} · Lv.${esc(g.level)} · ${num(g.members || 0)} narių · ${num(g.territories || 0)} turf</small>
              </div>
              <div class="top-rep">${num(g.reputation)}<small>REP</small></div>
            </li>`).join('') : `<li>${empty('Gaujų sąrašas tuščias', 'Kol kas neužregistruota nė vienos aktyvios gaujos.')}</li>`}
        </ol>
      </article>

      ${progression ? `
      <article class="card">
        <div class="card-header">
          <div class="title"><h2>Progresijos lygiai</h2><p class="muted">Kiekvienas lygis atrakina naujus kontraktus</p></div>
          ${pill('Level ' + progression.level, 'neon')}
        </div>
        <div class="ladder">
          ${progression.levels.map((level) => {
            const unlocked = progression.reputation >= level.required;
            const isCurrent = level.level === progression.level;
            return `
              <div class="ladder-card ${isCurrent ? 'is-current' : ''} ${!unlocked ? 'is-locked' : ''}">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px">
                  <h4>Level ${level.level}</h4>
                  ${pill(unlocked ? 'Atrakinta' : num(level.required) + ' REP', unlocked ? 'success' : '')}
                </div>
                <p>${esc(level.unlock)}</p>
                <div class="ladder-req">${unlocked ? 'Pasiektas' : 'Reikia ' + num(level.required) + ' rep'}</div>
              </div>`;
          }).join('')}
        </div>
      </article>` : ''}
    </div>`;
}

/* ------------------------------------------------------------
   SETTINGS (Nustatymai)
   ------------------------------------------------------------ */
function renderSettings() {
  const org = state.payload.organization;
  if (!org) return empty('Nėra prieigos', 'Nustatymai prieinami tik gaujos nariams.');

  const gang = org.gang;
  const canEdit = hasPermission('gang.edit');
  const canManageRoles = hasPermission('roles.manage');
  const canLogs = hasPermission('gang.logs');
  const activity = state.payload.activity || [];

  return `
    <div class="stack">
      <div class="card-header">
        <div class="title"><h2>Gaujos nustatymai</h2><p class="muted">Info, rangai, aktyvumo žurnalas</p></div>
      </div>

      <article class="settings-section">
        <div class="card-header">
          <div class="title"><h3>Bendra informacija</h3><p class="muted small">Pavadinimas, spalva ir profilinė</p></div>
          ${canEdit ? `<button class="button" data-action="gang-info-modal">${ICONS.edit}Redaguoti</button>` : ''}
        </div>
        <div class="settings-row">
          <div><strong>Pavadinimas</strong><small>${esc(gang.label)}</small></div>
          ${emblemHtml(gang.color_hex || '#A855F7', gang.label, 'sm', gang.avatar_url)}
        </div>
        <div class="settings-row">
          <div><strong>Techninis vardas</strong><small>${esc(gang.name)}</small></div>
        </div>
        <div class="settings-row">
          <div><strong>Tipas</strong><small>${esc(gangTypeLabel(gang.gang_type))}</small></div>
        </div>
        <div class="settings-row">
          <div><strong>Spalva</strong><small>${esc(gang.color_hex || '—')}</small></div>
          <span style="display:inline-block;width:22px;height:22px;border-radius:6px;background:${esc(gang.color_hex || '#A855F7')};box-shadow:0 0 12px ${esc(gang.color_hex || '#A855F7')}"></span>
        </div>
        <div class="settings-row">
          <div><strong>Profilinė</strong><small>${gang.avatar_url ? 'Nustatyta' : 'Nenustatyta'}</small></div>
        </div>
      </article>

      ${canManageRoles ? `
      <article class="settings-section">
        <div class="card-header">
          <div class="title"><h3>Rangai ir teisės</h3><p class="muted small">${org.roles.length} rangų sukurta</p></div>
          <button class="button primary" data-action="role-config-modal">${ICONS.plus}Naujas rangas</button>
        </div>
        <div class="list">
          ${org.roles.map((role) => `
            <div class="list-item">
              <div class="list-item-main">
                <strong>${esc(role.label)}</strong>
                <small>${esc(role.role_key)} · priority ${esc(role.priority)}${Number(role.is_owner) === 1 ? ' · owner' : ''}</small>
              </div>
              <button class="button" data-action="role-config-modal" data-role-key="${esc(role.role_key)}">${ICONS.edit}Redaguoti</button>
            </div>`).join('')}
        </div>
      </article>` : ''}

      ${canLogs ? `
      <article class="settings-section">
        <div class="card-header">
          <div class="title"><h3>Aktyvumo žurnalas</h3><p class="muted small">Paskutiniai ${activity.length} įrašai</p></div>
          ${pill('gang.logs', 'info')}
        </div>
        <div class="table-wrap">
          <table>
            <thead><tr><th>Laikas</th><th>Veiksmas</th><th>Aktorius</th><th>Taikinys</th></tr></thead>
            <tbody>
              ${activity.length ? activity.slice(0, 40).map((row) => `
                <tr>
                  <td>${esc(date(row.created_at))}</td>
                  <td>${esc(activityLabel(row.action))}</td>
                  <td>${esc(row.actor_citizenid || 'Sistema')}</td>
                  <td>${esc(row.target_type || '')} ${esc(row.target_id || '')}</td>
                </tr>`).join('') : `<tr><td colspan="4">${empty('Nėra įrašų', 'Kol kas nieko neįvyko.')}</td></tr>`}
            </tbody>
          </table>
        </div>
      </article>` : ''}
    </div>`;
}

/* ------------------------------------------------------------
   REGISTER (Registracija) - premium form
   ------------------------------------------------------------ */
function renderRegister() {
  if (state.payload.organization) {
    return `<article class="card">
      <div class="card-header"><div class="title"><h2>Jau priklausai gaujai</h2><p class="muted">„${esc(state.payload.organization.gang.label)}“</p></div></div>
      <button class="button" data-page="overview">Į pagrindinį</button>
    </article>`;
  }
  if (state.payload.allowCreate === false) {
    return empty('Registracija išjungta', 'Gaujų kūrimas žaidėjams šiuo metu išjungtas. Priimk kvietimą.');
  }

  const types = Object.entries(state.payload.gangTypes || {});
  if (!state.createType && types.length) state.createType = types[0][0];

  const cost = Number(state.payload.creationCost || 0);
  const previewLabel = state.createLabel || 'Nauja gauja';
  const previewName = state.createName || slugify(previewLabel);

  return `
    <div class="stack">
      <section class="register-hero">
        <div class="register-emblem-wrap">
          <div id="register-emblem" class="emblem" style="background:${esc(state.createColor)};color:${contrastColor(state.createColor)}"><span>${esc(initials(previewLabel))}</span></div>
          <small>Emblema (peržiūra)</small>
        </div>
        <div class="preview-text" style="flex:1;min-width:0">
          <h2 id="register-preview-label">${esc(previewLabel)}</h2>
          <p id="register-preview-meta">${esc(gangTypeLabel(state.createType))} · ${esc(state.createColor)}</p>
          ${cost > 0 ? `<span class="register-cost-tag">${ICONS.cash} Registracija kainuoja ${money(cost)}</span>` : ''}
        </div>
      </section>

      <form id="create-gang-form" class="card stack">
        <div class="grid grid-2">
          <div class="field">
            <label>Rodomas pavadinimas</label>
            <input name="label" maxlength="42" required placeholder="Pvz. Grove Street" value="${esc(state.createLabel)}">
            <small class="muted">Matys visi žaidėjai žemėlapyje ir reitingus.</small>
          </div>
          <div class="field">
            <label>Techninis pavadinimas</label>
            <input name="name" maxlength="32" required pattern="[a-z0-9_\\-]{3,32}" placeholder="grove_street" value="${esc(state.createName || slugify(state.createLabel))}">
            <small class="muted">Automatiškai generuojamas iš pavadinimo.</small>
          </div>
        </div>

        <div class="field">
          <label>Tipas</label>
          <div class="type-grid">
            ${types.map(([key, def]) => `
              <button type="button" class="type-card ${key === state.createType ? 'is-active' : ''}" data-action="pick-type" data-type="${esc(key)}">
                <strong>${esc(def.label || key)}</strong>
                <small>${esc(typeHint(key))}</small>
              </button>`).join('')}
          </div>
        </div>

        <div class="field">
          <label>Spalva</label>
          <input type="hidden" name="colorHex" id="create-color" value="${esc(state.createColor)}">
          <div class="swatches">
            ${PALETTE.map((hex) =>
              `<button type="button" class="swatch ${hex.toUpperCase() === state.createColor.toUpperCase() ? 'is-active' : ''}"
                data-action="pick-color" data-color="${hex}" style="background:${hex};box-shadow:0 0 12px ${hex}55" title="${hex}"></button>`
            ).join('')}
          </div>
        </div>

        <div class="button-row">
          <button class="button primary" type="submit">${ICONS.bolt}${cost > 0 ? 'Sukurti gaują · ' + money(cost) : 'Sukurti gaują'}</button>
          <button type="button" class="button" data-page="overview">Atšaukti</button>
        </div>
      </form>
    </div>`;
}

function typeHint(key) {
  const hints = {
    street: 'Gatvės aliejus, trap houses, PvP.',
    cartel: 'Laboratorijos, konvojai, kontrabanda.',
    mafia: 'Duoklės, apsauga, plovimas.',
    biker: 'Klubas, ginklai, motociklai.',
    racing: 'Automobiliai, kontraktai, maršrutai.',
  };
  return hints[key] || 'Speciali gaujos kryptis.';
}

/* ------------------------------------------------------------
   ADMIN
   ------------------------------------------------------------ */
function resetTurfEditor(territory) {
  if (!territory) {
    state.turfEditor = {
      id: '',
      label: '',
      type: 'gang',
      ownerGangId: '',
      vertices: [],
      allowsDrugSales: false,
      drugProduct: '',
      hourlyIncome: '',
      isNew: true,
    };
    return;
  }
  state.turfEditor = {
    id: territory.id || '',
    label: territory.label || '',
    type: territory.type || 'gang',
    ownerGangId: territory.ownerGangId ? String(territory.ownerGangId) : '',
    vertices: (territory.vertices || []).map((v) => ({ x: Number(v.x), y: Number(v.y) })),
    allowsDrugSales: territory.allowsDrugSales === true || Boolean(territory.drugProduct),
    drugProduct: territory.drugProduct || '',
    hourlyIncome: territory.hourlyIncome ? String(territory.hourlyIncome) : '',
    isNew: false,
    stock: territory.stock === true,
    runtime: territory.runtime === true,
  };
}

function renderAdminGangs(admin) {
  return `
    <article class="card">
      <div class="card-header"><div class="title"><h2>Gaujų valdymas</h2><p class="muted">Statusas ir ištrynimas</p></div></div>
      <div class="table-wrap"><table>
        <thead><tr><th>ID</th><th>Gauja</th><th>Tipas</th><th>REP</th><th>Heat</th><th>Iždas</th><th>Statusas</th><th></th></tr></thead>
        <tbody>${admin.gangs.map((g) => `
          <tr>
            <td>${g.id}</td>
            <td>${esc(g.label)}</td>
            <td>${esc(g.gang_type)}</td>
            <td>${num(g.reputation)}</td>
            <td>${g.heat || 0}</td>
            <td>${money(g.treasury)}</td>
            <td><select data-admin-gang-status="${g.id}">
              ${['active', 'suspended', 'archived'].map((s) => `<option ${s === g.status ? 'selected' : ''}>${s}</option>`).join('')}
            </select></td>
            <td><button class="button danger small" data-action="admin-delete-gang" data-id="${g.id}" data-label="${esc(g.label)}">Ištrinti</button></td>
          </tr>`).join('')}
        </tbody>
      </table></div>
    </article>`;
}

function renderAdminTurfs(admin) {
  const editor = state.turfEditor;
  const list = state.payload.territories || [];
  return `
    <div class="admin-turf-layout">
      <aside class="card admin-turf-list">
        <div class="card-header">
          <div class="title"><h2>Teritorijos</h2><p class="muted">${list.length} zonos</p></div>
          <button class="button primary small" data-action="admin-turf-new">${ICONS.plus} Nauja</button>
        </div>
        <div class="list compact">
          ${list.map((t) => `
            <button type="button" class="list-item ${editor.id === t.id && !editor.isNew ? 'is-active' : ''}" data-action="admin-turf-edit" data-id="${esc(t.id)}">
              <div class="list-item-main">
                <strong>${esc(t.label)}</strong>
                <small>${esc(t.type)} · ${esc(t.ownerLabel || 'Neutralu')}${t.runtime ? ' · custom' : ''}</small>
              </div>
              <i class="legend-dot" style="background:${esc(turfDisplayColor(t))}"></i>
            </button>`).join('') || empty('Nėra teritorijų', 'Sukurk pirmąją zoną.')}
        </div>
      </aside>

      <article class="card admin-turf-editor">
        <div class="card-header">
          <div class="title">
            <h2>${editor.isNew ? 'Nauja turf zona' : 'Redaguoti turf'}</h2>
            <p class="muted">Spausk žemėlapį — pridėti viršūnę · Apply išsaugo geometriją + savininką</p>
          </div>
        </div>
        <div class="admin-turf-form grid grid-2">
          <div class="field"><label>ID (techninis)</label>
            <input id="admin-turf-id" maxlength="48" pattern="[a-z0-9_]{3,48}" ${editor.isNew ? '' : 'readonly'}
              value="${esc(editor.id)}" placeholder="pvz. mirror_park_east">
          </div>
          <div class="field"><label>Pavadinimas</label>
            <input id="admin-turf-label" maxlength="64" value="${esc(editor.label)}" placeholder="Mirror Park East">
          </div>
          <div class="field"><label>Tipas</label>
            <select id="admin-turf-type">
              ${['gang', 'pvp', 'racket'].map((t) => `<option value="${t}" ${editor.type === t ? 'selected' : ''}>${t}</option>`).join('')}
            </select>
          </div>
          <div class="field"><label>Savininkas</label>
            <select id="admin-turf-owner">
              <option value="">Neutralu</option>
              ${admin.gangs.filter((g) => g.status === 'active').map((g) =>
                `<option value="${g.id}" ${String(g.id) === String(editor.ownerGangId) ? 'selected' : ''}>${esc(g.label)}</option>`
              ).join('')}
            </select>
          </div>
          <div class="field"><label>Drug produktas (optional)</label>
            <input id="admin-turf-drug" maxlength="32" value="${esc(editor.drugProduct)}" placeholder="weed / cocaine / meth…">
          </div>
          <div class="field"><label>Reketo pajamos / h</label>
            <input id="admin-turf-income" type="number" min="0" value="${esc(editor.hourlyIncome)}" placeholder="0">
          </div>
        </div>
        <label class="checkbox-row"><input type="checkbox" id="admin-turf-drugs" ${editor.allowsDrugSales ? 'checked' : ''}> Leidžia narkotikų pardavimą</label>
        <p class="muted small">Viršūnės: <strong>${editor.vertices.length}</strong> (min. 3). Stock zonas galima perpiešti; ištrinti galima tik custom.</p>
        <div class="admin-turf-actions">
          <button class="button" data-action="admin-turf-add-here">+ Mano pozicija</button>
          <button class="button" data-action="admin-turf-undo" ${editor.vertices.length ? '' : 'disabled'}>Undo taškas</button>
          <button class="button" data-action="admin-turf-clear" ${editor.vertices.length ? '' : 'disabled'}>Valyti poligoną</button>
          <button class="button primary" data-action="admin-turf-apply">${ICONS.bolt} Apply / Išsaugoti</button>
          <button class="button" data-action="admin-turf-reset-owner" ${editor.isNew ? 'disabled' : ''}>Reset savininką</button>
          <button class="button danger" data-action="admin-turf-delete" ${editor.isNew || editor.stock ? 'disabled' : ''}>Ištrinti zoną</button>
        </div>
        <div id="admin-turf-map" class="admin-turf-map"></div>
      </article>
    </div>`;
}

function renderAdminOps(admin) {
  return `
    <article class="card">
      <div class="card-header"><div class="title"><h2>Aktyvūs karai</h2></div></div>
      <div class="list">
        ${admin.activeWars.length ? admin.activeWars.map((w) => `
          <div class="list-item">
            <div class="list-item-main">
              <strong>#${w.id} · ${esc(w.territory_id)}</strong>
              <small>${esc(w.state)} · ${w.attacker_score}:${w.defender_score}</small>
            </div>
            <button class="button danger" data-action="admin-cancel-war" data-id="${w.id}">Atšaukti</button>
          </div>`).join('') : empty('Aktyvių karų nėra', 'Nieko nedaryti.')}
      </div>
    </article>
    <article class="card">
      <div class="card-header"><div class="title"><h2>Mission toggles</h2></div></div>
      <div class="grid grid-3">${(admin.missions || []).map((m) =>
        `<label class="list-item">
          <span>${esc(m.label)}</span>
          <input type="checkbox" data-admin-mission="${esc(m.id)}" ${m.enabled ? 'checked' : ''}>
        </label>`
      ).join('')}</div>
    </article>
    <article class="card">
      <div class="card-header"><div class="title"><h2>Greitas turf savininkas</h2><p class="muted">Be geometrijos keitimo</p></div></div>
      <div class="table-wrap"><table>
        <thead><tr><th>Teritorija</th><th>Tipas</th><th>Savininkas</th><th>Stabilumas</th></tr></thead>
        <tbody>${(state.payload.territories || []).map((t) => `
          <tr>
            <td>${esc(t.label)}</td>
            <td>${esc(t.type)}</td>
            <td>
              <select data-admin-territory-owner="${esc(t.id)}">
                <option value="">Neutralu</option>
                ${admin.gangs.filter((g) => g.status === 'active').map((g) =>
                  `<option value="${g.id}" ${Number(g.id) === Number(t.ownerGangId) ? 'selected' : ''}>${esc(g.label)}</option>`
                ).join('')}
              </select>
            </td>
            <td>${esc(t.stability)}%</td>
          </tr>`).join('')}
        </tbody>
      </table></div>
    </article>`;
}

function destroyAdminMap() {
  if (state.adminMap) {
    try { state.adminMap.remove(); } catch (_) { /* ignore */ }
  }
  state.adminMap = null;
  state.adminMapLayers = {};
  state.adminDrawLayer = null;
}

function syncAdminDrawLayer() {
  if (!state.adminMap) return;
  if (state.adminDrawLayer) {
    try { state.adminMap.removeLayer(state.adminDrawLayer); } catch (_) { /* ignore */ }
    state.adminDrawLayer = null;
  }
  const verts = state.turfEditor.vertices || [];
  if (verts.length < 2) return;
  const latlngs = verts.map((v) => [v.y, v.x]);
  state.adminDrawLayer = L.polygon(latlngs, {
    color: '#A855F7',
    weight: 2.5,
    fillColor: '#A855F7',
    fillOpacity: 0.35,
    dashArray: '6 4',
  }).addTo(state.adminMap);
}

function initAdminMap() {
  const node = document.querySelector('#admin-turf-map');
  if (!node || typeof L === 'undefined') return;
  const bounds = [[-4000, -4000], [6625, 4500]];
  const rebuild = !state.adminMap || !node._leaflet_id;
  if (rebuild) {
    destroyAdminMap();
    state.adminMap = L.map(node, {
      crs: L.CRS.Simple, minZoom: -3, maxZoom: 1.25, zoomControl: true, attributionControl: false,
    });
    L.imageOverlay('asset/gtav_satellite_2048.png', bounds).addTo(state.adminMap);
    state.adminMap.fitBounds([[-2500, -2000], [5200, 3000]]);
    state.adminMap.on('click', (e) => {
      const x = Number(e.latlng.lng);
      const y = Number(e.latlng.lat);
      if (!Number.isFinite(x) || !Number.isFinite(y)) return;
      state.turfEditor.vertices.push({ x, y });
      syncAdminDrawLayer();
      const count = document.querySelector('.admin-turf-editor .muted.small strong');
      if (count) count.textContent = String(state.turfEditor.vertices.length);
    });
  }

  Object.values(state.adminMapLayers).forEach((layer) => {
    try { state.adminMap.removeLayer(layer); } catch (_) { /* ignore */ }
  });
  state.adminMapLayers = {};

  (state.payload.territories || []).forEach((territory) => {
    if (!territory.vertices?.length) return;
    if (territory.id === state.turfEditor.id && !state.turfEditor.isNew) return;
    const latlngs = territory.vertices.map((v) => [v.y, v.x]);
    const layer = L.polygon(latlngs, {
      ...turfBaseStyle(territory, false),
      fillOpacity: 0.18,
      weight: 1.2,
    });
    layer.on('click', (e) => {
      L.DomEvent.stopPropagation(e);
      resetTurfEditor(territory);
      render();
    });
    layer.addTo(state.adminMap);
    state.adminMapLayers[territory.id] = layer;
  });

  syncAdminDrawLayer();
  setTimeout(() => state.adminMap?.invalidateSize(), 40);
}

function readTurfEditorForm() {
  const idEl = document.querySelector('#admin-turf-id');
  const labelEl = document.querySelector('#admin-turf-label');
  const typeEl = document.querySelector('#admin-turf-type');
  const ownerEl = document.querySelector('#admin-turf-owner');
  const drugEl = document.querySelector('#admin-turf-drug');
  const incomeEl = document.querySelector('#admin-turf-income');
  const drugsEl = document.querySelector('#admin-turf-drugs');
  if (idEl && state.turfEditor.isNew) state.turfEditor.id = idEl.value.trim().toLowerCase();
  if (labelEl) state.turfEditor.label = labelEl.value.trim();
  if (typeEl) state.turfEditor.type = typeEl.value;
  if (ownerEl) state.turfEditor.ownerGangId = ownerEl.value;
  if (drugEl) state.turfEditor.drugProduct = drugEl.value.trim();
  if (incomeEl) state.turfEditor.hourlyIncome = incomeEl.value;
  if (drugsEl) state.turfEditor.allowsDrugSales = drugsEl.checked;
}

function renderAdmin() {
  const admin = state.payload.admin;
  if (!admin) return empty('Admin režimas išjungtas', 'Neturi admin teisių.');
  const tab = state.adminTab || 'gangs';
  if (tab === 'turfs') setTimeout(initAdminMap, 0);
  else if (state.adminMap) destroyAdminMap();

  return `
    <div class="stack">
      <div class="card-header">
        <div class="title"><h2>Gang Admin</h2><p class="muted">Gaujos, turf apply/edit, karai, misijos · /gangadmin</p></div>
        ${pill('ADMIN', 'danger')}
      </div>

      <div class="grid grid-4">
        <div class="metric-card is-accent"><div class="metric-label">Gaujos</div><div class="metric">${admin.gangs.length}</div></div>
        <div class="metric-card"><div class="metric-label">Turf zonos</div><div class="metric">${(state.payload.territories || []).length}</div></div>
        <div class="metric-card"><div class="metric-label">Aktyvūs karai</div><div class="metric">${admin.activeWars.length}</div></div>
        <div class="metric-card"><div class="metric-label">Audit</div><div class="metric">${admin.recentAudit.length}</div></div>
      </div>

      <div class="admin-tabs">
        <button type="button" class="button ${tab === 'gangs' ? 'primary' : ''}" data-action="admin-tab" data-tab="gangs">Gaujos</button>
        <button type="button" class="button ${tab === 'turfs' ? 'primary' : ''}" data-action="admin-tab" data-tab="turfs">Turf apply / edit</button>
        <button type="button" class="button ${tab === 'ops' ? 'primary' : ''}" data-action="admin-tab" data-tab="ops">Karai / Misijos</button>
      </div>

      ${tab === 'gangs' ? renderAdminGangs(admin) : ''}
      ${tab === 'turfs' ? renderAdminTurfs(admin) : ''}
      ${tab === 'ops' ? renderAdminOps(admin) : ''}
    </div>`;
}

/* ------------------------------------------------------------
   MAIN RENDER
   ------------------------------------------------------------ */
const renderers = {
  overview: renderOverview,
  register: renderRegister,
  members: renderMembers,
  territories: renderTerritories,
  missions: renderMissions,
  finance: renderFinance,
  wars: renderWars,
  top: renderTop,
  settings: renderSettings,
  admin: renderAdmin,
};

function render() {
  if (!state.payload) return;
  renderNav();
  const pageMeta = availablePages().find((p) => p.key === state.page);
  title.textContent = pageMeta?.label || 'Pagrindinis';
  if (state.adminOnly) eyebrow.textContent = 'GANG ADMIN';
  else eyebrow.textContent = state.payload.organization ? 'SYNDICATE INTERFACE' : 'GUEST MODE';

  let preservedMap = null;
  if (state.page === 'territories' && state.map) {
    const live = document.querySelector('#territory-map');
    if (live && live._leaflet_id) {
      preservedMap = live;
      preservedMap.remove();
    }
  } else if (state.page !== 'territories' && state.map) {
    try { state.map.remove(); } catch (_) { /* ignore */ }
    state.map = null;
    state.mapLayers = {};
    state.mapMarkers = {};
  }

  if (!(state.page === 'admin' && state.adminTab === 'turfs') && state.adminMap) {
    destroyAdminMap();
  }

  content.innerHTML = (renderers[state.page] || renderOverview)();

  if (preservedMap && state.page === 'territories') {
    const host = document.querySelector('#territory-map');
    if (host) {
      host.replaceWith(preservedMap);
      setTimeout(() => state.map?.invalidateSize(), 30);
    }
  }
}

/* ------------------------------------------------------------
   MODALS
   ------------------------------------------------------------ */
function modal(html) {
  modalRoot.innerHTML = `<div class="modal-backdrop" data-action="dismiss-modal"><div class="modal" role="dialog">${html}</div></div>`;
}
function closeModal() { modalRoot.innerHTML = ''; }

function permissionEntries(groups) {
  return Object.entries(groups || {}).map(([groupKey, group]) => {
    if (Array.isArray(group)) return { key: groupKey, label: groupKey, permissions: group };
    return { key: groupKey, label: group.label || groupKey, permissions: group.permissions || [] };
  });
}

function inviteModal() {
  const roles = state.payload.organization.roles || [];
  modal(`
    <div class="modal-header"><h2>Pakviesti narį</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
    <form id="invite-form" class="stack">
      <div class="field"><label>Server ID</label><input name="targetSource" type="number" min="1" required placeholder="Pvz. 42"></div>
      <div class="field"><label>Pradinis rangas</label>
        <select name="roleKey">${roles.map((r) => `<option value="${esc(r.role_key)}">${esc(r.label)}</option>`).join('')}</select>
      </div>
      <button class="button primary wide">${ICONS.mail}Siųsti kvietimą</button>
    </form>`);
}

function roleModal(citizenid) {
  const roles = state.payload.organization.roles || [];
  modal(`
    <div class="modal-header"><h2>Keisti rangą</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
    <form id="role-form" class="stack">
      <input type="hidden" name="citizenid" value="${esc(citizenid)}">
      <div class="field"><label>Rangas</label>
        <select name="roleKey">${roles.map((r) => `<option value="${esc(r.role_key)}">${esc(r.label)}</option>`).join('')}</select>
      </div>
      <button class="button primary wide">Išsaugoti</button>
    </form>`);
}

function respModal(citizenid) {
  const catalog = state.payload.organization.responsibilityCatalog || {};
  const current = new Set(
    (state.payload.organization.responsibilities || [])
      .filter((r) => r.citizenid === citizenid)
      .map((r) => r.responsibility_key)
  );
  modal(`
    <div class="modal-header"><h2>Atsakomybės</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
    <form id="resp-form" class="stack">
      <input type="hidden" name="citizenid" value="${esc(citizenid)}">
      <div class="stack">
        ${Object.entries(catalog).map(([key, def]) => `
          <label class="list-item">
            <span><strong>${esc(def.label || key)}</strong><br><small class="muted">${esc((def.extraPermissions || []).join(', '))}</small></span>
            <input type="checkbox" name="resp" value="${esc(key)}" ${current.has(key) ? 'checked' : ''}>
          </label>`).join('')}
      </div>
      <button class="button primary wide">Išsaugoti</button>
    </form>`);
}

function roleConfigModal(roleKey = '') {
  const role = (state.payload.organization.roles || []).find((entry) => entry.role_key === roleKey);
  const selected = role?.permissions?.wildcard
    ? new Set(['*'])
    : new Set(Object.keys(role?.permissions?.set || {}).filter((key) => role.permissions.set[key]));
  const groups = permissionEntries(state.payload.permissionGroups || state.payload.organization?.permissionGroups || {});
  modal(`
    <div class="modal-header"><h2>${role ? 'Redaguoti rangą' : 'Naujas rangas'}</h2>
      <button class="close-button" data-action="dismiss-modal">×</button></div>
    <form id="role-config-form" class="stack">
      <div class="grid grid-2">
        <div class="field"><label>Raktas</label>
          <input name="roleKey" value="${esc(role?.role_key || '')}" ${role ? 'readonly' : ''} required></div>
        <div class="field"><label>Pavadinimas</label>
          <input name="label" value="${esc(role?.label || '')}" required></div>
      </div>
      <div class="field"><label>Prioritetas</label>
        <input name="priority" type="number" min="0" max="99" value="${esc(role?.priority || 10)}" required></div>
      <div class="stack">${groups.map((group) => `
        <div class="settings-section" style="padding:12px 14px">
          <h3 style="text-transform:capitalize">${esc(group.label)}</h3>
          <div class="grid grid-2">${group.permissions.map((permission) => `
            <label class="list-item">
              <span>${esc(permission)}</span>
              <input type="checkbox" name="permission" value="${esc(permission)}" ${selected.has(permission) || selected.has('*') ? 'checked' : ''}>
            </label>`).join('')}
          </div>
        </div>`).join('')}</div>
      <div class="button-row"><button class="button primary">Išsaugoti</button>
        ${role && !['boss', 'underboss', 'lieutenant', 'member', 'prospect'].includes(role.role_key)
          ? `<button type="button" class="button danger" data-action="delete-role" data-role-key="${esc(role.role_key)}">Pašalinti</button>` : ''}
      </div>
    </form>`);
}

function treasuryModal(operation) {
  modal(`
    <div class="modal-header"><h2>${operation === 'deposit' ? 'Įnešti į iždą' : 'Išimti iš iždo'}</h2>
      <button class="close-button" data-action="dismiss-modal">×</button></div>
    <form id="treasury-form" class="stack">
      <input type="hidden" name="operation" value="${esc(operation)}">
      <p class="muted small">${operation === 'deposit'
        ? 'Suma bus nuskaičiuota iš tavo banko sąskaitos.'
        : 'Suma bus pervesta į tavo banko sąskaitą.'}</p>
      <div class="field"><label>Suma</label>
        <input name="amount" type="number" min="1" max="1000000" required placeholder="Pvz. 5000">
      </div>
      <button class="button primary wide">${operation === 'deposit' ? ICONS.arrowUp + 'Įnešti iš banko' : ICONS.arrowDown + 'Išimti į banką'}</button>
    </form>`);
}

function gangInfoModal() {
  const gang = state.payload.organization.gang;
  modal(`
    <div class="modal-header"><h2>Gaujos info</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
    <form id="gang-info-form" class="stack">
      <div class="field"><label>Pavadinimas</label>
        <input name="label" value="${esc(gang.label)}" maxlength="96" required></div>
      <div class="field"><label>Profilinės nuoroda (URL)</label>
        <input name="avatarUrl" type="url" value="${esc(gang.avatar_url || '')}" maxlength="512"
          placeholder="https://i.imgur.com/...">
        <p class="muted small" style="margin-top:6px">Palik tuščią, jei nori grįžti prie inicialų. Rekomenduojama Imgur / Discord CDN nuoroda.</p>
      </div>
      <div class="field"><label>Spalva</label>
        <input type="hidden" name="colorHex" id="edit-color" value="${esc(gang.color_hex || '#A855F7')}">
        <div class="swatches">${PALETTE.map((hex) =>
          `<button type="button" class="swatch ${(gang.color_hex || '').toUpperCase() === hex.toUpperCase() ? 'is-active' : ''}"
            data-action="pick-edit-color" data-color="${hex}" style="background:${hex};box-shadow:0 0 12px ${hex}55"></button>`
        ).join('')}</div>
      </div>
      <button class="button primary wide">Išsaugoti</button>
    </form>`);
}

function readyModal() {
  modal(`
    <div class="modal-header"><h2>Party rolė</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
    <p class="muted small" style="margin-bottom:12px">Įsijunk rolę — kai gaujos nariai bus pasiruošę, misija prasidės.</p>
    <div class="grid grid-2">${Object.entries(state.payload.missionRoles || {})
      .filter(([key]) => key !== 'leader')
      .map(([key, role]) => `<button class="button" data-action="toggle-ready" data-role="${esc(key)}">${esc(role.label)}</button>`)
      .join('')}
    </div>`);
}

function treatyModal() {
  const ownId = Number(state.payload.organization.gang.gang_id);
  modal(`
    <div class="modal-header"><h2>Nauja sutartis</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
    <form id="treaty-form" class="stack">
      <div class="field"><label>Kita gauja</label>
        <select name="targetGangId">
          ${(state.payload.gangs || []).filter((g) => Number(g.id) !== ownId)
            .map((g) => `<option value="${g.id}">${esc(g.label)}</option>`).join('')}
        </select>
      </div>
      <div class="field"><label>Tipas</label>
        <select name="treatyType">
          ${Object.entries(state.payload.treatyTypes || {}).map(([key, def]) =>
            `<option value="${esc(key)}">${esc(def.label)}</option>`).join('')}
        </select>
      </div>
      <div class="field"><label>Trukmė (val.)</label>
        <input name="durationHours" type="number" min="0" max="720" value="72">
      </div>
      <button class="button primary wide">${ICONS.handshake}Siūlyti sutartį</button>
    </form>`);
}

function warModal() {
  const ownId = Number(state.payload.organization.gang.gang_id);
  const territories = (state.payload.territories || [])
    .filter((t) => t.ownerGangId && Number(t.ownerGangId) !== ownId && t.type !== 'racket');
  modal(`
    <div class="modal-header"><h2>Skelbti karą</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
    <form id="war-form" class="stack">
      <div class="field"><label>Teritorija ir gynėjas</label>
        <select name="territory">
          ${territories.map((t) => `<option value="${esc(t.id)}" data-owner="${t.ownerGangId}">${esc(t.label)} · ${esc(t.ownerLabel)}</option>`).join('')}
        </select>
      </div>
      <p class="muted small">Reikalingas aktyvus Enemy statusas. Roster užrakinamas pasibaigus pasiruošimui.</p>
      <button class="button primary wide" ${territories.length ? '' : 'disabled'}>${ICONS.wars}Skelbti kampaniją</button>
    </form>`);
}

async function openWarDetails(warId) {
  const result = await api('getWarDetails', { warId: Number(warId) });
  const war = result?.war || result;
  if (!war || !war.id) {
    toast(fail(result) || 'Nepavyko gauti karo detalių.', 'error');
    return;
  }
  const ownId = Number(state.payload.organization.gang.gang_id);
  const members = state.payload.organization.members || [];
  const rosterSet = new Set((war.roster || []).filter((r) => Number(r.gang_id) === ownId).map((r) => r.citizenid));
  const canRoster = hasPermission('wars.manage_roster') && war.state === 'preparation';
  modal(`
    <div class="modal-header"><h2>Karas #${esc(war.id)}</h2><button class="close-button" data-action="dismiss-modal">×</button></div>
    <div class="stack">
      <p class="muted small">${esc(war.territory_id)} · ${esc(war.state)} · Rezultatas ${esc(war.attacker_score)}:${esc(war.defender_score)}</p>
      <h3>Tikslai</h3>
      <div class="list">
        ${(war.objectives || []).length ? war.objectives.map((o) => `
          <div class="list-item">
            <div class="list-item-main"><strong>${esc(o.objective_key)}</strong>
              <small>${esc(o.objective_type)} · ${esc(o.state)} · A${esc(o.attacker_points)}/D${esc(o.defender_points)}</small>
            </div>
          </div>`).join('') : empty('Tikslų nėra', 'Kol nėra objectives, karas neaktyvus.')}
      </div>
      <h3>Roster (${rosterSet.size})</h3>
      <div class="list">
        ${members.map((m) => `
          <label class="list-item">
            <span><strong>${esc(m.display_name)}</strong><br><small class="muted">${esc(m.citizenid)}</small></span>
            <input type="checkbox" data-war-roster="${war.id}" data-citizen="${esc(m.citizenid)}"
              ${rosterSet.has(m.citizenid) ? 'checked' : ''} ${canRoster ? '' : 'disabled'}>
          </label>`).join('')}
      </div>
      ${canRoster ? '<p class="muted small">Pažymėk narius pasiruošimo fazėje.</p>' : '<p class="muted small">Roster redaguojamas tik preparation fazėje.</p>'}
    </div>`);
}

/* ------------------------------------------------------------
   EVENT DELEGATION
   ------------------------------------------------------------ */
document.addEventListener('click', async (event) => {
  const target = event.target.closest('[data-page],[data-action],[data-tab]');
  if (!target) return;

  if (target.dataset.tab && state.page === 'wars') {
    state.warsTab = target.dataset.tab;
    render();
    return;
  }

  if (target.dataset.page) {
    state.page = target.dataset.page;
    render();
    return;
  }

  const action = target.dataset.action;

  if (action === 'close') return api('close');
  if (action === 'refresh') return api('refresh');

  if (action === 'dismiss-modal') {
    if (event.target === target || target.classList.contains('close-button')) closeModal();
    return;
  }

  if (action === 'pick-color') {
    state.createColor = target.dataset.color;
    const input = document.querySelector('#create-color');
    if (input) input.value = state.createColor;
    document.querySelectorAll('.swatch[data-action="pick-color"]').forEach((node) => {
      node.classList.toggle('is-active', node.dataset.color.toUpperCase() === state.createColor.toUpperCase());
    });
    updateRegisterPreview();
    return;
  }

  if (action === 'pick-type') {
    state.createType = target.dataset.type;
    document.querySelectorAll('.type-card[data-action="pick-type"]').forEach((node) => {
      node.classList.toggle('is-active', node.dataset.type === state.createType);
    });
    updateRegisterPreview();
    return;
  }

  if (action === 'pick-edit-color') {
    const input = document.querySelector('#edit-color');
    if (input) input.value = target.dataset.color;
    document.querySelectorAll('.swatch[data-action="pick-edit-color"]').forEach((node) => {
      node.classList.toggle('is-active', node.dataset.color.toUpperCase() === target.dataset.color.toUpperCase());
    });
    return;
  }

  if (action === 'invite-modal') return inviteModal();
  if (action === 'role-modal') return roleModal(target.dataset.citizen);
  if (action === 'resp-modal') return respModal(target.dataset.citizen);
  if (action === 'role-config-modal') return roleConfigModal(target.dataset.roleKey || '');
  if (action === 'treasury-modal') return treasuryModal(target.dataset.operation);
  if (action === 'gang-info-modal') return gangInfoModal();
  if (action === 'ready-modal') return readyModal();
  if (action === 'treaty-modal') return treatyModal();
  if (action === 'war-modal') return warModal();

  if (action === 'select-territory') {
    state.selectedTerritoryId = target.dataset.id;
    render();
    return;
  }
  if (action === 'toggle-turf-filter') {
    const type = target.dataset.type;
    if (type && state.territoryFilters[type] !== undefined) {
      state.territoryFilters[type] = !state.territoryFilters[type];
      render();
    }
    return;
  }
  if (action === 'set-waypoint') {
    const territory = (state.payload.territories || []).find((t) => t.id === target.dataset.id);
    const center = territoryCenter(territory);
    if (!center) return toast('Nepavyko rasti turf centro.', 'error');
    const result = await api('setWaypoint', center);
    toast(result.ok ? 'GPS nustatytas.' : fail(result), result.ok ? 'success' : 'error');
    return;
  }
  if (action === 'accept-invite') {
    const result = await api('acceptInvite', { inviteId: Number(target.dataset.id) });
    toast(result.ok ? 'Kvietimas priimtas.' : fail(result), result.ok ? 'success' : 'error');
  } else if (action === 'kick-member') {
    const result = await api('kickMember', { citizenid: target.dataset.citizen });
    toast(result.ok ? 'Narys pašalintas.' : fail(result), result.ok ? 'success' : 'error');
  } else if (action === 'delete-role') {
    const result = await api('deleteRole', { roleKey: target.dataset.roleKey });
    toast(result.ok ? 'Rangas pašalintas.' : fail(result), result.ok ? 'success' : 'error');
    if (result.ok) closeModal();
  } else if (action === 'toggle-ready') {
    const result = await api('toggleMissionReady', { roleKey: target.dataset.role });
    toast(result.ready ? 'Party būsena aktyvi.' : 'Party būsena išjungta.', result.ok ? 'success' : 'error');
    closeModal();
  } else if (action === 'start-mission') {
    const difficulty = state.missionDifficulty[target.dataset.mission]
      || document.querySelector(`[data-mission-difficulty="${CSS.escape(target.dataset.mission)}"]`)?.value
      || 'easy';
    const result = await api('startMission', { missionKey: target.dataset.mission, difficulty });
    toast(result.ok ? 'Operacija pradėta.' : fail(result), result.ok ? 'success' : 'error');
  } else if (action === 'quick-start-mission') {
    const result = await api('startMission', { missionKey: target.dataset.mission, difficulty: 'easy' });
    toast(result.ok ? 'Operacija pradėta.' : fail(result), result.ok ? 'success' : 'error');
  } else if (action === 'resolve-treaty') {
    const result = await api('resolveTreaty', {
      treatyId: Number(target.dataset.id), accept: target.dataset.accept === 'true',
    });
    toast(result.ok ? 'Sutartis atnaujinta.' : fail(result), result.ok ? 'success' : 'error');
  } else if (action === 'break-treaty') {
    const result = await api('breakTreaty', { treatyId: Number(target.dataset.id) });
    toast(result.ok ? 'Sutartis nutraukta.' : fail(result), result.ok ? 'success' : 'error');
  } else if (action === 'admin-cancel-war') {
    const result = await api('adminCancelWar', { warId: Number(target.dataset.id) });
    toast(result.ok ? 'Karas atšauktas.' : fail(result), result.ok ? 'success' : 'error');
  } else if (action === 'admin-tab') {
    state.adminTab = target.dataset.tab || 'gangs';
    render();
  } else if (action === 'admin-turf-new') {
    resetTurfEditor(null);
    state.adminTab = 'turfs';
    render();
  } else if (action === 'admin-turf-edit') {
    const territory = (state.payload.territories || []).find((t) => t.id === target.dataset.id);
    if (!territory) return toast('Teritorija nerasta.', 'error');
    resetTurfEditor(territory);
    state.adminTab = 'turfs';
    render();
  } else if (action === 'admin-turf-undo') {
    state.turfEditor.vertices.pop();
    syncAdminDrawLayer();
    render();
  } else if (action === 'admin-turf-clear') {
    state.turfEditor.vertices = [];
    syncAdminDrawLayer();
    render();
  } else if (action === 'admin-turf-add-here') {
    const coords = await api('adminGetPlayerCoords');
    if (!coords?.ok) return toast('Nepavyko gauti pozicijos.', 'error');
    state.turfEditor.vertices.push({ x: Number(coords.x), y: Number(coords.y) });
    syncAdminDrawLayer();
    render();
  } else if (action === 'admin-turf-apply') {
    readTurfEditorForm();
    const editor = state.turfEditor;
    if (!editor.id || editor.id.length < 3) return toast('Neteisingas turf ID.', 'error');
    if (!editor.label || editor.label.length < 3) return toast('Įrašyk pavadinimą.', 'error');
    if (!editor.vertices || editor.vertices.length < 3) return toast('Reikia bent 3 poligono taškų.', 'error');
    const bonuses = {};
    const income = Number(editor.hourlyIncome);
    if (Number.isFinite(income) && income > 0) bonuses.hourlyIncome = income;
    const result = await api('adminUpsertTerritory', {
      id: editor.id,
      label: editor.label,
      type: editor.type,
      vertices: editor.vertices,
      ownerGangId: editor.ownerGangId === '' ? 0 : Number(editor.ownerGangId),
      allowsDrugSales: editor.allowsDrugSales === true,
      drugProduct: editor.drugProduct || null,
      bonuses,
    });
    toast(result.ok ? 'Turf pritaikytas.' : fail(result), result.ok ? 'success' : 'error');
    if (result.ok && result.territories) {
      state.payload.territories = result.territories;
      const updated = result.territories.find((t) => t.id === editor.id);
      resetTurfEditor(updated || null);
      render();
    }
  } else if (action === 'admin-turf-reset-owner') {
    readTurfEditorForm();
    if (!state.turfEditor.id || state.turfEditor.isNew) return;
    const result = await api('adminResetTerritory', { territoryId: state.turfEditor.id });
    toast(result.ok ? 'Savininkas nunulintas.' : fail(result), result.ok ? 'success' : 'error');
  } else if (action === 'admin-turf-delete') {
    readTurfEditorForm();
    if (!state.turfEditor.id || state.turfEditor.isNew || state.turfEditor.stock) {
      return toast('Stock zonų trinti negalima — tik custom.', 'error');
    }
    if (!window.confirm(`Ištrinti turf „${state.turfEditor.id}“?`)) return;
    const result = await api('adminDeleteTerritory', { territoryId: state.turfEditor.id });
    toast(result.ok ? 'Turf ištrintas.' : fail(result), result.ok ? 'success' : 'error');
    if (result.ok) {
      if (result.territories) state.payload.territories = result.territories;
      resetTurfEditor(null);
      render();
    }
  } else if (action === 'admin-delete-gang') {
    const gangId = Number(target.dataset.id);
    const confirmText = window.prompt(`Ištrinti gaują „${target.dataset.label || gangId}“?\nĮrašyk DELETE-${gangId}`);
    if (!confirmText) return;
    const result = await api('adminDeleteGang', { gangId, confirm: confirmText });
    toast(result.ok ? 'Gauja archyvuota.' : fail(result), result.ok ? 'success' : 'error');
  } else if (action === 'war-details') {
    await openWarDetails(target.dataset.id);
  }
});

document.addEventListener('change', async (event) => {
  if (event.target.matches('[data-mission-difficulty]')) {
    state.missionDifficulty[event.target.dataset.missionDifficulty] = event.target.value;
    // re-render so the mission-reward figure updates
    render();
  }
  if (event.target.matches('[data-admin-gang-status]')) {
    const result = await api('adminSetGangStatus', {
      gangId: Number(event.target.dataset.adminGangStatus), status: event.target.value,
    });
    toast(result.ok ? 'Statusas pakeistas.' : fail(result), result.ok ? 'success' : 'error');
  }
  if (event.target.matches('[data-admin-mission]')) {
    const result = await api('adminSetMissionState', {
      missionKey: event.target.dataset.adminMission, enabled: event.target.checked,
    });
    toast(result.ok ? 'Misijos būsena pakeista.' : fail(result), result.ok ? 'success' : 'error');
  }
  if (event.target.matches('[data-admin-territory-owner]')) {
    const result = await api('adminSetTerritoryOwner', {
      territoryId: event.target.dataset.adminTerritoryOwner,
      gangId: event.target.value === '' ? null : Number(event.target.value),
    });
    toast(result.ok ? 'Teritorijos kontrolė pakeista.' : fail(result), result.ok ? 'success' : 'error');
  }
  if (event.target.matches('[data-war-roster]')) {
    const result = await api('manageWarRoster', {
      warId: Number(event.target.dataset.warRoster),
      citizenid: event.target.dataset.citizen,
      enabled: event.target.checked,
    });
    toast(result.ok ? 'Roster atnaujintas.' : fail(result), result.ok ? 'success' : 'error');
    if (!result.ok) event.target.checked = !event.target.checked;
  }
});

function updateRegisterPreview() {
  const label = state.createLabel || 'Nauja gauja';
  const emblem = document.querySelector('#register-emblem');
  const labelEl = document.querySelector('#register-preview-label');
  const metaEl = document.querySelector('#register-preview-meta');
  if (emblem) {
    emblem.style.background = state.createColor;
    emblem.style.color = contrastColor(state.createColor);
    emblem.innerHTML = `<span>${esc(initials(label))}</span>`;
  }
  if (labelEl) labelEl.textContent = label;
  if (metaEl) metaEl.textContent = `${gangTypeLabel(state.createType)} · ${state.createColor}`;
}

document.addEventListener('input', (event) => {
  if (event.target.form?.id === 'create-gang-form' && event.target.name === 'label') {
    state.createLabel = event.target.value;
    const nameInput = event.target.form.elements.name;
    if (nameInput && !state.createTouchedName) {
      nameInput.value = slugify(event.target.value);
      state.createName = nameInput.value;
    }
    updateRegisterPreview();
  }
  if (event.target.form?.id === 'create-gang-form' && event.target.name === 'name') {
    state.createTouchedName = true;
    state.createName = event.target.value;
  }
});

document.addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.target;
  const data = Object.fromEntries(new FormData(form).entries());
  let result;

  if (form.id === 'create-gang-form') {
    result = await api('createGang', {
      label: data.label,
      name: data.name || slugify(data.label),
      gangType: state.createType || data.gangType,
      colorHex: data.colorHex || state.createColor,
    });
    toast(result.ok ? 'Gauja sukurta.' : fail(result), result.ok ? 'success' : 'error');
    return;
  }
  if (form.id === 'invite-form') {
    result = await api('inviteMember', { targetSource: Number(data.targetSource), roleKey: data.roleKey });
  }
  if (form.id === 'role-form') result = await api('setMemberRole', data);
  if (form.id === 'role-config-form') {
    result = await api('saveRole', {
      roleKey: data.roleKey,
      label: data.label,
      priority: Number(data.priority),
      permissions: new FormData(form).getAll('permission'),
    });
  }
  if (form.id === 'treasury-form') {
    result = await api('treasury', { operation: data.operation, amount: Number(data.amount) });
  }
  if (form.id === 'gang-info-form') {
    result = await api('updateGangInfo', {
      label: data.label,
      colorHex: data.colorHex,
      avatarUrl: data.avatarUrl || '',
    });
  }
  if (form.id === 'resp-form') {
    const selected = new Set(new FormData(form).getAll('resp'));
    const catalog = Object.keys(state.payload.organization.responsibilityCatalog || {});
    const current = new Set(
      (state.payload.organization.responsibilities || [])
        .filter((r) => r.citizenid === data.citizenid)
        .map((r) => r.responsibility_key)
    );
    let ok = true;
    let lastFail = null;
    for (const key of catalog) {
      const enabled = selected.has(key);
      if (enabled === current.has(key)) continue;
      const response = await api('setResponsibility', {
        citizenid: data.citizenid, key, enabled,
      });
      if (!response.ok) { ok = false; lastFail = response; }
    }
    result = ok ? { ok: true } : lastFail;
  }
  if (form.id === 'treaty-form') {
    result = await api('proposeTreaty', {
      targetGangId: Number(data.targetGangId),
      treatyType: data.treatyType,
      durationHours: Number(data.durationHours),
      terms: {},
    });
  }
  if (form.id === 'war-form') {
    const option = form.elements.territory.selectedOptions[0];
    result = await api('declareWar', {
      territoryId: option.value, defenderGangId: Number(option.dataset.owner),
    });
  }
  if (result) toast(result.ok ? 'Veiksmas atliktas.' : fail(result), result.ok ? 'success' : 'error');
  if (result?.ok) closeModal();
});

/* ------------------------------------------------------------
   CLOCK
   ------------------------------------------------------------ */
function tickClock() {
  if (!clockEl) return;
  const now = new Date();
  const hh = String(now.getHours()).padStart(2, '0');
  const mm = String(now.getMinutes()).padStart(2, '0');
  clockEl.textContent = `${hh}:${mm}`;
}

/* ------------------------------------------------------------
   MISSION PREP PROGRESS (bottom bar, jail-style)
   ------------------------------------------------------------ */
const missionProgressEl = document.getElementById('mission-progress');
const missionProgressTitle = document.getElementById('mission-progress-title');
const missionProgressTime = document.getElementById('mission-progress-time');
const missionProgressFill = document.getElementById('mission-progress-fill');
let missionProgressEndsAt = 0;
let missionProgressDuration = 0;
let missionProgressTimer = null;

function renderMissionProgress() {
  if (!missionProgressEndsAt || !missionProgressDuration) return;
  const leftMs = Math.max(0, missionProgressEndsAt - Date.now());
  const leftSec = Math.ceil(leftMs / 1000);
  const done = 1 - leftMs / missionProgressDuration;
  if (missionProgressTime) missionProgressTime.textContent = leftSec > 0 ? `${leftSec}s` : '0s';
  if (missionProgressFill) missionProgressFill.style.width = `${Math.min(100, Math.max(0, done * 100))}%`;
}

function showMissionProgress(data) {
  if (missionProgressTimer) {
    clearInterval(missionProgressTimer);
    missionProgressTimer = null;
  }
  missionProgressDuration = Math.max(1, Number(data.durationMs) || 5000);
  missionProgressEndsAt = Date.now() + missionProgressDuration;
  if (missionProgressTitle) missionProgressTitle.textContent = data.label || 'Ruošiama...';
  if (missionProgressFill) missionProgressFill.style.width = '0%';
  if (missionProgressEl) {
    missionProgressEl.classList.remove('hidden');
    missionProgressEl.setAttribute('aria-hidden', 'false');
  }
  renderMissionProgress();
  missionProgressTimer = setInterval(renderMissionProgress, 100);
}

function hideMissionProgress() {
  if (missionProgressTimer) {
    clearInterval(missionProgressTimer);
    missionProgressTimer = null;
  }
  missionProgressEndsAt = 0;
  missionProgressDuration = 0;
  if (missionProgressFill) missionProgressFill.style.width = '0%';
  if (missionProgressEl) {
    missionProgressEl.classList.add('hidden');
    missionProgressEl.setAttribute('aria-hidden', 'true');
  }
}

/* ------------------------------------------------------------
   NUI MESSAGE BRIDGE
   ------------------------------------------------------------ */
window.addEventListener('message', (event) => {
  const message = event.data || {};
  if (message.action === 'open') {
    state.payload = message.payload;
    state.adminOnly = message.adminOnly === true;
    if (message.startPage) state.page = message.startPage;
    else if (state.adminOnly) state.page = 'admin';
    else if (state.payload.organization && (state.page === 'register' || !state.page)) state.page = 'overview';
    if (state.adminOnly) state.adminTab = state.adminTab || 'turfs';
    tablet.classList.remove('is-hidden');
    tablet.setAttribute('aria-hidden', 'false');
    document.documentElement.style.background = 'transparent';
    document.body.style.background = 'transparent';
    tickClock();
    if (state.clockTimer) clearInterval(state.clockTimer);
    state.clockTimer = setInterval(tickClock, 30000);
    render();
  } else if (message.action === 'close') {
    tablet.classList.add('is-hidden');
    tablet.setAttribute('aria-hidden', 'true');
    document.documentElement.style.background = 'transparent';
    document.body.style.background = 'transparent';
    if (state.clockTimer) { clearInterval(state.clockTimer); state.clockTimer = null; }
    destroyAdminMap();
    closeModal();
    state.adminOnly = false;
  } else if (message.action === 'missionProgressShow') {
    showMissionProgress(message);
  } else if (message.action === 'missionProgressHide') {
    hideMissionProgress();
  } else if (message.action === 'territoriesUpdated' && state.payload) {
    state.payload.territories = message.territories;
    if (state.page === 'territories') {
      if (state.map) {
        (state.payload.territories || []).forEach((t) => {
          const poly = state.mapLayers[t.id];
          if (poly) animatePolygonStyle(poly, turfBaseStyle(t, t.id === state.selectedTerritoryId), 560);
          const marker = state.mapMarkers[t.id];
          if (marker) {
            marker.setIcon(L.divIcon({
              className: 'turf-marker-wrap',
              html: `<div class="turf-marker" style="--turf:${esc(turfDisplayColor(t))}"><span></span></div>`,
              iconSize: [14, 14],
              iconAnchor: [7, 7],
            }));
          }
        });
      }
      render();
    } else if (state.page === 'admin' && state.adminTab === 'turfs') {
      render();
    }
  }
});

window.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') api('close');
});

document.documentElement.style.background = 'transparent';
document.body.style.background = 'transparent';
tablet.classList.add('is-hidden');
tablet.setAttribute('aria-hidden', 'true');
closeModal();
