const app = document.getElementById('app');
const screenHome = document.getElementById('screenHome');
const screenWizard = document.getElementById('screenWizard');
const charCards = document.getElementById('charCards');
const stepNav = document.getElementById('stepNav');
const stepBody = document.getElementById('stepBody');
const stepTitle = document.getElementById('stepTitle');
const stepDesc = document.getElementById('stepDesc');
const reviewBox = document.getElementById('reviewBox');

let session = { maxChars: 5, enableDelete: true, characters: [], options: {} };
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
  { id: 'personal', title: 'Asmeninė informacija', desc: 'Vardas, pilietybė, gimimo data' },
  { id: 'genetics', title: 'Genetika', desc: 'Tėvai ir veido struktūra' },
  { id: 'eyes', title: 'Akys', desc: 'Spalva ir forma' },
  { id: 'hair', title: 'Šukuosena', desc: 'Plaukai, barzda, antakiai' },
  { id: 'facedetails', title: 'Veido detalės', desc: 'Makiažas, senėjimas' },
  { id: 'body', title: 'Kūnas', desc: 'Sudėjimas ir proporcijos' },
  { id: 'voice', title: 'Balsas', desc: 'RP balso preset' },
  { id: 'clothes', title: 'Pradinė apranga', desc: 'Startinis stilius' },
  { id: 'review', title: 'Galutinė peržiūra', desc: 'Patvirtink ir sukurk' },
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

function renderCards() {
  charCards.innerHTML = '';
  session.characters.forEach((c, i) => {
    const el = document.createElement('article');
    el.className = 'card glass';
    el.style.animationDelay = `${i * 0.06}s`;
    el.innerHTML = `
      <div class="avatar">${c.gender === 1 ? '♀' : '♂'}</div>
      <h3>${esc(c.firstname)} ${esc(c.lastname)}</h3>
      <div class="meta">
        <div>${esc(c.job)}</div>
        <div>Paskutinis: ${esc(c.lastPlayed || '—')}</div>
      </div>
      <div class="money">€ ${(c.cash || 0).toLocaleString()} · Bank ${(c.bank || 0).toLocaleString()}</div>
      <div class="actions">
        <button type="button" class="btn primary sm btn-play">Žaisti</button>
        ${session.enableDelete ? '<button type="button" class="btn danger sm btn-del">Ištrinti</button>' : ''}
      </div>`;
    el.querySelector('.btn-play').onclick = (ev) => {
      ev.stopPropagation();
      post('selectChar', { citizenid: c.citizenid });
      closeUi();
    };
    el.querySelector('.btn-del')?.addEventListener('click', (ev) => {
      ev.stopPropagation();
      if (confirm('Ištrinti personažą?')) post('deleteChar', { citizenid: c.citizenid });
    });
    el.onclick = () => {
      post('previewCharacter', { model: c.model, skin: c.skin });
    };
    charCards.appendChild(el);
  });
}

function renderNav() {
  stepNav.innerHTML = '';
  STEPS.forEach((s, i) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'step-link' + (i === stepIndex ? ' active' : '') + (i < stepIndex ? ' done' : '');
    b.textContent = `${i + 1}. ${s.title}`;
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

function renderStep() {
  const step = STEPS[stepIndex];
  stepTitle.textContent = step.title;
  stepDesc.textContent = step.desc;
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
      slider('Barzda', 'beard', state.hair, -1, 28, 1) +
      slider('Barzdos spalva', 'beardColor', state.hair, 0, 63, 1) +
      slider('Antakiai', 'brows', state.hair, 0, 33, 1);
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
    document.getElementById('btnNext').textContent = 'Sukurti personažą';
    return;
  }

  document.getElementById('btnNext').textContent = stepIndex === STEPS.length - 1 ? 'Sukurti personažą' : 'Toliau';
  reviewBox.classList.add('hidden');
}

function validateStep() {
  const p = state.personal;
  if (STEPS[stepIndex].id === 'personal') {
    if (!p.firstname.trim() || !p.lastname.trim()) {
      alert('Įvesk vardą ir pavardę.');
      return false;
    }
  }
  return true;
}

function closeUi() {
  app.classList.add('hidden');
  screenHome.classList.remove('hidden');
  screenWizard.classList.add('hidden');
}

document.getElementById('btnNew').onclick = () => {
  if (session.characters.length >= session.maxChars) {
    alert('Pasiektas personažų limitas.');
    return;
  }
  stepIndex = 0;
  screenHome.classList.add('hidden');
  screenWizard.classList.remove('hidden');
  post('setGender', { gender: 0 });
  renderStep();
};

document.getElementById('btnBack').onclick = () => {
  if (stepIndex === 0) {
    screenWizard.classList.add('hidden');
    screenHome.classList.remove('hidden');
    return;
  }
  stepIndex -= 1;
  renderStep();
};

document.getElementById('btnNext').onclick = () => {
  if (!validateStep()) return;
  if (STEPS[stepIndex].id === 'review') {
    post('createChar', {
      personal: state.personal,
      voice: state.voice,
      body: state.body,
      outfit: state.outfit,
    });
    closeUi();
    return;
  }
  if (stepIndex < STEPS.length - 1) {
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

window.addEventListener('message', (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === 'open') {
    session = d.data || session;
    app.classList.remove('hidden');
    screenWizard.classList.add('hidden');
    screenHome.classList.remove('hidden');
    renderCards();
  }
  if (d.action === 'close') closeUi();
});
