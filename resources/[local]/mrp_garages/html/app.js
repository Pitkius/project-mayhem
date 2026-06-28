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
const takeOutBtn = document.getElementById('takeOutBtn');

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

function setStatusClass(el, kind) {
  el.classList.remove('ok', 'warn');
  if (kind === 'ok') el.classList.add('ok');
  else if (kind === 'warn') el.classList.add('warn');
}

function applySelectedToDom() {
  const v = state.selected;
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
    takeOutBtn.disabled = true;
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
  setStatusClass(statusLineEl, v.canTakeOut ? 'ok' : 'warn');
  takeOutBtn.disabled = !v.canTakeOut;

  post('selectVehicle', { plate: v.plate, model: v.model });
}

function setSelected(vehicle) {
  state.selected = vehicle;
  applySelectedToDom();
  renderVehicleList();
  renderCars();
}

function vehicleImageCandidates(model, image) {
  const m = String(model || '')
    .trim()
    .toLowerCase()
    .replace(/^[\s\S]*\//g, '')
    .replace(/\s+/g, '');
  const slug = /^[a-z0-9_]+$/.test(m) ? m : 'sultan';
  const resName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mrp_garages';
  const base = `nui://${resName}/html/assets/vehicles`;
  const urls = [
    `https://docs.fivem.net/vehicles/${slug}.webp`,
    `nui://mrp_dealership/html/images/vehicles/${slug}.webp`,
    `${base}/${slug}.webp`,
    `${base}/${slug}.png`,
    `${base}/default.webp`,
  ];
  if (image && typeof image === 'string') {
    const rest = urls.filter((u) => u !== image);
    return [image, ...rest];
  }
  return urls;
}

function bindVehicleThumbnail(imgEl, model, image) {
  const urls = vehicleImageCandidates(model, image);
  let attempt = 0;
  imgEl.style.opacity = '1';
  imgEl.onerror = () => {
    attempt += 1;
    if (attempt < urls.length) {
      const next = urls[attempt];
      if (next.endsWith('.webp')) {
        imgEl.dataset.fallbackStep = '1';
      } else if (next.endsWith('.jpg')) {
        imgEl.dataset.fallbackStep = '2';
      }
      imgEl.src = next;
      return;
    }
    imgEl.onerror = null;
    imgEl.style.opacity = '0.75';
  };
  imgEl.src = urls[0];
}

function renderVehicleList() {
  vehicleListEl.innerHTML = '';
  const list = state.payload?.vehicles || [];
  if (list.length === 0) {
    const p = document.createElement('div');
    p.className = 'empty-msg';
    p.textContent = 'Neturi registruotu automobiliu.';
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
    const disabled = !veh.canTakeOut;
    card.className = `car-card ${state.selected?.plate === veh.plate ? 'active' : ''}${disabled ? ' disabled' : ''}`;
    card.onclick = () => setSelected(veh);

    const img = document.createElement('img');
    img.className = 'car-img';
    img.alt = veh.model || '';
    bindVehicleThumbnail(img, veh.model, veh.image);
    card.appendChild(img);

    const info = document.createElement('div');
    info.className = 'car-info';
    info.innerHTML = `<div>${veh.displayName || veh.model}</div><div class="car-plate">${veh.plate}</div><div class="car-status">${veh.statusLabel}</div>`;
    card.appendChild(info);

    carsEl.appendChild(card);
  });
}

function openUI(payload) {
  state.payload = payload;
  titleEl.textContent = payload?.title || 'Garažas';
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
takeOutBtn.onclick = () => {
  if (state.selected?.canTakeOut && state.selected.plate) {
    post('takeOut', { plate: state.selected.plate });
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
