const app = document.getElementById('app');
const titleEl = document.getElementById('title');
const vehicleListEl = document.getElementById('vehicleList');
const carsEl = document.getElementById('cars');
const selectedNameEl = document.getElementById('selectedName');
const selectedFuelEl = document.getElementById('selectedFuel');
const selectedPlateEl = document.getElementById('selectedPlate');
const statMaxEl = document.getElementById('statMax');
const stat0100El = document.getElementById('stat0100');
const statBrakingEl = document.getElementById('statBraking');
const statTractionEl = document.getElementById('statTraction');
const statusLineEl = document.getElementById('statusLine');
const reclaimBtn = document.getElementById('reclaimBtn');

let state = {
  payload: null,
  selected: null,
};

function post(action, data = {}) {
  fetch(`https://${GetParentResourceName()}/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  });
}

function fmtMoney(n) {
  return `$${Number(n || 0).toLocaleString('en-US')}`;
}

function setStatusClass(el, kind) {
  el.classList.remove('ok', 'warn');
  if (kind === 'ok') el.classList.add('ok');
  else if (kind === 'warn') el.classList.add('warn');
}

function applySelectedToDom() {
  const v = state.selected;
  const fee = state.payload?.fee ?? 5000;
  if (!v) {
    selectedNameEl.textContent = '-';
    selectedFuelEl.textContent = '-';
    selectedPlateEl.textContent = '-';
    statMaxEl.textContent = '0';
    stat0100El.textContent = '0.0';
    statBrakingEl.textContent = '0';
    statTractionEl.textContent = '0';
    statusLineEl.textContent = '-';
    setStatusClass(statusLineEl, null);
    reclaimBtn.disabled = true;
    return;
  }

  selectedNameEl.textContent = v.displayName || v.model;
  selectedFuelEl.textContent = `${v.fuel ?? 0}%`;
  selectedPlateEl.textContent = v.plate || '';
  statMaxEl.textContent = v.stats?.maxKmh ?? 0;
  stat0100El.textContent = v.stats?.zeroToHundred ?? 0;
  statBrakingEl.textContent = v.stats?.braking ?? 0;
  statTractionEl.textContent = v.stats?.traction ?? 0;
  statusLineEl.textContent = v.statusLabel || '-';
  setStatusClass(statusLineEl, 'warn');
  reclaimBtn.disabled = !v.canReclaim;
  reclaimBtn.textContent = `Atgauti už ${fmtMoney(fee)}`;

  post('selectVehicle', { plate: v.plate, model: v.model });
}

function setSelected(vehicle) {
  state.selected = vehicle;
  applySelectedToDom();
  renderVehicleList();
  renderCars();
}

function renderVehicleList() {
  vehicleListEl.innerHTML = '';
  const list = state.payload?.vehicles || [];
  if (list.length === 0) {
    const p = document.createElement('div');
    p.className = 'empty-msg';
    p.textContent = 'Nėra mašinų KMA (visos garaže arba sąrašas tuščias).';
    vehicleListEl.appendChild(p);
    return;
  }
  list.forEach((veh) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `veh-btn ${state.selected?.plate === veh.plate ? 'active' : ''}`;
    btn.innerHTML = `${veh.displayName || veh.model}<span class="veh-sub">${veh.plate} · ${veh.fuel}% kuras</span>`;
    btn.onclick = () => setSelected(veh);
    vehicleListEl.appendChild(btn);
  });
}

function renderCars() {
  carsEl.innerHTML = '';
  const list = state.payload?.vehicles || [];
  list.forEach((veh) => {
    const card = document.createElement('div');
    card.className = `car-card ${state.selected?.plate === veh.plate ? 'active' : ''}`;
    card.onclick = () => setSelected(veh);

    const img = document.createElement('img');
    img.className = 'car-img';
    img.src = veh.image;
    img.alt = veh.model;
    img.onerror = () => {
      img.src =
        'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="480" height="180"><rect width="100%" height="100%" fill="%2320262b"/><text x="50%" y="50%" fill="%23b3c1c8" font-family="Arial" font-size="20" dominant-baseline="middle" text-anchor="middle">No Image</text></svg>';
    };
    card.appendChild(img);

    const info = document.createElement('div');
    info.className = 'car-info';
    info.innerHTML = `<div>${veh.displayName || veh.model}</div><div class="car-plate">${veh.plate}</div><div style="margin-top:4px;font-size:0.75rem;color:#9ec5bf">${veh.statusLabel}</div>`;
    card.appendChild(info);

    carsEl.appendChild(card);
  });
}

function openUI(payload) {
  state.payload = payload;
  titleEl.textContent = payload?.title || 'KMA';
  const list = payload?.vehicles || [];
  state.selected = list[0] || null;
  renderVehicleList();
  renderCars();
  applySelectedToDom();
  app.classList.remove('hidden');
}

function closeUI() {
  app.classList.add('hidden');
  state = { payload: null, selected: null };
}

document.getElementById('closeBtn').onclick = () => post('close');
document.getElementById('rotateLeft').onclick = () => post('rotatePreview', { dir: -1 });
document.getElementById('rotateRight').onclick = () => post('rotatePreview', { dir: 1 });
reclaimBtn.onclick = () => {
  if (state.selected?.canReclaim && state.selected.plate) {
    post('reclaim', { plate: state.selected.plate });
  }
};

window.addEventListener(
  'keydown',
  (e) => {
    if (e.key === 'Escape' || e.code === 'Escape' || e.code === 'KeyP') {
      e.preventDefault();
      e.stopImmediatePropagation();
      post('close');
    }
  },
  true
);

window.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.action === 'open') {
    openUI(data.payload);
  } else if (data.action === 'close') {
    closeUI();
  }
});
