const overlay = document.getElementById('overlay');
const fill = document.getElementById('pressureFill');
const policeControls = document.getElementById('policeControls');
const gangControls = document.getElementById('gangControls');

function post(act) {
  fetch(`https://${GetParentResourceName()}/interrUi`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action: act }),
  }).catch(() => {});
}

document.querySelectorAll('.controls .btn[data-act]').forEach((btn) => {
  btn.addEventListener('click', () => post(btn.dataset.act));
});

function showPressure(d) {
  overlay.classList.remove('hidden');
  overlay.classList.add('active');
  if (d.modeLabel) document.getElementById('modeLabel').textContent = d.modeLabel;
  const p = Math.max(0, Math.min(100, Number(d.level) || 0));
  fill.style.width = `${p}%`;
}

function hideAll() {
  overlay.classList.add('hidden');
  overlay.classList.remove('active');
  policeControls.classList.add('hidden');
  gangControls.classList.add('hidden');
}

window.addEventListener('message', (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === 'hide') {
    hideAll();
    return;
  }
  if (d.action === 'pressure') {
    showPressure(d);
    return;
  }
  if (d.action === 'policeControls') {
    policeControls.classList.toggle('hidden', !d.show);
    if (!d.show) gangControls.classList.add('hidden');
    return;
  }
  if (d.action === 'gangControls') {
    gangControls.classList.toggle('hidden', !d.show);
    if (!d.show) policeControls.classList.add('hidden');
  }
});
