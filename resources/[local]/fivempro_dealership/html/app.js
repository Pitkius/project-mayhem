const app = document.getElementById('app');
const titleEl = document.getElementById('title');
const categoriesEl = document.getElementById('categories');
const carsEl = document.getElementById('cars');
const colorsEl = document.getElementById('colors');
const selectedNameEl = document.getElementById('selectedName');
const selectedPriceEl = document.getElementById('selectedPrice');
const statMaxEl = document.getElementById('statMax');
const stat0100El = document.getElementById('stat0100');
const statBrakingEl = document.getElementById('statBraking');
const statTractionEl = document.getElementById('statTraction');

let state = {
  payload: null,
  selectedCategory: null,
  selectedVehicle: null,
  selectedColorIdx: null,
};

const colorPalette = ['#ffffff','#0f0f0f','#5d5d5d','#cc2f2f','#2f5fcc','#ffd14d','#3ca95f','#e98d3a','#7a4bd6'];

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

function setSelectedVehicle(vehicle) {
  state.selectedVehicle = vehicle;
  if (!vehicle) return;

  selectedNameEl.textContent = `${vehicle.brand || ''} ${vehicle.name || vehicle.model}`.trim();
  selectedPriceEl.textContent = fmtMoney(vehicle.price);
  statMaxEl.textContent = vehicle.stats?.maxKmh ?? 0;
  stat0100El.textContent = vehicle.stats?.zeroToHundred ?? 0;
  statBrakingEl.textContent = vehicle.stats?.braking ?? 0;
  statTractionEl.textContent = vehicle.stats?.traction ?? 0;

  post('selectVehicle', { model: vehicle.model });
  renderCars();
}

function renderCategories() {
  categoriesEl.innerHTML = '';
  (state.payload?.categories || []).forEach((cat) => {
    const btn = document.createElement('button');
    btn.className = `cat-btn ${state.selectedCategory === cat.key ? 'active' : ''}`;
    btn.textContent = cat.label;
    btn.onclick = () => {
      state.selectedCategory = cat.key;
      const first = (state.payload?.vehicles || []).find((v) => v.category === cat.key);
      if (first) setSelectedVehicle(first);
      renderCategories();
      renderCars();
    };
    categoriesEl.appendChild(btn);
  });
}

function renderCars() {
  carsEl.innerHTML = '';
  const vehicles = (state.payload?.vehicles || []).filter((v) => v.category === state.selectedCategory);
  vehicles.forEach((veh) => {
    const card = document.createElement('div');
    card.className = `car-card ${state.selectedVehicle?.model === veh.model ? 'active' : ''}`;
    card.onclick = () => setSelectedVehicle(veh);

    const img = document.createElement('img');
    img.className = 'car-img';
    img.src = veh.image;
    img.alt = veh.model;
    img.onerror = () => {
      img.src = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="480" height="180"><rect width="100%" height="100%" fill="%2320262b"/><text x="50%" y="50%" fill="%23b3c1c8" font-family="Arial" font-size="20" dominant-baseline="middle" text-anchor="middle">No Image</text></svg>';
    };
    card.appendChild(img);

    const info = document.createElement('div');
    info.className = 'car-info';
    info.innerHTML = `<div>${veh.brand || ''} ${veh.name || veh.model}</div><div class="car-price">${fmtMoney(veh.price)}</div>`;
    card.appendChild(info);

    carsEl.appendChild(card);
  });
}

function renderColors() {
  colorsEl.innerHTML = '';
  (state.payload?.colors || []).forEach((c, idx) => {
    const dot = document.createElement('button');
    dot.className = `color-dot ${state.selectedColorIdx === c.idx ? 'active' : ''}`;
    dot.title = c.label || `Color ${idx + 1}`;
    dot.style.background = colorPalette[idx % colorPalette.length];
    dot.onclick = () => {
      state.selectedColorIdx = c.idx;
      post('setColor', { colorIdx: c.idx });
      renderColors();
    };
    colorsEl.appendChild(dot);
  });
}

function openUI(payload) {
  state.payload = payload;
  titleEl.textContent = payload?.title || 'Autosalonas';
  const firstCategory = payload?.categories?.[0]?.key || null;
  state.selectedCategory = firstCategory;
  state.selectedColorIdx = payload?.colors?.[0]?.idx ?? null;
  renderCategories();
  renderColors();
  const firstVehicle = (payload?.vehicles || []).find((v) => v.category === firstCategory) || payload?.vehicles?.[0];
  if (firstVehicle) setSelectedVehicle(firstVehicle);
  app.classList.remove('hidden');
}

function closeUI() {
  app.classList.add('hidden');
  state = { payload: null, selectedCategory: null, selectedVehicle: null, selectedColorIdx: null };
}

document.getElementById('closeBtn').onclick = () => post('close');
document.getElementById('rotateLeft').onclick = () => post('rotatePreview', { dir: -1 });
document.getElementById('rotateRight').onclick = () => post('rotatePreview', { dir: 1 });
document.getElementById('buyBtn').onclick = () => {
  if (state.selectedVehicle) {
    post('buyVehicle', { model: state.selectedVehicle.model });
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
