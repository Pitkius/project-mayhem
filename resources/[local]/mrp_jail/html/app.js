(() => {
  const hud = document.getElementById('hud');
  const timeEl = document.getElementById('time');
  const reasonEl = document.getElementById('reason');
  const hintEl = document.getElementById('hint');
  const leftLabelEl = document.getElementById('left-label');

  const workEl = document.getElementById('work');
  const workTitleEl = document.getElementById('work-title');
  const workTimeEl = document.getElementById('work-time');
  const workFillEl = document.getElementById('work-fill');

  let endsAtMs = 0;
  let requireWork = false;
  let remainingSec = 0;
  let tickTimer = null;

  let workEndsAt = 0;
  let workDuration = 0;
  let workTimer = null;

  function formatClock(totalSec) {
    totalSec = Math.max(0, Math.ceil(totalSec));
    const m = Math.floor(totalSec / 60);
    const s = totalSec % 60;
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }

  function applyMode() {
    if (requireWork) {
      leftLabelEl.textContent = 'Darbai';
      hintEl.textContent = 'Laikas nestovi. Atlik valymo darbus — 1 darbas = −1';
    } else {
      leftLabelEl.textContent = 'Liko';
      hintEl.textContent = 'Pasirenkami darbai lėktuvnešyje trumpina laiką (−1 min)';
    }
  }

  function render() {
    if (requireWork) {
      const jobs = Math.max(0, Math.ceil(remainingSec / 60));
      timeEl.textContent = String(jobs);
      return;
    }
    if (!endsAtMs) {
      timeEl.textContent = '00:00';
      return;
    }
    timeEl.textContent = formatClock((endsAtMs - Date.now()) / 1000);
  }

  function stopTick() {
    if (tickTimer) {
      clearInterval(tickTimer);
      tickTimer = null;
    }
  }

  function startTick() {
    stopTick();
    if (!requireWork) {
      tickTimer = setInterval(render, 250);
    }
  }

  function renderWork() {
    if (!workEndsAt || !workDuration) return;
    const leftMs = Math.max(0, workEndsAt - Date.now());
    const leftSec = Math.ceil(leftMs / 1000);
    const done = 1 - leftMs / workDuration;
    workTimeEl.textContent = leftSec > 0 ? `${leftSec}s` : '0s';
    workFillEl.style.width = `${Math.min(100, Math.max(0, done * 100))}%`;
    if (leftMs <= 0) stopWorkTick();
  }

  function stopWorkTick() {
    if (workTimer) {
      clearInterval(workTimer);
      workTimer = null;
    }
  }

  function showWork(data) {
    workDuration = Math.max(1, Number(data.durationMs) || 60000);
    workEndsAt = Date.now() + workDuration;
    workTitleEl.textContent = data.label || 'Valymo darbas';
    workFillEl.style.width = '0%';
    workEl.classList.remove('hidden');
    renderWork();
    stopWorkTick();
    workTimer = setInterval(renderWork, 100);
  }

  function hideWork() {
    stopWorkTick();
    workEndsAt = 0;
    workDuration = 0;
    workFillEl.style.width = '0%';
    workEl.classList.add('hidden');
  }

  function show(data) {
    requireWork = data.requireWork === true;
    remainingSec = Math.max(0, Number(data.remainingSeconds) || 0);
    endsAtMs = requireWork ? 0 : Date.now() + remainingSec * 1000;
    reasonEl.textContent = data.reason || '—';
    applyMode();
    hud.classList.remove('hidden');
    render();
    startTick();
  }

  function hide() {
    stopTick();
    endsAtMs = 0;
    remainingSec = 0;
    requireWork = false;
    hud.classList.add('hidden');
  }

  function update(data) {
    if (typeof data.requireWork === 'boolean') {
      requireWork = data.requireWork;
      applyMode();
      startTick();
    }
    if (typeof data.remainingSeconds === 'number') {
      remainingSec = Math.max(0, data.remainingSeconds);
      if (!requireWork) {
        endsAtMs = Date.now() + remainingSec * 1000;
      }
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
    else if (msg.action === 'workShow') showWork(msg);
    else if (msg.action === 'workHide') hideWork();
  });
})();
