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
    nationality: 'Lietuvos', originCity: 'Vilnius', bloodType: 'A+',
  },
  genetics: { mom: 0, dad: 0, shapeMix: 0.5, skinMix: 0.5, nose: 0 },
  eyes: { color: 0, opening: 0.0 },
  hair: { style: 0, color: 0, color2: 0, beard: 0, beardColor: 0, brows: 0, browColor: 0 },
  facedetails: { ageing: -1, blush: -1, lipstick: -1, makeup: -1, moles: 0 },
  body: { shoulders: 0, arms: 0, legs: 0, muscle: 0, weight: 0 },
  voice: 'male_young',
  outfit: 'casual',
};

const STEPS = [
  { id: 'personal', title: 'Asmeninė informacija', icon: 'fa-id-card', desc: 'Vardas, pilietybė, gimimo data' },
  { id: 'genetics', title: 'Genetika', icon: 'fa-users', desc: 'Tėvai ir veido struktūra' },
  { id: 'eyes', title: 'Akys', icon: 'fa-eye', desc: 'Spalva ir forma' },
  { id: 'hair', title: 'Šukuosena', icon: 'fa-scissors', desc: 'Plaukai, barzda, antakiai' },
  { id: 'facedetails', title: 'Veido detalės', icon: 'fa-palette', desc: 'Makiažas, senėjimas' },
  { id: 'body', title: 'Kūnas', icon: 'fa-person', desc: 'Sudėjimas ir proporcijos' },
  { id: 'voice', title: 'Balsas', icon: 'fa-microphone', desc: 'RP balso preset' },
  { id: 'clothes', title: 'Apranga', icon: 'fa-shirt', desc: 'Startinis stilius' },
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
  return {
    face: { item: g.mom, texture: 0 },
    face2: { item: g.dad, texture: 0 },
    facemix: { shapeMix: g.shapeMix, skinMix: g.skinMix },
    eye_color: { item: e.color, texture: 0 },
    eye_opening: { item: e.opening, texture: 0 },
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
  return session.shopMode === 'barber' || session.shopMode === 'clothing';
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

function slider(label, key, obj, min, max, step, onChange) {
  const v = obj[key];
  const id = `sl_${key}_${Math.random().toString(36).slice(2, 7)}`;
  return `<div class="slider-row">
    <label><span>${label}</span><span id="${id}_v">${Number(v).toFixed(2)}</span></label>
    <input type="range" min="${min}" max="${max}" step="${step}" value="${v}" data-k="${key}" class="sl" />
  </div>`;
}

function bindSliders(container, obj, extra) {
  container.querySelectorAll('.sl').forEach((inp) => {
    inp.oninput = () => {
      const k = inp.dataset.k;
      obj[k] = parseFloat(inp.value);
      const lab = container.querySelector(`#${inp.previousElementSibling?.querySelector('span')?.id || ''}`);
      inp.parentElement.querySelector('label span:last-child').textContent = parseFloat(inp.value).toFixed(2);
      syncAppearance();
      if (extra) extra(k, parseFloat(inp.value));
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

function renderClothingShop() {
  const items = session.clothingItems || [];
  const skin = parseCurrentSkin();
  let html = '<p class="muted shop-hint">Pasirink drabužių modelį ir tekstūrą. ← → suka kamerą.</p><div class="field-grid">';
  items.forEach((it) => {
    html += `<div class="field full clothing-row" data-key="${esc(it.key)}">
      <label>${esc(it.label)}</label>
      <div class="slider-row">
        <label><span>Modelis</span><span class="cv-item">0</span></label>
        <input type="range" class="sl-cloth" data-key="${esc(it.key)}" data-part="item" min="0" max="${it.maxItem || 100}" step="1" value="0" />
      </div>
      <div class="slider-row">
        <label><span>Spalva / tekstūra</span><span class="cv-tex">0</span></label>
        <input type="range" class="sl-cloth" data-key="${esc(it.key)}" data-part="texture" min="0" max="${it.maxTex || 15}" step="1" value="0" />
      </div>
    </div>`;
  });
  html += '</div>';
  stepBody.innerHTML = html;
  items.forEach((it) => {
    const row = stepBody.querySelector(`.clothing-row[data-key="${it.key}"]`);
    if (!row) return;
    const part = skin[it.key] || { item: 0, texture: 0 };
    const itemInp = row.querySelector('[data-part="item"]');
    const texInp = row.querySelector('[data-part="texture"]');
    itemInp.value = part.item ?? 0;
    texInp.value = part.texture ?? 0;
    row.querySelector('.cv-item').textContent = itemInp.value;
    row.querySelector('.cv-tex').textContent = texInp.value;
  });
  stepBody.querySelectorAll('.sl-cloth').forEach((inp) => {
    inp.oninput = () => {
      const key = inp.dataset.key;
      const row = inp.closest('.clothing-row');
      const itemInp = row.querySelector('[data-part="item"]');
      const texInp = row.querySelector('[data-part="texture"]');
      row.querySelector('.cv-item').textContent = itemInp.value;
      row.querySelector('.cv-tex').textContent = texInp.value;
      post('setClothing', {
        key,
        item: parseInt(itemInp.value, 10),
        texture: parseInt(texInp.value, 10),
      });
    };
  });
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
      : step.desc;
  post('setCamera', { step: step.id });
  renderNav();

  let html = '';
  const opt = session.options || {};

  if (step.id === 'personal') {
    html = `<div class="field-grid">
      ${field('Vardas', '<input id="fn" maxlength="20" />')}
      ${field('Pavardė', '<input id="ln" maxlength="20" />')}
      ${field('Gimimo data', '<input id="bd" placeholder="DD-MM-YYYY" />')}
      ${field('Lytis', '<select id="gender"><option value="0">Vyras</option><option value="1">Moteris</option></select>')}
      ${field('Pilietybė', `<select id="nat">${(opt.nationalities || []).map((n) => `<option>${esc(n)}</option>`).join('')}</select>`)}
      ${field('Kilmės miestas', `<select id="city">${(opt.originCities || []).map((n) => `<option>${esc(n)}</option>`).join('')}</select>`)}
      ${field('Kraujo grupė', `<select id="blood">${(opt.bloodTypes || []).map((n) => `<option>${esc(n)}</option>`).join('')}</select>`)}
    </div>`;
    stepBody.innerHTML = html;
    const p = state.personal;
    document.getElementById('fn').value = p.firstname;
    document.getElementById('ln').value = p.lastname;
    document.getElementById('bd').value = p.birthdate;
    document.getElementById('gender').value = p.gender;
    document.getElementById('nat').value = p.nationality;
    document.getElementById('city').value = p.originCity;
    document.getElementById('blood').value = p.bloodType;
    document.getElementById('gender').onchange = (e) => {
      p.gender = parseInt(e.target.value, 10);
      post('setGender', { gender: p.gender });
    };
    ['fn', 'ln', 'bd', 'nat', 'city', 'blood'].forEach((id) => {
      document.getElementById(id).oninput = (e) => {
        const map = { fn: 'firstname', ln: 'lastname', bd: 'birthdate', nat: 'nationality', city: 'originCity', blood: 'bloodType' };
        p[map[id]] = e.target.value;
      };
    });
  } else if (step.id === 'genetics') {
    html = slider('Mama (veidas)', 'mom', state.genetics, 0, 45, 1) +
      slider('Tėtis (veidas)', 'dad', state.genetics, 0, 45, 1) +
      slider('Veido maišymas', 'shapeMix', state.genetics, 0, 1, 0.01) +
      slider('Odos spalva', 'skinMix', state.genetics, 0, 1, 0.01) +
      slider('Nosies plotis', 'nose', state.genetics, -1, 1, 0.01);
    state.genetics.nose = state.genetics.nose || 0;
    stepBody.innerHTML = html;
    bindSliders(stepBody, state.genetics);
  } else if (step.id === 'eyes') {
    const colors = opt.eyeColors || [];
    html = field('Akių spalva', `<select id="eyeColor">${colors.map((c) => `<option value="${c.id}">${esc(c.label)}</option>`).join('')}</select>`) +
      slider('Akių dydis / tarpas', 'opening', state.eyes, -1, 1, 0.01);
    stepBody.innerHTML = `<div class="field-grid">${html}</div>`;
    document.getElementById('eyeColor').value = state.eyes.color;
    document.getElementById('eyeColor').onchange = (e) => { state.eyes.color = parseInt(e.target.value, 10); syncAppearance(); };
    bindSliders(stepBody, state.eyes);
  } else if (step.id === 'hair') {
    html = slider('Šukuosena', 'style', state.hair, 0, 80, 1) +
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
    html = slider('Senėjimas', 'ageing', state.facedetails, -1, 14, 1) +
      slider('Makiažas', 'makeup', state.facedetails, -1, 74, 1) +
      slider('Lūpdažiai', 'lipstick', state.facedetails, -1, 9, 1) +
      slider('Skruostų rausvas', 'blush', state.facedetails, -1, 6, 1) +
      slider('Randai / apgamai', 'moles', state.facedetails, 0, 17, 1);
    stepBody.innerHTML = html;
    bindSliders(stepBody, state.facedetails);
  } else if (step.id === 'body') {
    html = slider('Pečiai', 'shoulders', state.body, -1, 1, 0.01) +
      slider('Rankos', 'arms', state.body, -1, 1, 0.01) +
      slider('Kojos', 'legs', state.body, -1, 1, 0.01) +
      slider('Raumenys', 'muscle', state.body, -1, 1, 0.01) +
      slider('Svorio tipas', 'weight', state.body, -1, 1, 0.01);
    stepBody.innerHTML = html;
    bindSliders(stepBody, state.body);
  } else if (step.id === 'voice') {
    html = field('Balso preset', `<select id="voice">${(opt.voicePresets || []).map((v) => `<option value="${v.id}">${esc(v.label)}</option>`).join('')}</select>`);
    stepBody.innerHTML = html;
    document.getElementById('voice').value = state.voice;
    document.getElementById('voice').onchange = (e) => { state.voice = e.target.value; };
  } else if (step.id === 'clothes') {
    if (isShop() && session.shopMode === 'clothing') {
      renderClothingShop();
    } else {
      const outfits = [
        { id: 'casual', label: 'Casual' },
        { id: 'street', label: 'Streetwear' },
        { id: 'business', label: 'Business' },
        { id: 'sport', label: 'Sport' },
      ];
      html = `<div class="outfit-grid">${outfits.map((o) =>
        `<button type="button" class="outfit-btn${state.outfit === o.id ? ' active' : ''}" data-o="${o.id}">${o.label}</button>`
      ).join('')}</div>`;
      stepBody.innerHTML = html;
      stepBody.querySelectorAll('.outfit-btn').forEach((btn) => {
        btn.onclick = () => {
          state.outfit = btn.dataset.o;
          stepBody.querySelectorAll('.outfit-btn').forEach((b) => b.classList.toggle('active', b.dataset.o === state.outfit));
          post('applyOutfit', { outfit: state.outfit, gender: state.personal.gender });
        };
      });
    }
  } else if (step.id === 'review') {
    const p = state.personal;
    reviewBox.classList.remove('hidden');
    reviewBox.innerHTML = `
      <strong>${esc(p.firstname)} ${esc(p.lastname)}</strong><br/>
      Gim.: ${esc(p.birthdate)} · ${p.gender === 1 ? 'Moteris' : 'Vyras'}<br/>
      ${esc(p.nationality)} · ${esc(p.originCity)}<br/>
      Kraujas: ${esc(p.bloodType)}<br/>
      Balsas: ${esc(state.voice)}<br/>
      Apranga: ${esc(state.outfit)}`;
    stepBody.innerHTML = '<p class="muted">Patikrink personažą dešinėje (3D peržiūra). Paspausk „Sukurti personažą“.</p>';
    const fin = wizardMode === 'edit' ? 'Išsaugoti išvaizdą' : 'Sukurti personažą';
    document.getElementById('btnNext').innerHTML = `<i class="fa-solid fa-check" aria-hidden="true"></i> ${fin}`;
    return;
  }

  let finishLabel = wizardMode === 'edit' ? 'Išsaugoti išvaizdą' : 'Sukurti personažą';
  if (isShop()) finishLabel = 'Išsaugoti ir uždaryti';
  const btnNext = document.getElementById('btnNext');
  if (stepIndex === steps.length - 1) {
    btnNext.innerHTML = `<i class="fa-solid fa-check" aria-hidden="true"></i> ${finishLabel}`;
  } else {
    btnNext.innerHTML = `Toliau <i class="fa-solid fa-arrow-right" aria-hidden="true"></i>`;
  }
  reviewBox.classList.add('hidden');
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
  if (cur.voice) state.voice = cur.voice;
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
  } else {
    post('setGender', { gender }).then(() => {
      if (session.current?.skin) post('loadPreset', { skin: session.current.skin });
      renderStep();
    });
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
  post('cancelShop');
  closeUi();
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
    voice: state.voice,
    body: state.body,
    outfit: state.outfit,
  };

  if (step.id === 'review' || (isShop() && stepIndex === steps.length - 1)) {
    post(isShop() || wizardMode === 'edit' ? 'saveAppearance' : 'createChar', payload);
    closeUi();
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
    post('cancelShop');
    closeUi();
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
