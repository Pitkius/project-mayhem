const app = document.getElementById('app');
const screenWizard = document.getElementById('screenWizard');
const stepNav = document.getElementById('stepNav');
const stepBody = document.getElementById('stepBody');
const stepTitle = document.getElementById('stepTitle');
const stepDesc = document.getElementById('stepDesc');
const reviewBox = document.getElementById('reviewBox');

let session = { maxChars: 1, enableDelete: false, characters: [], options: {} };
let wizardMode = 'create';
let stepIndex = 0;
const state = {
  personal: {
    firstname: '', lastname: '', birthdate: '01-01-1995', gender: 0,
    nationality: 'Lietuva', originCity: 'Los Santos',
  },
  genetics: { mom: 0, dad: 0, shapeMix: 0.5, skinMix: 0.5, skinTone: 0, nose: 0 },
  eyes: { color: 0, opening: 0.0 },
  hair: { style: 0, color: 0, color2: 0, beard: 0, beardColor: 0, brows: 0, browColor: 0 },
  facedetails: { ageing: -1, blush: -1, lipstick: -1, makeup: -1, moles: 0 },
  body: { shoulders: 0, arms: 0, legs: 0, muscle: 0, weight: 0 },
};

const STEPS = [
  { id: 'personal', title: 'Asmeninė informacija', icon: 'fa-id-card', desc: 'Vardas, pilietybė, gimimo data' },
  { id: 'genetics', title: 'Genetika', icon: 'fa-users', desc: 'Tėvai ir veido struktūra' },
  { id: 'eyes', title: 'Akys', icon: 'fa-eye', desc: 'Spalva ir forma' },
  { id: 'hair', title: 'Šukuosena', icon: 'fa-scissors', desc: 'Plaukai, barzda, antakiai' },
  { id: 'facedetails', title: 'Veido detalės', icon: 'fa-palette', desc: 'Makiažas, senėjimas' },
  { id: 'body', title: 'Kūnas', icon: 'fa-person', desc: 'Sudėjimas ir proporcijos' },
  { id: 'clothes', title: 'Apranga', icon: 'fa-shirt', desc: 'Visi drabužių variantai' },
  { id: 'tattoos', title: 'Tatuiruotės', icon: 'fa-pen-nib', desc: 'Kūno tatuiruotės' },
  { id: 'review', title: 'Peržiūra', icon: 'fa-circle-check', desc: 'Patvirtink ir sukurk' },
];

function post(name, data = {}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  }).then((r) => r.json()).catch(() => ({}));
}

function esc(s) {
  const d = document.createElement('div');
  d.textContent = s ?? '';
  return d.innerHTML;
}

function buildPatch() {
  const g = state.genetics;
  const h = state.hair;
  const e = state.eyes;
  const f = state.facedetails;
  const b = state.body;
  const skinTex = Math.min(45, Math.max(0, Math.round(g.skinTone ?? 0)));
  return {
    face: { item: g.mom, texture: skinTex },
    face2: { item: g.dad, texture: skinTex },
    facemix: { shapeMix: g.shapeMix, skinMix: g.skinMix },
    eye_color: { item: e.color, texture: 0 },
    eye_opening: { item: e.opening * 10, texture: 0 },
    hair: { item: h.style, texture: h.color },
    eyebrows: { item: h.brows, texture: h.browColor },
    beard: { item: state.personal.gender === 1 ? -1 : h.beard, texture: h.beardColor },
    blush: { item: f.blush, texture: 0 },
    lipstick: { item: f.lipstick, texture: 0 },
    makeup: { item: f.makeup, texture: 0 },
    ageing: { item: f.ageing, texture: 0 },
    moles: { item: f.moles, texture: 0 },
    jaw_bone_width: { item: b.shoulders * 0.4, texture: 0 },
    neck_thikness: { item: b.weight * 0.3, texture: 0 },
    cheek_1: { item: b.muscle * 0.35, texture: 0 },
    lips_thickness: { item: b.legs * 0.2, texture: 0 },
    nose_0: { item: b.arms * 0.25, texture: 0 },
    nose_1: { item: (g.nose || 0) * 0.5, texture: 0 },
  };
}

function syncAppearance() {
  post('applyPatch', { patch: buildPatch() });
}

function isShop() {
  return session.shopMode === 'barber' || session.shopMode === 'clothing' || session.shopMode === 'tattoo';
}

function getActiveSteps() {
  if (isShop() && session.shopSteps && session.shopSteps.length) {
    return STEPS.filter((s) => session.shopSteps.includes(s.id));
  }
  return STEPS;
}

function updateShopChrome() {
  const shop = isShop();
  document.getElementById('btnCancel').classList.toggle('hidden', !shop);
  const tools = document.querySelector('.sidebar-tools');
  if (tools) tools.classList.toggle('hidden', shop);
}

function renderNav() {
  const steps = getActiveSteps();
  stepNav.innerHTML = '';
  steps.forEach((s, i) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'step-link' + (i === stepIndex ? ' active' : '') + (i < stepIndex ? ' done' : '');
    const ic = s.icon ? `<i class="fa-solid ${s.icon}" aria-hidden="true"></i> ` : '';
    b.innerHTML = `${ic}${i + 1}. ${esc(s.title)}`;
    b.onclick = () => { stepIndex = i; renderStep(); };
    stepNav.appendChild(b);
  });
}

function field(label, html) {
  return `<div class="field">${label ? `<label>${label}</label>` : ''}${html}</div>`;
}

function slider(label, key, obj, min, max, step) {
  const v = obj[key];
  return `<div class="slider-row">
    <label><span>${label}</span><span>${Number(v).toFixed(step < 1 ? 2 : 0)}</span></label>
    <input type="range" min="${min}" max="${max}" step="${step}" value="${v}" data-k="${key}" class="sl" />
  </div>`;
}

function bindSliders(container, obj) {
  container.querySelectorAll('.sl').forEach((inp) => {
    inp.oninput = () => {
      const k = inp.dataset.k;
      obj[k] = parseFloat(inp.value);
      const dec = parseFloat(inp.step) < 1 ? 2 : 0;
      const valSpan = inp.parentElement?.querySelector('label span:last-child');
      if (valSpan) valSpan.textContent = parseFloat(inp.value).toFixed(dec);
      syncAppearance();
    };
  });
}

function parseCurrentSkin() {
  try {
    const raw = session.current?.skin;
    if (!raw) return {};
    return typeof raw === 'string' ? JSON.parse(raw) : raw;
  } catch {
    return {};
  }
}

function updateClothingTextureLimit(row, key, itemValue, applyChange) {
  return post('getTextureLimit', { key, item: itemValue }).then((res) => {
    const texInp = row.querySelector('[data-part="texture"]');
    if (!texInp) return;
    const maxTex = Math.max(0, Number(res?.maxTex) || 0);
    texInp.max = String(maxTex);
    let tex = parseInt(texInp.value, 10);
    if (!Number.isFinite(tex) || tex < 0) tex = 0;
    if (tex > maxTex) {
      tex = maxTex;
      texInp.value = String(tex);
    }
    row.querySelector('.cv-tex').textContent = String(tex);
    if (applyChange) {
      const itemInp = row.querySelector('[data-part="item"]');
      post('setClothing', {
        key,
        item: parseInt(itemInp.value, 10),
        texture: tex,
      });
    }
  });
}

function bindClothingSliders(container) {
  container.querySelectorAll('.sl-cloth').forEach((inp) => {
    inp.oninput = () => {
      const row = inp.closest('.clothing-row');
      const key = row.dataset.key;
      const itemInp = row.querySelector('[data-part="item"]');
      const texInp = row.querySelector('[data-part="texture"]');
      row.querySelector('.cv-item').textContent = itemInp.value;
      if (inp.dataset.part === 'item') {
        updateClothingTextureLimit(row, key, parseInt(itemInp.value, 10), true);
        return;
      }
      row.querySelector('.cv-tex').textContent = texInp.value;
      post('setClothing', {
        key,
        item: parseInt(itemInp.value, 10),
        texture: parseInt(texInp.value, 10),
      });
    };
  });
}

function renderClothingShop(items) {
  const skin = parseCurrentSkin();
  let html = '<p class="muted shop-hint">Visi drabužių variantai — slankikliai. ← → suka kamerą.</p><div class="field-grid">';
  items.forEach((it) => {
    const minItem = it.minItem ?? 0;
    html += `<div class="field full clothing-row" data-key="${esc(it.key)}">
      <label>${esc(it.label)}</label>
      <div class="slider-row">
        <label><span>Modelis</span><span class="cv-item">${minItem}</span></label>
        <input type="range" class="sl-cloth" data-part="item" min="${minItem}" max="${it.maxItem || 100}" step="1" value="${minItem}" />
      </div>
      <div class="slider-row">
        <label><span>Spalva / tekstūra</span><span class="cv-tex">0</span></label>
        <input type="range" class="sl-cloth" data-part="texture" min="0" max="${Math.max(0, it.maxTex ?? 0)}" step="1" value="0" />
      </div>
    </div>`;
  });
  html += '</div>';
  stepBody.innerHTML = html;
  items.forEach((it) => {
    const row = stepBody.querySelector(`.clothing-row[data-key="${it.key}"]`);
    if (!row) return;
    const part = skin[it.key] || { item: it.minItem ?? 0, texture: 0 };
    const itemInp = row.querySelector('[data-part="item"]');
    const texInp = row.querySelector('[data-part="texture"]');
    itemInp.value = part.item ?? (it.minItem ?? 0);
    texInp.value = part.texture ?? 0;
    row.querySelector('.cv-item').textContent = itemInp.value;
    row.querySelector('.cv-tex').textContent = texInp.value;
    updateClothingTextureLimit(row, it.key, parseInt(itemInp.value, 10), false);
  });
  bindClothingSliders(stepBody);
}

let tattooState = { zone: 'ZONE_TORSO', catalog: [], owned: [], filter: '' };

function tattooOwnedInZone(zone) {
  return tattooState.owned.filter((t) => t.zone === zone);
}

function tattooIsOwned(name, zone) {
  return tattooState.owned.some((t) => t.name === name && t.zone === zone);
}

function renderTattooOwned(zone) {
  const owned = tattooOwnedInZone(zone);
  if (!owned.length) {
    return '<p class="muted tattoo-owned-empty">Šioje zonoje tatuiruočių nėra.</p>';
  }
  return `<div class="tattoo-owned-list">${owned.map((t) => {
    const label = tattooState.catalog.find((c) => c.name === t.name)?.label || t.name;
    return `<div class="tattoo-owned-item">
      <span>${esc(label)}</span>
      <button type="button" class="btn ghost sm" data-remove-name="${esc(t.name)}">Pašalinti</button>
    </div>`;
  }).join('')}</div>`;
}

function renderTattooCatalogList(zone) {
  const q = (tattooState.filter || '').trim().toLowerCase();
  const rows = tattooState.catalog.filter((t) => {
    if (!q) return true;
    return (t.label || '').toLowerCase().includes(q) || (t.name || '').toLowerCase().includes(q);
  });
  if (!rows.length) {
    return '<p class="muted">Nieko nerasta.</p>';
  }
  return `<div class="tattoo-list">${rows.map((t) => {
    const active = tattooIsOwned(t.name, zone) ? ' active' : '';
    return `<button type="button" class="tattoo-item${active}" data-tattoo-name="${esc(t.name)}">
      <span class="tattoo-item-label">${esc(t.label || t.name)}</span>
      <span class="tattoo-item-state">${active ? 'Uždėta' : 'Uždėti'}</span>
    </button>`;
  }).join('')}</div>`;
}

function bindTattooShop(zone) {
  const search = stepBody.querySelector('#tattooSearch');
  if (search) {
    search.oninput = () => {
      tattooState.filter = search.value;
      const list = stepBody.querySelector('#tattooCatalog');
      if (list) list.innerHTML = renderTattooCatalogList(zone);
      bindTattooShop(zone);
    };
  }

  stepBody.querySelectorAll('.pill-btn[data-zone]').forEach((btn) => {
    btn.onclick = () => {
      tattooState.zone = btn.dataset.zone;
      tattooState.filter = '';
      loadTattooZone(tattooState.zone);
    };
  });

  stepBody.querySelectorAll('.tattoo-item[data-tattoo-name]').forEach((btn) => {
    btn.onclick = () => {
      post('toggleTattoo', { name: btn.dataset.tattooName, zone }).then((res) => {
        tattooState.owned = res.tattoos || [];
        const ownedBox = stepBody.querySelector('#tattooOwned');
        const catalogBox = stepBody.querySelector('#tattooCatalog');
        if (ownedBox) ownedBox.innerHTML = renderTattooOwned(zone);
        if (catalogBox) catalogBox.innerHTML = renderTattooCatalogList(zone);
        bindTattooShop(zone);
      });
    };
  });

  stepBody.querySelectorAll('[data-remove-name]').forEach((btn) => {
    btn.onclick = () => {
      post('toggleTattoo', { name: btn.dataset.removeName, zone }).then((res) => {
        tattooState.owned = res.tattoos || [];
        const ownedBox = stepBody.querySelector('#tattooOwned');
        const catalogBox = stepBody.querySelector('#tattooCatalog');
        if (ownedBox) ownedBox.innerHTML = renderTattooOwned(zone);
        if (catalogBox) catalogBox.innerHTML = renderTattooCatalogList(zone);
        bindTattooShop(zone);
      });
    };
  });

  const clearBtn = stepBody.querySelector('#clearTattooZone');
  if (clearBtn) {
    clearBtn.onclick = () => {
      post('clearTattooZone', { zone }).then((res) => {
        tattooState.owned = res.tattoos || [];
        const ownedBox = stepBody.querySelector('#tattooOwned');
        const catalogBox = stepBody.querySelector('#tattooCatalog');
        if (ownedBox) ownedBox.innerHTML = renderTattooOwned(zone);
        if (catalogBox) catalogBox.innerHTML = renderTattooCatalogList(zone);
        bindTattooShop(zone);
      });
    };
  }
}

function loadTattooZone(zone) {
  post('setTattooZoneCamera', { zone });
  stepBody.querySelectorAll('.pill-btn[data-zone]').forEach((b) => {
    b.classList.toggle('active', b.dataset.zone === zone);
  });
  const catalogBox = stepBody.querySelector('#tattooCatalog');
  if (catalogBox) catalogBox.innerHTML = '<p class="muted">Kraunama...</p>';
  return Promise.all([
    post('getTattooZoneCatalog', { zone }),
    post('getPlayerTattoos'),
  ]).then(([catalog, owned]) => {
    tattooState.catalog = Array.isArray(catalog) ? catalog : [];
    tattooState.owned = Array.isArray(owned) ? owned : [];
    const ownedBox = stepBody.querySelector('#tattooOwned');
    if (ownedBox) ownedBox.innerHTML = renderTattooOwned(zone);
    if (catalogBox) catalogBox.innerHTML = renderTattooCatalogList(zone);
    bindTattooShop(zone);
  });
}

function renderTattooShop() {
  const zones = session.tattooZones || [
    { id: 'ZONE_HEAD', label: 'Galva' },
    { id: 'ZONE_TORSO', label: 'Liemuo' },
    { id: 'ZONE_LEFT_ARM', label: 'Kairė ranka' },
    { id: 'ZONE_RIGHT_ARM', label: 'Dešinė ranka' },
    { id: 'ZONE_LEFT_LEG', label: 'Kairė koja' },
    { id: 'ZONE_RIGHT_LEG', label: 'Dešinė koja' },
    { id: 'ZONE_HAIR', label: 'Plaukai' },
  ];
  const zone = tattooState.zone || zones[1]?.id || 'ZONE_TORSO';
  tattooState.zone = zone;

  stepBody.innerHTML = `
    <p class="muted shop-hint">Pasirink kūno zoną, tada tatuiruotę. ← → suka kamerą. Personažas aprengtas minimaliai, kad matytumėte tatuiruotes.</p>
    <div class="pill-row tattoo-zones" id="tattooZonePills">
      ${zones.map((z) => `<button type="button" class="pill-btn${z.id === zone ? ' active' : ''}" data-zone="${esc(z.id)}">${esc(z.label)}</button>`).join('')}
    </div>
    <div class="field full">
      <label>Dabartinės tatuiruotės</label>
      <div id="tattooOwned"></div>
      <button type="button" class="btn ghost sm" id="clearTattooZone">Pašalinti visas iš zonos</button>
    </div>
    <div class="field full">
      <label>Paieška</label>
      <input type="text" id="tattooSearch" placeholder="Ieškoti tatuiruotės..." autocomplete="off" />
    </div>
    <div class="field full">
      <label>Katalogas</label>
      <div id="tattooCatalog"><p class="muted">Kraunama...</p></div>
    </div>`;

  loadTattooZone(zone);
}

function renderStep() {
  const steps = getActiveSteps();
  const step = steps[stepIndex];
  if (!step) return;
  stepTitle.textContent = step.title;
  stepDesc.textContent = isShop() && session.shopMode === 'barber' && step.id === 'hair'
    ? 'Plaukai, barzda, antakiai'
    : isShop() && session.shopMode === 'clothing' && step.id === 'clothes'
      ? 'Tik drabužiai — be veido ar plaukų'
      : isShop() && session.shopMode === 'tattoo' && step.id === 'tattoos'
        ? 'Tatuiruotės visose GTA kūno zonose'
        : step.desc;
  post('setCamera', { step: step.id });
  renderNav();

  const opt = session.options || {};

  if (step.id === 'personal') {
    const p = state.personal;
    const nats = opt.nationalities || [];
    const cities = opt.originCities || [];
    let html = `<div class="field-grid">
      ${field('Vardas', '<input id="fn" maxlength="20" type="text" />')}
      ${field('Pavardė', '<input id="ln" maxlength="20" type="text" />')}
      ${field('Gimimo data', '<input id="bd" placeholder="DD-MM-YYYY" type="text" />')}
      ${field('Lytis', `<div class="pill-row" id="genderPills">
        <button type="button" class="pill-btn${p.gender === 0 ? ' active' : ''}" data-g="0">Vyras</button>
        <button type="button" class="pill-btn${p.gender === 1 ? ' active' : ''}" data-g="1">Moteris</button>
      </div>`)}
      ${field('Pilietybė', `<input id="nat" list="natList" placeholder="Ieškoti šalies..." autocomplete="off" />
        <datalist id="natList">${nats.map((n) => `<option value="${esc(n)}">`).join('')}</datalist>`)}
      ${field('Miestas (spawn)', `<div class="city-grid" id="cityGrid">${cities.map((c) => {
        const id = typeof c === 'string' ? c : c.id;
        const label = typeof c === 'string' ? c : c.label;
        const hint = typeof c === 'object' ? (c.hint || '') : '';
        return `<button type="button" class="city-card${p.originCity === id ? ' active' : ''}" data-city="${esc(id)}">
          <strong>${esc(label)}</strong><span>${esc(hint)}</span></button>`;
      }).join('')}</div>`)}
    </div>`;
    stepBody.innerHTML = html;
    document.getElementById('fn').value = p.firstname;
    document.getElementById('ln').value = p.lastname;
    document.getElementById('bd').value = p.birthdate;
    document.getElementById('nat').value = p.nationality;
    ['fn', 'ln', 'bd', 'nat'].forEach((id) => {
      document.getElementById(id).oninput = (e) => {
        const map = { fn: 'firstname', ln: 'lastname', bd: 'birthdate', nat: 'nationality' };
        p[map[id]] = e.target.value;
      };
    });
    document.querySelectorAll('#genderPills .pill-btn').forEach((btn) => {
      btn.onclick = () => {
        p.gender = parseInt(btn.dataset.g, 10);
        document.querySelectorAll('#genderPills .pill-btn').forEach((b) => b.classList.toggle('active', b === btn));
        post('setGender', { gender: p.gender });
      };
    });
    document.querySelectorAll('#cityGrid .city-card').forEach((btn) => {
      btn.onclick = () => {
        p.originCity = btn.dataset.city;
        document.querySelectorAll('#cityGrid .city-card').forEach((b) => b.classList.toggle('active', b === btn));
      };
    });
  } else if (step.id === 'genetics') {
    const html = slider('Mama (veidas)', 'mom', state.genetics, 0, 45, 1) +
      slider('Tėtis (veidas)', 'dad', state.genetics, 0, 45, 1) +
      slider('Veido maišymas', 'shapeMix', state.genetics, 0, 1, 0.01) +
      slider('Odos spalva', 'skinTone', state.genetics, 0, 45, 1) +
      slider('Nosies plotis', 'nose', state.genetics, -1, 1, 0.01);
    state.genetics.nose = state.genetics.nose || 0;
    stepBody.innerHTML = html;
    bindSliders(stepBody, state.genetics);
  } else if (step.id === 'eyes') {
    const colors = opt.eyeColors || [];
    let html = `<div class="pill-row" id="eyePills">${colors.map((c) =>
      `<button type="button" class="pill-btn${state.eyes.color === c.id ? ' active' : ''}" data-e="${c.id}">${esc(c.label)}</button>`
    ).join('')}</div>`;
    html += slider('Akių dydis / tarpas', 'opening', state.eyes, -1, 1, 0.01);
    stepBody.innerHTML = html;
    document.querySelectorAll('#eyePills .pill-btn').forEach((btn) => {
      btn.onclick = () => {
        state.eyes.color = parseInt(btn.dataset.e, 10);
        document.querySelectorAll('#eyePills .pill-btn').forEach((b) => b.classList.toggle('active', b === btn));
        syncAppearance();
      };
    });
    bindSliders(stepBody, state.eyes);
  } else if (step.id === 'hair') {
    let html = slider('Šukuosena', 'style', state.hair, 0, 80, 1) +
      slider('Plaukų spalva', 'color', state.hair, 0, 63, 1) +
      slider('Antra spalva', 'color2', state.hair, 0, 63, 1) +
      slider('Antakiai', 'brows', state.hair, 0, 33, 1) +
      slider('Antakių spalva', 'browColor', state.hair, 0, 63, 1);
    if (state.personal.gender !== 1) {
      html += slider('Barzda', 'beard', state.hair, -1, 28, 1) +
        slider('Barzdos spalva', 'beardColor', state.hair, 0, 63, 1);
    }
    stepBody.innerHTML = html;
    bindSliders(stepBody, state.hair);
  } else if (step.id === 'facedetails') {
    const html = slider('Senėjimas', 'ageing', state.facedetails, -1, 14, 1) +
      slider('Makiažas', 'makeup', state.facedetails, -1, 74, 1) +
      slider('Lūpdažiai', 'lipstick', state.facedetails, -1, 9, 1) +
      slider('Skruostų rausvas', 'blush', state.facedetails, -1, 6, 1) +
      slider('Randai / apgamai', 'moles', state.facedetails, 0, 17, 1);
    stepBody.innerHTML = html;
    bindSliders(stepBody, state.facedetails);
  } else if (step.id === 'body') {
    const html = slider('Pečiai', 'shoulders', state.body, -1, 1, 0.01) +
      slider('Rankos', 'arms', state.body, -1, 1, 0.01) +
      slider('Kojos', 'legs', state.body, -1, 1, 0.01) +
      slider('Raumenys', 'muscle', state.body, -1, 1, 0.01) +
      slider('Svorio tipas', 'weight', state.body, -1, 1, 0.01);
    stepBody.innerHTML = html;
    bindSliders(stepBody, state.body);
  } else if (step.id === 'clothes') {
    const items = session.clothingItems || [];
    if (isShop() && session.shopMode === 'clothing') {
      renderClothingShop(items);
    } else {
      stepBody.innerHTML = '<p class="muted">Kraunami drabužių variantai...</p>';
      post('getClothingLimits').then((limits) => {
        session.clothingItems = limits && limits.length ? limits : items;
        renderClothingShop(session.clothingItems);
      });
    }
    finishStepButtons(steps);
    return;
  } else if (step.id === 'tattoos') {
    renderTattooShop();
    finishStepButtons(steps);
    return;
  } else if (step.id === 'review') {
    const p = state.personal;
    const cityObj = (opt.originCities || []).find((c) => (typeof c === 'string' ? c : c.id) === p.originCity);
    const cityLabel = cityObj ? (typeof cityObj === 'string' ? cityObj : cityObj.label) : p.originCity;
    reviewBox.classList.remove('hidden');
    reviewBox.innerHTML = `
      <strong>${esc(p.firstname)} ${esc(p.lastname)}</strong><br/>
      Gim.: ${esc(p.birthdate)} · ${p.gender === 1 ? 'Moteris' : 'Vyras'}<br/>
      ${esc(p.nationality)} · ${esc(cityLabel)}`;
    stepBody.innerHTML = '<p class="muted">Patikrink personažą dešinėje. Paspausk „Sukurti personažą“.</p>';
    const fin = wizardMode === 'edit' ? 'Išsaugoti išvaizdą' : 'Sukurti personažą';
    document.getElementById('btnNext').innerHTML = `<i class="fa-solid fa-check" aria-hidden="true"></i> ${fin}`;
    return;
  }

  finishStepButtons(steps);
  reviewBox.classList.add('hidden');
}

function finishStepButtons(steps) {
  let finishLabel = wizardMode === 'edit' ? 'Išsaugoti išvaizdą' : 'Sukurti personažą';
  if (isShop()) finishLabel = 'Išsaugoti ir uždaryti';
  const btnNext = document.getElementById('btnNext');
  if (stepIndex === steps.length - 1) {
    btnNext.innerHTML = `<i class="fa-solid fa-check" aria-hidden="true"></i> ${finishLabel}`;
  } else {
    btnNext.innerHTML = `Toliau <i class="fa-solid fa-arrow-right" aria-hidden="true"></i>`;
  }
}

function validateStep() {
  if (isShop()) return true;
  const p = state.personal;
  const steps = getActiveSteps();
  if (steps[stepIndex].id === 'personal') {
    if (!p.firstname.trim() || !p.lastname.trim()) {
      alert('Įvesk vardą ir pavardę.');
      return false;
    }
  }
  return true;
}

function closeUi() {
  app.classList.add('hidden');
  screenWizard.classList.add('hidden');
}

function applyCurrentFromSession() {
  const cur = session.current;
  if (!cur) return;
  if (cur.personal) Object.assign(state.personal, cur.personal);
}

function beginAppearanceUi(mode) {
  wizardMode = mode || (session.editMode ? 'edit' : 'create');
  if (!isShop() && wizardMode === 'create' && session.characters.length >= session.maxChars) {
    alert('Jau turi personažą šioje paskyroje.');
    return;
  }
  applyCurrentFromSession();
  stepIndex = 0;
  screenWizard.classList.remove('hidden');
  updateShopChrome();
  const gender = state.personal.gender ?? 0;
  if (isShop()) {
    post('loadPreset', { skin: session.current?.skin }).then(() => renderStep());
  } else if (session.editMode && session.current?.skin) {
    post('loadPreset', { skin: session.current.skin }).then(() => renderStep());
  } else {
    post('setGender', { gender }).then(() => renderStep());
  }
}

function startWizard(mode) {
  session.shopMode = null;
  beginAppearanceUi(mode);
}

function startShop() {
  wizardMode = 'edit';
  beginAppearanceUi('edit');
}

document.getElementById('btnCancel').onclick = () => {
  post('cancelShop').then(() => closeUi());
};

document.getElementById('btnBack').onclick = () => {
  if (stepIndex === 0) return;
  stepIndex -= 1;
  renderStep();
};

document.getElementById('btnNext').onclick = () => {
  if (!validateStep()) return;
  const steps = getActiveSteps();
  const step = steps[stepIndex];
  const payload = {
    personal: state.personal,
    body: state.body,
  };

  if (step.id === 'review' || (isShop() && stepIndex === steps.length - 1)) {
    if (isShop()) {
      post('saveShop').then(() => closeUi());
    } else {
      post(wizardMode === 'edit' ? 'saveAppearance' : 'createChar', payload).then(() => closeUi());
    }
    return;
  }
  if (stepIndex < steps.length - 1) {
    stepIndex += 1;
    renderStep();
  }
};

document.getElementById('btnRandom').onclick = () => {
  post('randomize', { gender: state.personal.gender });
};

document.getElementById('btnSavePreset').onclick = () => {
  const name = prompt('Preset pavadinimas:');
  if (name) post('savePreset', { name });
};

document.getElementById('btnLoadPreset').onclick = async () => {
  const rows = await post('getPresets');
  if (!rows || !rows.length) return alert('Presetų nėra.');
  const names = rows.map((r, i) => `${i + 1}. ${r.name}`).join('\n');
  const pick = prompt('Pasirink numerį:\n' + names);
  const idx = parseInt(pick, 10) - 1;
  if (rows[idx]) post('loadPreset', { skin: rows[idx].skin });
};

function onCameraKeydown(e) {
  if (app.classList.contains('hidden')) return;
  if (e.key === 'Escape' && isShop()) {
    e.preventDefault();
    post('cancelShop').then(() => closeUi());
    return;
  }
  if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
  const tag = (e.target && e.target.tagName) || '';
  if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;
  e.preventDefault();
  const step = e.repeat ? 2.2 : 8;
  post('rotateCamera', { delta: e.key === 'ArrowLeft' ? -step : step });
}

document.addEventListener('keydown', onCameraKeydown);

window.addEventListener('message', (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === 'openWizard') {
    session = d.data || session;
    app.classList.remove('hidden');
    startWizard(session.editMode && session.current ? 'edit' : 'create');
  }
  if (d.action === 'openShop') {
    session = d.data || session;
    app.classList.remove('hidden');
    startShop();
  }
  if (d.action === 'close') closeUi();
});
