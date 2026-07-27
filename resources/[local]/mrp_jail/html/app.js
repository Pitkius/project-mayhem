(() => {
  const hud = document.getElementById('hud');
  const timeEl = document.getElementById('time');
  const reasonEl = document.getElementById('reason');

  let endsAtMs = 0;
  let tickTimer = null;

  function formatRemaining(ms) {
    const totalSec = Math.max(0, Math.ceil(ms / 1000));
    const m = Math.floor(totalSec / 60);
    const s = totalSec % 60;
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }

  function render() {
    if (!endsAtMs) {
      timeEl.textContent = '00:00';
      return;
    }
    timeEl.textContent = formatRemaining(endsAtMs - Date.now());
  }

  function stopTick() {
    if (tickTimer) {
      clearInterval(tickTimer);
      tickTimer = null;
    }
  }

  function show(data) {
    const remainingSec = Number(data.remainingSeconds) || 0;
    endsAtMs = Date.now() + remainingSec * 1000;
    reasonEl.textContent = data.reason || '—';
    hud.classList.remove('hidden');
    render();
    stopTick();
    tickTimer = setInterval(render, 250);
  }

  function hide() {
    stopTick();
    endsAtMs = 0;
    hud.classList.add('hidden');
  }

  function update(data) {
    if (typeof data.remainingSeconds === 'number') {
      endsAtMs = Date.now() + Math.max(0, data.remainingSeconds) * 1000;
      render();
    }
    if (data.reason) {
      reasonEl.textContent = data.reason;
    }
  }

  window.addEventListener('message', (event) => {
    const msg = event.data || {};
    if (msg.action === 'show') show(msg);
    else if (msg.action === 'hide') hide();
    else if (msg.action === 'update') update(msg);
  });
})();
