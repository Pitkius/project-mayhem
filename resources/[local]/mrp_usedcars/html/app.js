const app = document.getElementById('app');
const content = document.getElementById('content');
const titleEl = document.getElementById('title');
const closeBtn = document.getElementById('btn-close');

let state = {
  mode: null,
  listing: null,
  listings: [],
  minPrice: 1000,
  maxPrice: 5000000,
  feePercent: 7,
  isOwner: false,
  returnGarage: 'pillboxgarage',
};

function money(n) {
  const v = Math.floor(Number(n) || 0);
  return '$' + v.toLocaleString('lt-LT');
}

function post(name, data) {
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
  });
}

function closeUi() {
  app.classList.add('hidden');
  post('close');
}

closeBtn.addEventListener('click', closeUi);
window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') closeUi();
});

function modLabel(v) {
  const n = Number(v);
  if (!Number.isFinite(n) || n < 0) return 'Stock';
  return `Lvl ${n + 1}`;
}

function renderList() {
  titleEl.textContent = 'Listuoti mašiną';
  content.innerHTML = `
    <p class="muted">Nurodyk pardavimo kainą. Iš kainos bus nuskaičiuotas ${state.feePercent}% mokestis — pardavėjas gaus ${100 - state.feePercent}%.</p>
    <div class="field">
      <label>Kaina ($)</label>
      <input id="price-input" type="number" min="${state.minPrice}" max="${state.maxPrice}" step="100" placeholder="${state.minPrice}" />
    </div>
    <p class="muted">Min ${money(state.minPrice)} · Max ${money(state.maxPrice)}</p>
    <div class="actions">
      <button class="btn" type="button" id="btn-cancel">Atšaukti</button>
      <button class="btn primary" type="button" id="btn-list">Parduoti</button>
    </div>
  `;
  content.querySelector('#btn-cancel').onclick = closeUi;
  content.querySelector('#btn-list').onclick = () => {
    const price = Number(content.querySelector('#price-input').value);
    post('listVehicle', { price });
  };
}

function renderMine() {
  titleEl.textContent = 'Mano skelbimai';
  if (!state.listings.length) {
    content.innerHTML = `<p class="muted">Neturi aktyvių skelbimų. Atšaukus mašina grįžta į ${state.returnGarage}.</p>`;
    return;
  }
  content.innerHTML = `
    <p class="muted">Atšaukus skelbimą mašina grįžta į garažą <strong>${state.returnGarage}</strong>.</p>
    <div class="list">
      ${state.listings.map((l) => `
        <div class="list-item">
          <div>
            <h3>${escapeHtml(l.label || l.model)}</h3>
            <p>${escapeHtml(l.plate)} · ${money(l.price)}</p>
          </div>
          <button class="btn danger" type="button" data-cancel="${l.id}">Atšaukti</button>
        </div>
      `).join('')}
    </div>
  `;
  content.querySelectorAll('[data-cancel]').forEach((btn) => {
    btn.addEventListener('click', () => post('cancelListing', { id: Number(btn.dataset.cancel) }));
  });
}

function renderInspect() {
  const l = state.listing || {};
  const tune = l.tune || {};
  const perf = l.perf || {};
  titleEl.textContent = l.label || l.model || 'Apžiūra';

  content.innerHTML = `
    <div class="price">${money(l.price)}<small>${escapeHtml(l.plate || '')} · ${escapeHtml(tune.label || 'Stock')}</small></div>
    <div class="pill-row">
      ${perf.tierLabel || perf.tier ? `<span class="pill">${escapeHtml(perf.tierLabel || perf.tier)}</span>` : ''}
      ${perf.maxKmh ? `<span class="pill">${Math.round(perf.maxKmh)} km/h</span>` : ''}
      ${tune.turbo ? `<span class="pill ok">Turbo</span>` : ''}
      <span class="pill">${escapeHtml(tune.label || 'Stock')}</span>
    </div>
    <div class="stats">
      <div class="stat"><strong>${l.engine ?? '—'}%</strong><small>Variklis</small></div>
      <div class="stat"><strong>${l.body ?? '—'}%</strong><small>Kėbulas</small></div>
      <div class="stat"><strong>${l.fuel ?? '—'}%</strong><small>Kuras</small></div>
    </div>
    <div class="tune-grid">
      <div><span>Engine</span> · ${modLabel(tune.engine)}</div>
      <div><span>Brakes</span> · ${modLabel(tune.brakes)}</div>
      <div><span>Transmission</span> · ${modLabel(tune.transmission)}</div>
      <div><span>Suspension</span> · ${modLabel(tune.suspension)}</div>
      <div><span>Armor</span> · ${modLabel(tune.armor)}</div>
      <div><span>Body mods</span> · ${tune.bodyMods || 0}</div>
    </div>
    <p class="muted">Mokestis ${state.feePercent}% nuskaičiuojamas pardavėjui. Tu moki visą kainą.</p>
    <div class="actions">
      <button class="btn" type="button" id="btn-cancel">Uždaryti</button>
      <button class="btn primary" type="button" id="btn-buy" ${state.isOwner ? 'disabled' : ''}>
        ${state.isOwner ? 'Tavo skelbimas' : 'Pirkti'}
      </button>
    </div>
  `;
  content.querySelector('#btn-cancel').onclick = closeUi;
  const buy = content.querySelector('#btn-buy');
  if (!state.isOwner) {
    buy.onclick = () => post('buyListing', { id: l.id });
  }
}

function escapeHtml(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function render() {
  app.classList.remove('hidden');
  if (state.mode === 'list') renderList();
  else if (state.mode === 'mine') renderMine();
  else if (state.mode === 'inspect') renderInspect();
  else closeUi();
}

window.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.action === 'close') {
    app.classList.add('hidden');
    return;
  }
  if (data.action !== 'open') return;
  state.mode = data.mode;
  state.listing = data.listing || null;
  state.listings = data.listings || [];
  state.minPrice = data.minPrice || state.minPrice;
  state.maxPrice = data.maxPrice || state.maxPrice;
  state.feePercent = data.feePercent ?? state.feePercent;
  state.isOwner = !!data.isOwner;
  state.returnGarage = data.returnGarage || state.returnGarage;
  render();
});
