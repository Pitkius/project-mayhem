const app = document.getElementById('app');
const btnClose = document.getElementById('btnClose');

function resourceName() {
  try {
    if (typeof GetParentResourceName === 'function') return GetParentResourceName();
  } catch (e) {}
  return 'fivempro_ltpd';
}

function nuiPost(endpoint, data) {
  return fetch(`https://${resourceName()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
  }).then((r) => r.json());
}

window.addEventListener('message', (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === 'open') {
    app.classList.remove('hidden');
    const perms = (d.data && d.data.permissions) || {};
    document.getElementById('tabFine').style.display = perms.fine ? '' : 'none';
    document.getElementById('tabWant').style.display = perms.wanted ? '' : 'none';
    const sel = document.getElementById('finePreset');
    sel.innerHTML = '';
    (d.data.presets || []).forEach((p) => {
      const o = document.createElement('option');
      o.value = p.code;
      o.textContent = `${p.label} (${p.defaultAmount} €)`;
      o.dataset.amount = p.defaultAmount;
      o.dataset.label = p.label;
      sel.appendChild(o);
    });
    sel.onchange = () => {
      const opt = sel.options[sel.selectedIndex];
      document.getElementById('fineAmt').value = opt.dataset.amount || '';
      document.getElementById('fineLabel').value = opt.dataset.label || '';
    };
    if (sel.options.length) sel.onchange();
  }
  if (d.action === 'close') app.classList.add('hidden');
});

btnClose.onclick = () => nuiPost('close', {});

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    e.preventDefault();
    nuiPost('close', {});
  }
});

document.querySelectorAll('.tab').forEach((t) => {
  t.onclick = () => {
    document.querySelectorAll('.tab').forEach((x) => x.classList.remove('active'));
    t.classList.add('active');
    document.querySelectorAll('.panel').forEach((p) => p.classList.add('hidden'));
    const id = 'panel-' + t.dataset.tab;
    const pan = document.getElementById(id);
    if (pan) pan.classList.remove('hidden');
  };
});

document.getElementById('goPerson').onclick = () => {
  const q = document.getElementById('qPerson').value.trim();
  nuiPost('searchPerson', { query: q }).then((res) => renderPerson(res));
};

function renderPerson(res) {
  const el = document.getElementById('personResults');
  el.innerHTML = '';
  if (!res || !res.ok || !res.rows || !res.rows.length) {
    el.innerHTML = '<div class="muted">Nieko nerasta.</div>';
    return;
  }
  res.rows.forEach((r) => {
    const c = document.createElement('div');
    c.className = 'card';
    let html = `<h4>${escapeHtml(r.name || '')}</h4>`;
    html += `<div class="muted">citizenid: ${escapeHtml(r.citizenid)}`;
    if (r.player_id != null) html += ` • server ID: ${escapeHtml(String(r.player_id))}`;
    html += `</div>`;
    if (res.full && r.cash != null) {
      html += `<div>Grynieji: ${r.cash} € | Bankas: ${r.bank} €</div>`;
    }
    html += `<div>Paieškomumas: <strong>${r.wanted_level}</strong> ${escapeHtml(r.wanted_reason || '')}</div>`;
    if (res.full && r.vehicles && r.vehicles.length) {
      html += '<div class="muted">Transportas:</div><ul>';
      r.vehicles.forEach((v) => {
        html += `<li>${escapeHtml(v.plate)} — ${escapeHtml(v.vehicle)} (${v.state})</li>`;
      });
      html += '</ul>';
    }
    if (res.full && r.fines && r.fines.length) {
      html += '<div class="muted">Paskutinės baudos:</div><ul>';
      r.fines.forEach((f) => {
        html += `<li>${f.amount} € — ${escapeHtml(f.reason_label || '')}</li>`;
      });
      html += '</ul>';
    }
    c.innerHTML = html;
    el.appendChild(c);
  });
}

document.getElementById('goVeh').onclick = () => {
  const plate = document.getElementById('qPlate').value.trim();
  nuiPost('searchVehicle', { plate }).then((res) => {
    const el = document.getElementById('vehResults');
    el.innerHTML = '';
    if (!res || !res.ok || !res.row) {
      el.innerHTML = '<div class="muted">Nerasta.</div>';
      return;
    }
    const v = res.row;
    el.innerHTML = `<div class="card"><h4>${escapeHtml(v.plate)}</h4>
      <div>Modelis: ${escapeHtml(v.vehicle)}</div>
      <div>Savininkas: ${escapeHtml(v.owner_name)} (${escapeHtml(v.citizenid)})</div>
      <div>Statusas: ${escapeHtml(v.status)}</div></div>`;
  });
};

document.getElementById('goFine').onclick = () => {
  const preset = document.getElementById('finePreset');
  const opt = preset.options[preset.selectedIndex];
  nuiPost('issueFine', {
    citizenid: document.getElementById('fineCid').value.trim(),
    amount: Number(document.getElementById('fineAmt').value),
    reason_code: opt ? opt.value : '',
    reason_label: document.getElementById('fineLabel').value.trim(),
  });
};

document.getElementById('goWant').onclick = () => {
  nuiPost('setWanted', {
    citizenid: document.getElementById('wantCid').value.trim(),
    level: Number(document.getElementById('wantLvl').value),
    reason: document.getElementById('wantReason').value.trim(),
  });
};

function escapeHtml(s) {
  const d = document.createElement('div');
  d.textContent = s == null ? '' : String(s);
  return d.innerHTML;
}
