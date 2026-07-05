/* MRP narkotikų mini-žaidimų UI — modernus komponentų rinkinys */
window.MiniGameUI = (() => {
  const THEMES = {
    thc:      { accent: '#a78bfa', accent2: '#7c3aed', glow: 'rgba(167,139,250,0.38)', label: 'THC', icon: '🧪' },
    alcohol:  { accent: '#fbbf24', accent2: '#d97706', glow: 'rgba(251,191,36,0.32)', label: 'Samagonas', icon: '🥃' },
    vape:     { accent: '#67e8f9', accent2: '#0891b2', glow: 'rgba(103,232,249,0.3)', label: 'Vape', icon: '💨' },
    weed:     { accent: '#4ade80', accent2: '#16a34a', glow: 'rgba(74,222,128,0.35)', label: 'Kanapės', icon: '🌿' },
    heroin:   { accent: '#f87171', accent2: '#dc2626', glow: 'rgba(248,113,113,0.3)', label: 'Heroinas', icon: '💉' },
    meth:     { accent: '#38bdf8', accent2: '#0284c7', glow: 'rgba(56,189,248,0.32)', label: 'Metamfetaminas', icon: '💎' },
    pills:    { accent: '#fb923c', accent2: '#ea580c', glow: 'rgba(251,146,60,0.3)', label: 'Tabletės', icon: '💊' },
    mushroom: { accent: '#c084fc', accent2: '#9333ea', glow: 'rgba(192,132,252,0.3)', label: 'Grybai', icon: '🍄' },
    cocaine:  { accent: '#e2e8f0', accent2: '#64748b', glow: 'rgba(226,232,240,0.2)', label: 'Kokainas', icon: '❄️' },
    amp:      { accent: '#fde047', accent2: '#ca8a04', glow: 'rgba(253,224,71,0.28)', label: 'Amfetaminas', icon: '⚡' },
    default:  { accent: '#c084fc', accent2: '#7c3aed', glow: 'rgba(192,132,252,0.32)', label: 'Gamyba', icon: '⚗️' },
  };

  const LEVEL_RING = { 1: '#a78bfa', 2: '#4ade80', 3: '#f87171' };

  function themeFor(drug) {
    return THEMES[String(drug || 'default').toLowerCase()] || THEMES.default;
  }

  function applyTheme(drug, difficulty) {
    const box = document.querySelector('#mgSchedule .sch-box');
    if (!box) return;
    const t = themeFor(drug);
    box.style.setProperty('--mg-accent', t.accent);
    box.style.setProperty('--mg-accent-2', t.accent2);
    box.style.setProperty('--mg-glow', t.glow);
    const lvl = Math.min(3, Math.max(1, Number(difficulty) || 1));
    box.style.setProperty('--mg-level', LEVEL_RING[lvl] || LEVEL_RING[1]);
    box.dataset.drugTheme = String(drug || 'default').toLowerCase();
    const orb = document.getElementById('schDrugIcon');
    if (orb) orb.textContent = t.icon;
  }

  function renderStepDots(current, total) {
    const wrap = document.getElementById('schStepDots');
    if (!wrap) return;
    wrap.innerHTML = '';
    for (let i = 1; i <= total; i += 1) {
      const dot = document.createElement('span');
      dot.className = 'sch-step-dot';
      if (i < current) dot.classList.add('done');
      if (i === current) dot.classList.add('active');
      wrap.appendChild(dot);
    }
  }

  function clearBoard() {
    if (typeof schBoard !== 'undefined' && schBoard) schBoard.innerHTML = '';
  }

  function scene(className) {
    const el = document.createElement('div');
    el.className = `mg-scene ${className || ''}`.trim();
    return el;
  }

  function panel(className, inner) {
    const el = document.createElement('div');
    el.className = `mg-panel ${className || ''}`.trim();
    if (typeof inner === 'string') el.innerHTML = inner;
    return el;
  }

  function mount(el) {
    clearBoard();
    schBoard.appendChild(el);
    return el;
  }

  function iconHero(icon, subtitle) {
    const wrap = panel('mg-hero');
    wrap.innerHTML = `
      <div class="mg-hero-icon">${icon || '⚗️'}</div>
      ${subtitle ? `<p class="mg-hero-sub">${subtitle}</p>` : ''}
    `;
    return wrap;
  }

  function actionBtn(label, opts = {}) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `mg-action ${opts.variant || 'primary'} ${opts.large ? 'mg-action--lg' : ''}`.trim();
    b.innerHTML = opts.icon
      ? `<span class="mg-action-icon">${opts.icon}</span><span class="mg-action-label">${label}</span>`
      : label;
    if (opts.onClick) b.onclick = opts.onClick;
    return b;
  }

  function gaugeHold(opts) {
    const {
      label, speed = 1.5, need = 55, zoneWidth = 22,
      zoneLeft = 25 + Math.random() * 38,
      timeout = 14000, onSuccess, onFail, hintEl,
    } = opts;

    const root = scene('mg-scene-gauge');
    const wrap = panel('mg-gauge-wrap');
    const track = document.createElement('div');
    track.className = 'mg-gauge-track';
    const zone = document.createElement('div');
    zone.className = 'mg-gauge-zone';
    zone.style.left = `${zoneLeft}%`;
    zone.style.width = `${zoneWidth}%`;
    const needle = document.createElement('div');
    needle.className = 'mg-gauge-needle';
    track.append(zone, needle);
    const hint = document.createElement('p');
    hint.className = 'mg-gauge-hint';
    hint.innerHTML = '<kbd>SPACE</kbd> Laikyk adatą spalvotoje zonoje';
    wrap.append(track, hint);
    root.appendChild(wrap);
    mount(root);

    let pos = 10;
    let dir = speed;
    let hold = 0;
    const iv = setInterval(() => {
      pos += dir;
      if (pos >= 98) dir = -speed;
      if (pos <= 2) dir = speed;
      needle.style.left = `${pos}%`;
      const inZone = pos >= zoneLeft && pos <= zoneLeft + zoneWidth;
      if (inZone) hold += 1;
      const pct = Math.min(100, Math.floor((hold / need) * 100));
      if (hintEl) hintEl.textContent = `${label || 'Stabilizacija'} — ${pct}%`;
      if (hold >= need) { cleanup(); if (onSuccess) onSuccess(); }
    }, 40);

    function cleanup() {
      clearInterval(iv);
      window.removeEventListener('keydown', onKey);
      if (scheduleTimer) { clearTimeout(scheduleTimer); scheduleTimer = null; }
    }
    function fail() {
      cleanup();
      if (onFail) onFail();
      else if (typeof failSchedule === 'function') failSchedule();
    }
    const onKey = (ev) => {
      if (ev.code !== 'Space') return;
      ev.preventDefault();
      if (!(pos >= zoneLeft && pos <= zoneLeft + zoneWidth)) fail();
    };
    window.addEventListener('keydown', onKey);
    scheduleTimer = setTimeout(fail, timeout);
    return { cleanup, fail };
  }

  function clickBoard(opts) {
    const { title, total, positions, icon, onComplete } = opts;
    const root = scene('mg-scene-click');
    const board = panel('mg-click-board');
    board.appendChild(iconHero(icon || '🎯', title));
    const points = document.createElement('div');
    points.className = 'mg-click-points';
    let done = 0;
    positions.slice(0, total).forEach((pos, i) => {
      const p = document.createElement('button');
      p.type = 'button';
      p.className = 'mg-click-spot';
      p.style.top = pos.top;
      p.style.left = pos.left;
      p.innerHTML = `<span>${i + 1}</span>`;
      p.onclick = () => {
        if (p.classList.contains('done')) return;
        p.classList.add('done');
        done += 1;
        if (done >= total && onComplete) onComplete();
      };
      points.appendChild(p);
    });
    board.appendChild(points);
    root.appendChild(board);
    mount(root);
  }

  function multiTap(opts) {
    const { icon, label, need, onDone } = opts;
    const root = scene('mg-scene-tap');
    let count = 0;
    const counter = document.createElement('p');
    counter.className = 'mg-tap-counter';
    counter.textContent = `0 / ${need}`;
    const btn = actionBtn(label || 'Tęsti', { icon, large: true, variant: 'primary' });
    btn.onclick = () => {
      count += 1;
      counter.textContent = `${count} / ${need}`;
      btn.classList.add('mg-action--pulse');
      setTimeout(() => btn.classList.remove('mg-action--pulse'), 120);
      if (count >= need && onDone) onDone();
    };
    root.append(iconHero(icon, label), btn, counter);
    mount(root);
  }

  function sliderBlend(opts) {
    const { target, onConfirm } = opts;
    const root = scene('mg-scene-blend');
    const row = panel('mg-blend-row');
    const a = document.createElement('input');
    a.type = 'range'; a.min = 0; a.max = 100; a.value = 10; a.className = 'mg-range';
    const b = document.createElement('input');
    b.type = 'range'; b.min = 0; b.max = 100; b.value = 80; b.className = 'mg-range';
    const preview = document.createElement('div');
    preview.className = 'mg-blend-preview';
    const sync = () => {
      preview.style.background = `linear-gradient(135deg, hsl(${Number(a.value) * 2},70%,45%), hsl(${Number(b.value) * 2},60%,50%))`;
    };
    a.oninput = sync; b.oninput = sync; sync();
    row.append(a, preview, b);
    root.append(row, actionBtn('Patvirtinti mišinį', { variant: 'primary', onClick: () => {
      const mid = (Number(a.value) + Number(b.value)) / 2;
      if (Math.abs(mid - target) > 18) { if (typeof failSchedule === 'function') failSchedule(); return; }
      if (onConfirm) onConfirm();
    }}));
    mount(root);
  }

  function vesselFill(opts) {
    const { icon, label, steps, onStep, onComplete } = opts;
    const root = scene('mg-scene-vessel');
    let step = 0;
    const vessel = panel('mg-vessel');
    vessel.innerHTML = `<span class="mg-vessel-icon">${icon || '🫙'}</span><div class="mg-vessel-fill" id="mgVesselFill"></div>`;
    const btn = actionBtn(label || 'Pildyti', {
      variant: 'primary',
      onClick: () => {
        step += 1;
        const fill = document.getElementById('mgVesselFill');
        const need = steps || 1;
        if (fill) fill.style.height = `${Math.min(88, step * (82 / need))}%`;
        if (onStep) onStep(step, need);
        if (step >= need && onComplete) onComplete();
      },
    });
    root.append(vessel, btn);
    mount(root);
  }

  function spawnCatcher(opts) {
    const { icon, need, spawnInterval, onComplete } = opts;
    const root = scene('mg-scene-spawn');
    let picked = 0;
    const arena = panel('mg-arena');
    root.appendChild(arena);
    mount(root);
    function spawn() {
      if (picked >= need) return;
      const m = document.createElement('button');
      m.type = 'button';
      m.className = 'mg-spawn-item';
      m.textContent = icon || '●';
      m.style.left = `${12 + Math.random() * 76}%`;
      m.style.top = `${15 + Math.random() * 65}%`;
      m.onclick = () => {
        m.remove();
        picked += 1;
        if (typeof schHint !== 'undefined' && schHint) schHint.textContent = `Surinkta ${picked}/${need}`;
        if (picked >= need && onComplete) onComplete();
        else setTimeout(spawn, spawnInterval || 420);
      };
      arena.appendChild(m);
    }
    spawn();
  }

  function stripRow(opts) {
    const { icon, need, onComplete } = opts;
    const root = scene('mg-scene-branch');
    let stripped = 0;
    const branch = panel('mg-branch');
    ['10%', '26%', '42%', '58%', '74%', '90%'].slice(0, need).forEach((left) => {
      const leaf = document.createElement('button');
      leaf.type = 'button';
      leaf.className = 'mg-branch-leaf';
      leaf.style.left = left;
      leaf.textContent = icon || '🍃';
      leaf.onclick = () => {
        if (leaf.classList.contains('done')) return;
        leaf.classList.add('done');
        stripped += 1;
        if (stripped >= need && onComplete) onComplete();
        else if (typeof schHint !== 'undefined' && schHint) schHint.textContent = `${stripped}/${need}`;
      };
      branch.appendChild(leaf);
    });
    root.appendChild(branch);
    mount(root);
  }

  function blisterPack(slots, onFilled) {
    const root = scene('mg-scene-blister');
    let filled = 0;
    const blister = panel('mg-blister');
    for (let i = 0; i < slots; i += 1) {
      const slot = document.createElement('button');
      slot.type = 'button';
      slot.className = 'mg-blister-slot';
      slot.textContent = '💊';
      slot.onclick = () => {
        if (slot.classList.contains('done')) return;
        slot.classList.add('done');
        filled += 1;
        if (filled >= slots && onFilled) onFilled();
      };
      blister.appendChild(slot);
    }
    root.appendChild(blister);
    mount(root);
  }

  function keySequence(opts) {
    const { keys = ['Q', 'W', 'E'], rounds, onSuccess, onFail } = opts;
    const seq = [];
    for (let i = 0; i < rounds; i += 1) seq.push(keys[Math.floor(Math.random() * keys.length)]);
    let idx = 0;
    const root = scene('mg-scene-seq');
    const panelEl = panel('mg-seq-panel');
    const display = document.createElement('div');
    display.className = 'mg-seq-display';
    display.textContent = seq.join('  →  ');
    const keysRow = document.createElement('div');
    keysRow.className = 'mg-seq-keys';
    keys.forEach((k) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'mg-seq-key';
      b.textContent = k;
      b.onclick = () => {
        if (k !== seq[idx]) {
          if (onFail) onFail();
          else if (typeof failSchedule === 'function') failSchedule();
          return;
        }
        b.classList.add('hit');
        idx += 1;
        if (idx >= seq.length && onSuccess) onSuccess();
      };
      keysRow.appendChild(b);
    });
    panelEl.append(iconHero('💎', 'Stabilizuok kristalizaciją — sek seką'), display, keysRow);
    root.appendChild(panelEl);
    mount(root);
  }

  function pressMachine(opts) {
    const { need, icon, label, onDone } = opts;
    const root = scene('mg-scene-press');
    let presses = 0;
    const press = document.createElement('button');
    press.type = 'button';
    press.className = 'mg-press-machine';
    press.innerHTML = `<span>${icon || '💊'}</span><small>${label || 'Presuoti'} ${presses}/${need}</small>`;
    press.onclick = () => {
      presses += 1;
      press.querySelector('small').textContent = `${label || 'Presuoti'} ${presses}/${need}`;
      if (presses >= need && onDone) onDone();
    };
    root.append(iconHero(icon, label), press);
    mount(root);
  }

  function washStation(opts) {
    const { need, onDone } = opts;
    let washed = 0;
    const root = scene('mg-scene-wash');
    const tub = panel('mg-wash-tub');
    tub.innerHTML = '<div class="mg-wash-tub-icon">🧪 Cheminis tirpalas</div>';
    for (let i = 0; i < need; i += 1) {
      const leaf = document.createElement('button');
      leaf.type = 'button';
      leaf.className = 'mg-wash-leaf';
      leaf.textContent = '🍃';
      leaf.onclick = () => {
        if (leaf.classList.contains('done')) return;
        leaf.classList.add('done');
        washed += 1;
        if (washed >= need) {
          tub.appendChild(actionBtn('Maišyti tirpalą', {
            icon: '⚗️', variant: 'primary', large: true,
            onClick: () => { if (onDone) onDone(); },
          }));
        }
      };
      tub.appendChild(leaf);
    }
    root.appendChild(tub);
    mount(root);
  }

  function packBagFlow(opts) {
    const { icon, onDone } = opts;
    let step = 1;

    function renderWeigh() {
      const root = scene('mg-scene-pack');
      const row = panel('mg-pack-row');
      const scale = document.createElement('div');
      scale.className = 'mg-pack-slot';
      scale.innerHTML = `<span>⚖️</span><small id="mgWeight">0.00 g</small>`;
      const prod = document.createElement('div');
      prod.className = 'mg-pack-slot';
      prod.innerHTML = `<span>${icon || '🌿'}</span><small>Produktas</small>`;
      row.append(scale, prod);
      root.append(row, actionBtn('Sverti', { variant: 'primary', onClick: () => {
        const w = document.getElementById('mgWeight');
        if (w) w.textContent = `${(1.8 + Math.random() * 0.4).toFixed(2)} g`;
        setTimeout(renderFill, 450);
      }}));
      mount(root);
    }

    function renderFill() {
      step = 2;
      const root = scene('mg-scene-pack');
      let picked = false;
      const row = panel('mg-pack-row');
      const prod = document.createElement('button');
      prod.type = 'button';
      prod.className = 'mg-pack-slot';
      prod.innerHTML = `<span>${icon || '🌿'}</span><small>Pasirink</small>`;
      prod.onclick = () => { picked = true; prod.classList.add('active'); };
      const bag = document.createElement('button');
      bag.type = 'button';
      bag.className = 'mg-pack-slot';
      bag.innerHTML = '<span>👜</span><small>Maišelis</small>';
      bag.onclick = () => {
        if (!picked) { if (schHint) schHint.textContent = 'Pirma pasirink produktą!'; return; }
        renderSeal();
      };
      row.append(prod, bag);
      root.appendChild(row);
      mount(root);
    }

    function renderSeal() {
      step = 3;
      multiTap({ icon: '👜', label: 'Užlydinti maišelį', need: 3, onDone: () => {
        const root = scene('mg-scene-success');
        root.innerHTML = '<div class="mg-success"><div class="mg-success-icon">✓</div><p>Supakuota sėkmingai</p></div>';
        root.appendChild(actionBtn('Baigti', { variant: 'primary', onClick: () => {
          if (onDone) onDone();
          else if (typeof postSchedule === 'function') postSchedule(true, { mistakes: 0 });
        }}));
        mount(root);
      }});
    }

    renderWeigh();
  }

  function foilFold(opts) {
    const { need, onFolded } = opts;
    const root = scene('mg-scene-foil');
    let folds = 0;
    const foil = document.createElement('button');
    foil.type = 'button';
    foil.className = 'mg-foil-card';
    foil.innerHTML = `<span>📄</span><small>Sulankstyti 0/${need}</small>`;
    foil.onclick = () => {
      folds += 1;
      foil.style.transform = `rotate(${folds * 5}deg) scale(${1 - folds * 0.035})`;
      foil.querySelector('small').textContent = `Sulankstyti ${folds}/${need}`;
      if (folds >= need && onFolded) onFolded();
    };
    root.append(iconHero('📄', 'Sulankstyk foliją su produktu'), foil);
    mount(root);
  }

  function successScreen(message, onDone) {
    const root = scene('mg-scene-success');
    root.innerHTML = `<div class="mg-success"><div class="mg-success-icon">✓</div><p>${message || 'Atlikta'}</p></div>`;
    root.appendChild(actionBtn('Baigti', { variant: 'primary', onClick: onDone }));
    mount(root);
  }

  return {
    THEMES, themeFor, applyTheme, renderStepDots, clearBoard, scene, panel, mount,
    iconHero, actionBtn, gaugeHold, clickBoard, multiTap, sliderBlend, vesselFill,
    spawnCatcher, stripRow, blisterPack, keySequence, pressMachine, washStation,
    packBagFlow, foilFold, successScreen,
  };
})();
