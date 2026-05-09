const tablet = document.getElementById('tablet');
const registerPanel = document.getElementById('registerPanel');
const gangPanel = document.getElementById('gangPanel');
const gangTitle = document.getElementById('gangTitle');
const gangMeta = document.getElementById('gangMeta');
const gangName = document.getElementById('gangName');
const gangType = document.getElementById('gangType');
const primaryColor = document.getElementById('primaryColor');
const secondaryColor = document.getElementById('secondaryColor');
const colorWarn = document.getElementById('colorWarn');
const turfList = document.getElementById('turfList');
let lastState = null;

function resourceName() {
  try { if (typeof GetParentResourceName === 'function') return GetParentResourceName(); } catch (e) {}
  return 'fivempro_gangs';
}
function post(endpoint, data) {
  return fetch(`https://${resourceName()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
  }).then((r) => r.json());
}

function safe(s) {
  const d = document.createElement('div');
  d.textContent = s == null ? '' : String(s);
  return d.innerHTML;
}

function renderPalette(palette, usage) {
  primaryColor.innerHTML = '';
  secondaryColor.innerHTML = '';
  (palette || []).forEach((hex) => {
    const used = Number((usage || {})[String(hex).toUpperCase()] || 0);
    const txt = used > 0 ? `${hex} (USED ${used})` : hex;
    const o1 = document.createElement('option');
    o1.value = hex; o1.textContent = txt;
    primaryColor.appendChild(o1);
    const o2 = document.createElement('option');
    o2.value = hex; o2.textContent = txt;
    secondaryColor.appendChild(o2);
  });
}

function renderTurfs(state) {
  turfList.innerHTML = '';
  const turfs = state.turfs || [];
  turfs.forEach((t) => {
    const div = document.createElement('div');
    div.className = 'turf';
    const owner = t.owner_name || 'Unclaimed';
    div.style.background = t.owner_color_hex ? `${t.owner_color_hex}55` : 'rgba(31,41,55,0.6)';
    div.innerHTML = `<strong>${safe(t.turf_label || t.turf_id)}</strong><div class="owner">${safe(owner)} | Progress ${Number(t.progress||0)}%</div>`;
    div.onclick = () => post('gangs:setWaypoint', { turfId: t.turf_id });
    turfList.appendChild(div);
  });
}

function render(state) {
  lastState = state;
  tablet.classList.remove('hidden');
  gangType.innerHTML = '';
  Object.entries(state.gangTypes || {}).forEach(([k, v]) => {
    const o = document.createElement('option');
    o.value = k;
    o.textContent = `${v} (${k})`;
    gangType.appendChild(o);
  });
  renderPalette(state.palette || [], state.colorUsage || {});
  renderTurfs(state);
  if (!state.hasGang) {
    registerPanel.classList.remove('hidden');
    gangPanel.classList.add('hidden');
  } else {
    registerPanel.classList.add('hidden');
    gangPanel.classList.remove('hidden');
    gangTitle.textContent = `${state.gang.name} (${state.gang.gang_type})`;
    gangMeta.textContent = `Rep: ${state.gang.reputation || 0} | Heat: ${state.gang.heat || 0} | Colors: ${state.gang.color_hex || '-'} / ${state.gang.secondary_color_hex || '-'}`;
  }
}

function refreshWarn() {
  if (!lastState) return;
  const usage = lastState.colorUsage || {};
  const used = Number(usage[String(primaryColor.value || '').toUpperCase()] || 0) > 0;
  colorWarn.classList.toggle('hidden', !used);
  colorWarn.textContent = used ? `Gang color ${primaryColor.value} is already used. You can still choose it.` : '';
}
primaryColor.addEventListener('change', refreshWarn);

window.addEventListener('message', (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === 'open') render(d.payload || {});
  if (d.action === 'close') tablet.classList.add('hidden');
});

document.getElementById('btnClose').onclick = () => post('gangs:close', {});
document.getElementById('btnRefresh').onclick = () => post('gangs:refresh', {}).then((res) => res && res.ok && render(res));
document.getElementById('btnCreate').onclick = () => {
  const payload = {
    name: gangName.value.trim(),
    gangType: gangType.value,
    colorHex: primaryColor.value,
    secondaryColorHex: secondaryColor.value,
  };
  post('gangs:createGang', payload).then(() => post('gangs:refresh', {}).then((res) => res && res.ok && render(res)));
};

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !tablet.classList.contains('hidden')) {
    e.preventDefault();
    post('gangs:close', {});
  }
});
