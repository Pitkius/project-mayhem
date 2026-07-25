const app = document.getElementById('app');
const agencyTitle = document.getElementById('agencyTitle');
const hintText = document.getElementById('hintText');
const districtFilter = document.getElementById('districtFilter');
const onlyAvailable = document.getElementById('onlyAvailable');
const propertyList = document.getElementById('propertyList');
const detailPanel = document.getElementById('detailPanel');
const closeBtn = document.getElementById('closeBtn');

let state = {
  properties: [],
  maxOwned: 2,
  selectedId: null,
  selectedInterior: null,
  furnished: false,
  furnishedMult: 1.32,
};

function post(action, data = {}) {
  fetch(`https://${GetParentResourceName()}/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  });
}

function fmt(n) {
  return `$${Number(n || 0).toLocaleString('lt-LT')}`;
}

function qualityClass(tier) {
  const t = Number(tier) || 1;
  if (t >= 4) return 'q-luxury';
  if (t >= 3) return 'q-good';
  if (t >= 2) return 'q-mid';
  return 'q-low';
}

function interiorPerks(intr) {
  const parts = [`Sandėlis: ${intr.stashSlots || '?'} slot. / ${Math.round((intr.stashWeight || 0) / 1000)} kg`];
  parts.push(intr.hasWardrobe ? 'Drabužinė: taip' : 'Drabužinė: ne');
  return parts.join(' · ');
}

function interiorPrice(intr) {
  if (state.furnished) return intr.priceFurnished || intr.price;
  return intr.priceUnfurnished || intr.price;
}

function typeLabel(p) {
  if (p.type === 'house') return 'Namas';
  if (p.type === 'mansion') return 'Mansion';
  return 'Butas';
}

function getSelectedProperty() {
  return state.properties.find((p) => p.id === state.selectedId);
}

function renderDistrictFilter() {
  const districts = {};
  state.properties.forEach((p) => {
    districts[p.district] = p.districtLabel || p.district;
  });
  districtFilter.innerHTML = '<option value="">Visi rajonai</option>';
  Object.keys(districts).sort().forEach((key) => {
    const opt = document.createElement('option');
    opt.value = key;
    opt.textContent = districts[key];
    districtFilter.appendChild(opt);
  });
}

function filteredProperties() {
  const dist = districtFilter.value;
  const onlyFree = onlyAvailable.checked;
  return state.properties.filter((p) => {
    if (dist && p.district !== dist) return false;
    if (onlyFree && p.owned && !p.ownedByMe) return false;
    if (onlyFree && p.owned) return false;
    return true;
  });
}

function renderList() {
  propertyList.innerHTML = '';
  const list = filteredProperties();
  list.forEach((p) => {
    const card = document.createElement('div');
    let cls = 'prop-card';
    if (p.id === state.selectedId) cls += ' active';
    if (p.owned && !p.ownedByMe) cls += ' sold';
    if (p.ownedByMe) cls += ' mine';
    card.className = cls;

    let badge = '<span class="badge badge-free">Laisvas</span>';
    if (p.ownedByMe) badge = '<span class="badge badge-mine">Mano</span>';
    else if (p.owned) badge = '<span class="badge badge-sold">Parduota</span>';

    card.innerHTML = `
      <div class="prop-title">${p.label} ${badge}</div>
      <div class="prop-meta">${p.districtLabel} · ${typeLabel(p)} · ${p.classLabel || p.class || ''}</div>
      <div class="prop-price">nuo ${fmt(p.minPrice)}</div>
    `;

    card.onclick = () => {
      state.selectedId = p.id;
      state.selectedInterior = p.interiors && p.interiors[0] ? p.interiors[0].key : null;
      state.furnished = false;
      renderList();
      renderDetail();
    };
    propertyList.appendChild(card);
  });
}

function renderDetail() {
  const p = getSelectedProperty();
  if (!p) {
    detailPanel.innerHTML = '<div class="detail-empty">Pasirinkite objektą</div>';
    return;
  }

  if (p.ownedByMe) {
    const ownedIntr = (p.interiors || []).find((i) => i.key === p.ownedInteriorKey);
    const q = p.ownedQualityLabel
      ? `<span class="quality-pill ${qualityClass(ownedIntr && ownedIntr.tier)}">${p.ownedQualityLabel}</span>`
      : '';
    const furn = p.ownedFurnished ? 'Su baldais (įrengta)' : 'Be baldų (galite įsirengti patys)';
    const insideNote = ownedIntr && ownedIntr.hasWardrobe ? 'įėjimas, sandėliukas, drabužinė' : 'įėjimas, sandėliukas (be drabužinės)';
    detailPanel.innerHTML = `
      <h2>${p.label}</h2>
      <p class="sub">${p.districtLabel} · ${p.classLabel || ''} — jūsų nuosavybė ${q}</p>
      <p class="sub">Interjeras: <strong>${p.ownedInteriorLabel || '—'}</strong></p>
      <p class="sub">${furn}</p>
      <p class="price-total">Eikite prie durų žemėlapyje — ${insideNote}.</p>
      <p class="sub">Prie durų: užraktas ir raktų dalijimas (įėjimas + sandėliukas).</p>
      <div class="actions">
        <button class="btn btn-ghost" id="wpBtn">GPS į objektą</button>
      </div>
    `;
    document.getElementById('wpBtn').onclick = () => post('setWaypoint', { propertyId: p.id });
    return;
  }

  if (p.owned) {
    detailPanel.innerHTML = `
      <h2>${p.label}</h2>
      <p class="sub">Šis objektas jau turi savininką.</p>
    `;
    return;
  }

  const interiors = p.interiors || [];
  let interiorHtml = '<div class="interior-list">';
  interiors.forEach((intr) => {
    const sel = state.selectedInterior === intr.key ? ' selected' : '';
    const qCls = qualityClass(intr.tier);
    interiorHtml += `
      <div class="interior-opt${sel}" data-key="${intr.key}">
        <div>
          <div class="name-row">
            <span class="name">${intr.label}</span>
            <span class="quality-pill ${qCls}">${intr.qualityLabel || '—'}</span>
          </div>
          <div class="desc">${intr.description || ''}</div>
          <div class="perks">${interiorPerks(intr)}</div>
        </div>
        <div class="price">${fmt(interiorPrice(intr))}</div>
      </div>
    `;
  });
  interiorHtml += '</div>';

  const selected = interiors.find((i) => i.key === state.selectedInterior);
  const total = selected ? interiorPrice(selected) : p.minPrice;
  const furnChecked = state.furnished ? 'checked' : '';
  const unfurnChecked = !state.furnished ? 'checked' : '';

  detailPanel.innerHTML = `
    <h2>${p.label}</h2>
    <p class="sub">${p.districtLabel} · Klasė: <strong>${p.classLabel || p.class}</strong></p>
    <p class="buy-hint">Interjerai priklauso nuo būsto klasės — pigus būstas negali turėti prabangaus interjero.</p>
    <p>Pasirinkite interjerą:</p>
    ${interiorHtml}
    <p>Įrengimas:</p>
    <div class="furn-options">
      <label class="furn-opt"><input type="radio" name="furn" value="0" ${unfurnChecked}/> Be baldų (pigiau) — patys įsirengiate</label>
      <label class="furn-opt"><input type="radio" name="furn" value="1" ${furnChecked}/> Su baldais (+${Math.round(((state.furnishedMult || 1.32) - 1) * 100)}%) — iškart įrengta</label>
    </div>
    <div class="price-total">Suma: ${fmt(total)}</div>
    <div class="actions">
      <button class="btn btn-primary" id="buyBtn">Pirkti iš banko</button>
      <button class="btn btn-ghost" id="wpBtn2">GPS</button>
    </div>
  `;

  detailPanel.querySelectorAll('.interior-opt').forEach((el) => {
    el.onclick = () => {
      state.selectedInterior = el.dataset.key;
      renderDetail();
    };
  });

  detailPanel.querySelectorAll('input[name="furn"]').forEach((el) => {
    el.onchange = () => {
      state.furnished = el.value === '1';
      renderDetail();
    };
  });

  document.getElementById('wpBtn2').onclick = () => post('setWaypoint', { propertyId: p.id });
  document.getElementById('buyBtn').onclick = () => {
    if (!state.selectedInterior) return;
    const btn = document.getElementById('buyBtn');
    btn.disabled = true;
    post('purchase', {
      propertyId: p.id,
      interiorKey: state.selectedInterior,
      furnished: state.furnished,
    });
    setTimeout(() => { btn.disabled = false; }, 1200);
  };
}

function openUI(data) {
  state.properties = data.properties || [];
  state.maxOwned = data.maxOwned || 2;
  state.furnishedMult = data.furnishedMult || 1.32;
  agencyTitle.textContent = data.agencyLabel || 'Dynasty 8';
  hintText.textContent =
    'Klasė nustato leidžiamus interjerus. Pasirinkite Su baldais arba Be baldų. Max ' +
    state.maxOwned +
    ' obj. / žaidėjas.';
  state.selectedId = null;
  state.selectedInterior = null;
  state.furnished = false;
  renderDistrictFilter();
  renderList();
  renderDetail();
  app.classList.remove('hidden');
}

window.addEventListener('message', (e) => {
  const msg = e.data;
  if (msg.action === 'open') openUI(msg.data || {});
  if (msg.action === 'refresh' && msg.data && msg.data.properties) {
    state.properties = msg.data.properties;
    renderList();
    renderDetail();
  }
});

closeBtn.onclick = () => {
  app.classList.add('hidden');
  post('close');
};

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') closeBtn.click();
});

districtFilter.onchange = () => renderList();
onlyAvailable.onchange = () => renderList();
