/* MRP narkotikų mini-žaidimų UI — modernus komponentų rinkinys */
window.MiniGameUI = (() => {
  const DI = () => window.DrugIcons;

  function resolveIcon(icon, fallback = 'beaker') {
    const lib = DI();
    if (!lib) return '';
    if (!icon) return lib.render(fallback);
    if (typeof icon === 'string' && icon.includes('<svg')) return icon;
    if (typeof lib[icon] === 'function') return lib[icon]();
    return lib.render(icon, 48);
  }

  const THEMES = {
    thc:      { accent: '#a78bfa', accent2: '#7c3aed', glow: 'rgba(167,139,250,0.38)', label: 'THC', icon: 'thcVial' },
    alcohol:  { accent: '#fbbf24', accent2: '#d97706', glow: 'rgba(251,191,36,0.32)', label: 'Samagonas', icon: 'still' },
    vape:     { accent: '#67e8f9', accent2: '#0891b2', glow: 'rgba(103,232,249,0.3)', label: 'Vape', icon: 'vapeDevice' },
    weed:     { accent: '#4ade80', accent2: '#16a34a', glow: 'rgba(74,222,128,0.35)', label: 'Kanapės', icon: 'cannabisLeaf' },
    heroin:   { accent: '#f87171', accent2: '#dc2626', glow: 'rgba(248,113,113,0.3)', label: 'Heroinas', icon: 'syringe' },
    meth:     { accent: '#38bdf8', accent2: '#0284c7', glow: 'rgba(56,189,248,0.32)', label: 'Metamfetaminas', icon: 'methCrystal' },
    pills:    { accent: '#fb923c', accent2: '#ea580c', glow: 'rgba(251,146,60,0.3)', label: 'Tabletės', icon: 'pill' },
    mushroom: { accent: '#c084fc', accent2: '#9333ea', glow: 'rgba(192,132,252,0.3)', label: 'Grybai', icon: 'mushroom' },
    cocaine:  { accent: '#e2e8f0', accent2: '#64748b', glow: 'rgba(226,232,240,0.2)', label: 'Kokainas', icon: 'cocaineBrick' },
    amp:      { accent: '#fde047', accent2: '#ca8a04', glow: 'rgba(253,224,71,0.28)', label: 'Amfetaminas', icon: 'pillPress' },
    default:  { accent: '#c084fc', accent2: '#7c3aed', glow: 'rgba(192,132,252,0.32)', label: 'Gamyba', icon: 'beaker' },
  };

  const LEVEL_RING = { 1: '#a78bfa', 2: '#4ade80', 3: '#f87171' };

  function themeFor(drug) {
    return THEMES[String(drug || 'default').toLowerCase()] || THEMES.default;
  }

  function prepareDrugScreen(drug, mode) {
    applyTheme(drug);
    const key = String(drug || 'default').toLowerCase();
    const modeKey = mode ? String(mode).toLowerCase().replace(/[^a-z0-9_]/g, '') : '';
    const box = document.querySelector('#mgSchedule .sch-box');
    if (box) {
      box.className = 'sch-box';
      box.classList.add(`sch-screen-${key}`);
      if (modeKey) box.classList.add(`sch-mode-${modeKey}`);
    }
    const deco = document.getElementById('schScreenDeco');
    if (deco) {
      deco.className = `sch-screen-deco sch-deco-${key}`;
      if (modeKey) deco.classList.add(`sch-deco-mode-${modeKey}`);
    }
    if (window.MgFx) MgFx.prepareScreen(key, modeKey);
    if (window.MgAudio) MgAudio.ambientFor(key);
  }

  function sfx(name) {
    if (window.MgAudio) MgAudio.play(name);
  }

  function fxBurst(type) {
    if (window.MgFx) MgFx.burst(type);
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
    if (orb) orb.innerHTML = DI() ? DI().drug(drug, 48) : resolveIcon(t.icon);
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
    const drug = document.querySelector('#mgSchedule .sch-box')?.dataset?.drugTheme || '';
    el.className = `mg-scene ${drug ? `mg-scene-${drug}` : ''} ${className || ''}`.trim();
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
      <div class="mg-hero-icon">${resolveIcon(icon)}</div>
      ${subtitle ? `<p class="mg-hero-sub">${subtitle}</p>` : ''}
    `;
    return wrap;
  }

  function actionBtn(label, opts = {}) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `mg-action ${opts.variant || 'primary'} ${opts.large ? 'mg-action--lg' : ''}`.trim();
    const iconHtml = opts.icon ? `<span class="mg-action-icon">${resolveIcon(opts.icon, 'target')}</span>` : '';
    b.innerHTML = iconHtml
      ? `${iconHtml}<span class="mg-action-label">${label}</span>`
      : label;
    if (opts.onClick) {
      b.onclick = (...args) => {
        sfx('tap');
        opts.onClick(...args);
      };
    }
    return b;
  }

  function gaugeHold(opts) {
    const {
      label, speed = 1.5, need = 55, zoneWidth = 22,
      zoneLeft = 25 + Math.random() * 38,
      timeout = 14000, onSuccess, onFail, hintEl,
    } = opts;

    const root = scene('mg-scene-gauge');
    if (opts.prepend) root.appendChild(opts.prepend);
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
      if (hold >= need) { cleanup(); sfx('synth'); if (onSuccess) onSuccess(); }
    }, 40);

    function cleanup() {
      clearInterval(iv);
      window.removeEventListener('keydown', onKey);
      if (scheduleTimer) { clearTimeout(scheduleTimer); scheduleTimer = null; }
    }
    function fail() {
      cleanup();
      if (window.MgFx) MgFx.shake(1.2);
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
    board.appendChild(iconHero(icon || 'target', title));
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
        sfx('click');
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
      sfx('tap');
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
    vessel.innerHTML = `<span class="mg-vessel-icon">${resolveIcon(icon, 'moonshineJar')}</span><div class="mg-vessel-fill" id="mgVesselFill"></div>`;
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
      m.innerHTML = resolveIcon(icon, 'target');
      m.style.left = `${12 + Math.random() * 76}%`;
      m.style.top = `${15 + Math.random() * 65}%`;
      m.onclick = () => {
        sfx('click');
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

  const COCA_LEAF_SLOTS = [
    { left: '53.3%', top: '14.6%' },  /* viršus — centrinė šakelė */
    { left: '7.5%', top: '26.2%' },   /* kairė — tolimiausia šakelė */
    { left: '92.5%', top: '26.2%' },  /* dešinė — tolimiausia šakelė */
    { left: '13.3%', top: '33.8%' },  /* viršutinė kairė */
    { left: '86.7%', top: '33.8%' },  /* viršutinė dešinė */
  ];

  function buildCocaTreeSvg() {
  return `<svg viewBox="0 0 240 260" xmlns="http://www.w3.org/2000/svg" class="mg-coca-svg" aria-hidden="true">
    <defs>
      <linearGradient id="mgCocaWood" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#5c3d1e"/>
        <stop offset="42%" stop-color="#b8895a"/>
        <stop offset="100%" stop-color="#6b4423"/>
      </linearGradient>
      <linearGradient id="mgCocaSoil" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" stop-color="#c49a6c"/>
        <stop offset="100%" stop-color="#7a5535"/>
      </linearGradient>
      <radialGradient id="mgCocaGrass" cx="50%" cy="30%" r="70%">
        <stop offset="0%" stop-color="#72c35a"/>
        <stop offset="100%" stop-color="#4d9a42"/>
      </radialGradient>
    </defs>

    <ellipse cx="120" cy="252" rx="54" ry="5" fill="rgba(0,0,0,0.22)"/>

    <path d="M64 236 C64 218, 96 210, 120 210 C144 210, 176 218, 176 236 C176 248, 152 254, 120 254 C88 254, 64 248, 64 236 Z" fill="url(#mgCocaSoil)"/>
    <path d="M70 228 C92 218, 110 214, 120 213 C130 214, 148 218, 170 228 C160 220, 140 216, 120 216 C100 216, 80 220, 70 228 Z" fill="url(#mgCocaGrass)"/>
    <path d="M82 221 Q84 212 87 221" stroke="#3d8a35" stroke-width="2.2" fill="none" stroke-linecap="round"/>
    <path d="M153 221 Q155 212 158 221" stroke="#3d8a35" stroke-width="2.2" fill="none" stroke-linecap="round"/>

    <path d="M106 238 L90 256" stroke="#3d2817" stroke-width="5" stroke-linecap="round"/>
    <path d="M120 240 L118 259" stroke="#3d2817" stroke-width="6" stroke-linecap="round"/>
    <path d="M134 238 L150 256" stroke="#3d2817" stroke-width="5" stroke-linecap="round"/>
    <path d="M98 236 L80 249" stroke="#4a3220" stroke-width="3.5" stroke-linecap="round"/>
    <path d="M142 236 L160 249" stroke="#4a3220" stroke-width="3.5" stroke-linecap="round"/>

    <path d="M120 226 L120 185" stroke="url(#mgCocaWood)" stroke-width="16" stroke-linecap="round" fill="none"/>

    <path d="M120 185 Q90 185 60 145" stroke="#b8895a" stroke-width="10" stroke-linecap="round" fill="none"/>
    <path d="M120 185 Q150 185 180 145" stroke="#b8895a" stroke-width="10" stroke-linecap="round" fill="none"/>

    <path d="M120 185 L120 155" stroke="#b8895a" stroke-width="13" stroke-linecap="round" fill="none"/>

    <path d="M120 155 Q105 150 85 110" stroke="#9a7048" stroke-width="9" stroke-linecap="round" fill="none"/>
    <path d="M120 155 Q135 150 155 110" stroke="#9a7048" stroke-width="9" stroke-linecap="round" fill="none"/>

    <path d="M120 155 L120 85" stroke="#9a7048" stroke-width="9" stroke-linecap="round" fill="none"/>
  </svg>`;
}

  function stripRow(opts) {
    const { icon, need, onComplete } = opts;
    const root = scene('mg-scene-branch');
    let stripped = 0;

    const tree = document.createElement('div');
    tree.className = 'mg-coca-tree';
    tree.innerHTML = buildCocaTreeSvg();

    COCA_LEAF_SLOTS.slice(0, need).forEach((slot) => {
      const leaf = document.createElement('button');
      leaf.type = 'button';
      leaf.className = 'mg-branch-leaf mg-coca-leaf';
      leaf.style.left = slot.left;
      leaf.style.top = slot.top;
      leaf.innerHTML = resolveIcon(icon, 'cocaLeaf');
      leaf.onclick = () => {
        if (leaf.classList.contains('done')) return;
        sfx('click');
        leaf.classList.add('done');
        stripped += 1;
        if (typeof schHint !== 'undefined' && schHint) schHint.textContent = `${stripped}/${need}`;
        if (stripped >= need && onComplete) onComplete();
      };
      tree.appendChild(leaf);
    });

    root.appendChild(tree);
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
      slot.innerHTML = resolveIcon('pill');
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
    panelEl.append(iconHero('methCrystal', 'Stabilizuok kristalizaciją — sek seką'), display, keysRow);
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
    press.innerHTML = `${resolveIcon(icon, 'pillPress')}<small>${label || 'Presuoti'} ${presses}/${need}</small>`;
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
    tub.innerHTML = `<div class="mg-wash-tub-icon">${resolveIcon('beaker')}<span>Cheminis tirpalas</span></div>`;
    for (let i = 0; i < need; i += 1) {
      const leaf = document.createElement('button');
      leaf.type = 'button';
      leaf.className = 'mg-wash-leaf';
      leaf.innerHTML = resolveIcon('cocaLeaf');
      leaf.onclick = () => {
        if (leaf.classList.contains('done')) return;
        leaf.classList.add('done');
        washed += 1;
        if (washed >= need) {
          tub.appendChild(actionBtn('Maišyti tirpalą', {
            icon: 'beaker', variant: 'primary', large: true,
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
      scale.innerHTML = `${resolveIcon('scale')}<small id="mgWeight">0.00 g</small>`;
      const prod = document.createElement('div');
      prod.className = 'mg-pack-slot';
      prod.innerHTML = `${resolveIcon(icon, 'cannabisLeaf')}<small>Produktas</small>`;
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
      prod.innerHTML = `${resolveIcon(icon, 'cannabisLeaf')}<small>Pasirink</small>`;
      prod.onclick = () => { picked = true; prod.classList.add('active'); };
      const bag = document.createElement('button');
      bag.type = 'button';
      bag.className = 'mg-pack-slot';
      bag.innerHTML = `${resolveIcon('bag')}<small>Maišelis</small>`;
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
      multiTap({ icon: 'bag', label: 'Užlydinti maišelį', need: 3, onDone: () => {
        const root = scene('mg-scene-success');
        root.innerHTML = `<div class="mg-success"><div class="mg-success-icon">${resolveIcon('check')}</div><p>Supakuota sėkmingai</p></div>`;
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
    foil.innerHTML = `${resolveIcon('foil')}<small>Sulankstyti 0/${need}</small>`;
    foil.onclick = () => {
      folds += 1;
      foil.style.transform = `rotate(${folds * 5}deg) scale(${1 - folds * 0.035})`;
      foil.querySelector('small').textContent = `Sulankstyti ${folds}/${need}`;
      if (folds >= need && onFolded) onFolded();
    };
    root.append(iconHero('foil', 'Sulankstyk foliją su produktu'), foil);
    mount(root);
  }

  function successScreen(message, onDone) {
    sfx('success');
    fxBurst('success');
    const root = scene('mg-scene-success');
    root.innerHTML = `<div class="mg-success"><div class="mg-success-icon">${resolveIcon('check')}</div><p>${message || 'Atlikta'}</p></div>`;
    root.appendChild(actionBtn('Baigti', { variant: 'primary', onClick: onDone }));
    mount(root);
  }

  /** Schedule-1: laikyk mygtuką — optimalus greitis, pildyk indą iki tikslo */
  function pourHold(opts) {
    const {
      label = 'Pilti', target = 100, tolerance = 6, icon = 'moonshineJar',
      onSuccess, onFail, hintEl,
    } = opts;
    const root = scene('mg-scene-pour');
    let fill = 0;
    let speed = 0;
    let hold = false;
    let overflows = 0;

    const vessel = panel('mg-pour-vessel');
    vessel.innerHTML = `
      <div class="mg-pour-icon">${resolveIcon(icon, 'moonshineJar')}</div>
      <div class="mg-pour-fill-track"><div class="mg-pour-fill" id="mgPourFill"></div></div>
      <p class="mg-pour-pct" id="mgPourPct">0%</p>
    `;
    const speedWrap = document.createElement('div');
    speedWrap.className = 'mg-pour-speed';
    speedWrap.innerHTML = `
      <small>Greitis</small>
      <div class="mg-pour-speed-track"><div class="mg-pour-speed-bar" id="mgPourSpeed"></div><div class="mg-pour-speed-zone"></div></div>
    `;
    const btn = actionBtn(label, { variant: 'primary', large: true });
    root.append(vessel, speedWrap, btn);
    mount(root);

    const paint = () => {
      const el = document.getElementById('mgPourFill');
      const pct = document.getElementById('mgPourPct');
      if (el) el.style.height = `${Math.min(100, fill)}%`;
      if (pct) pct.textContent = `${Math.round(fill)}%`;
    };

    const finish = (ok) => {
      clearInterval(iv);
      btn.onmousedown = null;
      btn.onmouseup = null;
      btn.onmouseleave = null;
      if (ok && onSuccess) onSuccess();
      else if (!ok && onFail) onFail();
      else if (!ok && typeof failSchedule === 'function') failSchedule();
    };

    const start = (ev) => { if (ev) ev.preventDefault(); hold = true; btn.classList.add('mg-action--pulse'); };
    const end = () => { hold = false; btn.classList.remove('mg-action--pulse'); };
    btn.onmousedown = start;
    btn.onmouseup = end;
    btn.onmouseleave = end;
    btn.ontouchstart = (ev) => { start(ev); };
    btn.ontouchend = end;

    const iv = setInterval(() => {
      speed = hold ? Math.min(100, speed + 5) : Math.max(0, speed - 4);
      const bar = document.getElementById('mgPourSpeed');
      if (bar) {
        bar.style.width = `${speed}%`;
        bar.classList.toggle('ok', speed >= 32 && speed <= 68);
        bar.classList.toggle('hot', speed > 72);
      }
      if (hold && speed > 8) {
        if (Math.random() < 0.15) sfx('pour');
        const rate = speed > 72 ? 2.4 : speed > 38 ? 1.2 : 0.5;
        fill += rate;
        paint();
        if (fill > target + 12) {
          overflows += 1;
          fill = target + 8;
          hold = false;
          end();
          if (hintEl) hintEl.textContent = 'Perpylė! Bandyk lėčiau';
        } else if (fill >= target - tolerance && fill <= target + tolerance && speed <= 70) {
          sfx('success');
          finish(true);
        } else if (hintEl) {
          hintEl.textContent = `Tikslas ~${target}% · ${Math.round(fill)}%`;
        }
      }
    }, 55);
    if (typeof scheduleTimer !== 'undefined') scheduleTimer = iv;
    return { cleanup: () => clearInterval(iv) };
  }

  /** Schedule-1: užlydimo zonos — spausk iš eilės */
  function sealZones(opts) {
    const { need = 3, onDone } = opts;
    const root = scene('mg-scene-seal');
    const wrap = panel('mg-seal-wrap');
    wrap.innerHTML = `<div class="mg-seal-bag">${resolveIcon('bag')}</div><div class="mg-seal-bar" id="mgSealBar"></div><p class="mg-seal-count">0 / ${need}</p>`;
    const bar = wrap.querySelector('#mgSealBar');
    let done = 0;
    for (let i = 0; i < need; i += 1) {
      const z = document.createElement('button');
      z.type = 'button';
      z.className = 'mg-seal-zone';
      z.dataset.i = String(i);
      z.onclick = () => {
        if (z.classList.contains('done') || Number(z.dataset.i) !== done) return;
        sfx('seal');
        z.classList.add('done', 'active');
        setTimeout(() => z.classList.remove('active'), 350);
        if (window.MgFx) MgFx.flash('rgba(251,146,60,0.25)');
        done += 1;
        wrap.querySelector('.mg-seal-count').textContent = `${done} / ${need}`;
        if (done >= need && onDone) onDone();
      };
      bar.appendChild(z);
    }
    root.appendChild(wrap);
    mount(root);
  }

  /** Distiliatorius + temperatūros gauge */
  function stillGauge(opts) {
    gaugeHold({
      ...opts,
      label: opts.label || 'Distiliacija',
      prepend: panel('mg-still-visual', `<div class="mg-still-tower">${resolveIcon('still')}<span class="mg-still-steam"></span></div>`),
    });
  }

  /** Metas: kaitinimas → seka → kristalai */
  function crystalPipeline(opts) {
    const { onSuccess, onFail, hintEl } = opts;
    gaugeHold({
      label: 'Kaitinimas',
      speed: 1.6,
      need: 52,
      zoneWidth: 20,
      hintEl,
      onSuccess: () => {
        keySequence({
          keys: ['Q', 'W', 'E', 'R'],
          rounds: 4 + (opts.difficulty || 1),
          onSuccess: () => {
            multiTap({
              icon: 'methCrystal',
              label: 'Kristalizuoti',
              need: 3,
              onDone: () => { if (onSuccess) onSuccess(); },
            });
          },
          onFail,
        });
      },
      onFail,
    });
  }

  /** Presas su ritmu — spausk kai indikatorius žalioje zonoje */
  function pressRhythm(opts) {
    const { need = 4, icon = 'pill', label = 'Presuoti', onDone, onFail } = opts;
    let hits = 0;
    let pos = 8;
    let dir = 2.2;
    const root = scene('mg-scene-rhythm');
    const track = panel('mg-rhythm-track');
    track.innerHTML = `
      <div class="mg-rhythm-zone"></div>
      <div class="mg-rhythm-needle" id="mgRhythmNeedle"></div>
      <p class="mg-rhythm-count">${hits}/${need}</p>
    `;
    const btn = actionBtn(label, { icon, variant: 'primary', large: true });
    root.append(track, btn);
    mount(root);

    const zoneLeft = 38;
    const zoneWidth = 24;
    const iv = setInterval(() => {
      pos += dir;
      if (pos >= 94) dir = -2.2;
      if (pos <= 4) dir = 2.2;
      const n = document.getElementById('mgRhythmNeedle');
      if (n) n.style.left = `${pos}%`;
    }, 35);

    btn.onclick = () => {
      const inZone = pos >= zoneLeft && pos <= zoneLeft + zoneWidth;
      if (!inZone) {
        clearInterval(iv);
        if (window.MgFx) MgFx.shake(1);
        if (onFail) onFail();
        else if (typeof failSchedule === 'function') failSchedule();
        return;
      }
      hits += 1;
      sfx('press');
      track.querySelector('.mg-rhythm-count').textContent = `${hits}/${need}`;
      btn.classList.add('mg-action--pulse');
      setTimeout(() => btn.classList.remove('mg-action--pulse'), 100);
      if (hits >= need) {
        clearInterval(iv);
        if (onDone) onDone();
      }
    };
  }

  /** Kokaino plovimas: lapai → maišymo gauge */
  function chemistryWash(opts) {
    const { need = 4, onDone, hintEl } = opts;
    washStation({
      need,
      onDone: () => {
        gaugeHold({
          label: 'Maišyti tirpalą',
          speed: 1.4,
          need: 45,
          hintEl,
          onSuccess: () => { if (onDone) onDone(); },
        });
      },
    });
  }

  /** Pasirink įrankį → kirpk taškus */
  function scrapeTrim(opts) {
    const { toolIcon = 'scissors', targetIcon = 'cannabisLeaf', cuts = 5, positions, onComplete } = opts;
    let toolReady = false;
    let cut = 0;
    const root = scene('mg-scene-scrape');
    const row = panel('mg-scrape-tools');
    const tool = actionBtn('Pasirink įrankį', { icon: toolIcon, variant: 'secondary' });
    const board = document.createElement('div');
    board.className = 'mg-scrape-board';
    board.innerHTML = `<div class="mg-scrape-target">${resolveIcon(targetIcon, 'cannabisLeaf')}</div>`;
    const pts = document.createElement('div');
    pts.className = 'mg-click-points';
    const spots = positions || [
      { top: '20%', left: '40%' }, { top: '35%', left: '55%' },
      { top: '50%', left: '38%' }, { top: '65%', left: '52%' }, { top: '45%', left: '62%' },
    ];
    spots.slice(0, cuts).forEach((pos, i) => {
      const p = document.createElement('button');
      p.type = 'button';
      p.className = 'mg-click-spot';
      p.style.top = pos.top;
      p.style.left = pos.left;
      p.innerHTML = `<span>${i + 1}</span>`;
      p.onclick = () => {
        if (!toolReady || p.classList.contains('done')) return;
        sfx('scrape');
        p.classList.add('done');
        cut += 1;
        if (cut >= cuts && onComplete) onComplete();
      };
      pts.appendChild(p);
    });
    board.appendChild(pts);
    tool.onclick = () => {
      toolReady = true;
      tool.classList.add('mg-action--pulse');
      tool.textContent = 'Įrankis paruoštas';
    };
    row.append(tool);
    root.append(row, board);
    mount(root);
  }

  /** Lašai — spausk kai žymeklis zonoje */
  function timedDrops(opts) {
    const { need = 3, icon = 'waterDrop', onComplete, onFail } = opts;
    let drops = 0;
    let pos = 10;
    let dir = 2.5;
    const root = scene('mg-scene-drops');
    const track = panel('mg-drop-track');
    track.innerHTML = `
      <div class="mg-drop-zone"></div>
      <div class="mg-drop-marker" id="mgDropMarker"></div>
      <div class="mg-drop-vial">${resolveIcon(icon, 'beaker')}</div>
      <p class="mg-drop-count">0 / ${need}</p>
    `;
    const btn = actionBtn('Lašinti', { variant: 'primary' });
    root.append(track, btn);
    mount(root);

    const zoneL = 42;
    const zoneW = 18;
    const iv = setInterval(() => {
      pos += dir;
      if (pos >= 92) dir = -2.5;
      if (pos <= 6) dir = 2.5;
      const m = document.getElementById('mgDropMarker');
      if (m) m.style.left = `${pos}%`;
    }, 40);

    btn.onclick = () => {
      const ok = pos >= zoneL && pos <= zoneL + zoneW;
      if (!ok) {
        clearInterval(iv);
        if (onFail) onFail();
        else if (typeof failSchedule === 'function') failSchedule();
        return;
      }
      drops += 1;
      sfx('drop');
      track.querySelector('.mg-drop-count').textContent = `${drops} / ${need}`;
      if (drops >= need) {
        clearInterval(iv);
        if (onComplete) onComplete();
      }
    };
  }

  /** Džiovinimo lentyna — pakabink ant kabyklų */
  function dryRack(opts) {
    const { need = 3, icon = 'cocaLeaf', onComplete } = opts;
    let hung = 0;
    const root = scene('mg-scene-dry');
    const rack = panel('mg-dry-rack');
    for (let i = 0; i < need; i += 1) {
      const hook = document.createElement('button');
      hook.type = 'button';
      hook.className = 'mg-dry-hook';
      hook.innerHTML = `${resolveIcon(icon, 'cannabisLeaf')}<small>Kabliukas ${i + 1}</small>`;
      hook.onclick = () => {
        if (hook.classList.contains('hung')) return;
        hook.classList.add('hung');
        hung += 1;
        if (hung >= need && onComplete) onComplete();
      };
      rack.appendChild(hook);
    }
    root.appendChild(rack);
    mount(root);
  }

  return {
    THEMES, themeFor, applyTheme, prepareDrugScreen, renderStepDots, clearBoard, scene, panel, mount,
    resolveIcon, iconHero, actionBtn, gaugeHold, clickBoard, multiTap, sliderBlend, vesselFill,
    spawnCatcher, stripRow, blisterPack, keySequence, pressMachine, washStation,
    packBagFlow, foilFold, successScreen, sfx, fxBurst,
    pourHold, sealZones, stillGauge, crystalPipeline, pressRhythm, chemistryWash,
    scrapeTrim, timedDrops, dryRack,
  };
})();
