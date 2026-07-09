/* Dūmai, dalelės, ekrano drebėjimas — kiekvienam narkotikui atskiras profilis */
window.MgFx = (() => {
  let canvas = null;
  let ctx = null;
  let raf = null;
  let particles = [];
  let profile = 'default';
  let modeClass = '';

  const PROFILES = {
    thc:      { count: 28, speed: 0.35, size: [1.5, 3.5], color: ['#a78bfa', '#7c3aed', '#c4b5fd'], drift: -0.4, shape: 'orb' },
    alcohol:  { count: 22, speed: 0.55, size: [2, 4], color: ['#fbbf24', '#f59e0b', '#fef3c7'], drift: -0.7, shape: 'steam' },
    vape:     { count: 36, speed: 0.25, size: [1, 2.8], color: ['#67e8f9', '#22d3ee', '#a5f3fc'], drift: -0.3, shape: 'mist' },
    weed:     { count: 18, speed: 0.2, size: [1.2, 3], color: ['#4ade80', '#22c55e', '#86efac'], drift: 0.15, shape: 'leaf' },
    heroin:   { count: 14, speed: 0.45, size: [1, 2.5], color: ['#f87171', '#ef4444', '#fecaca'], drift: -0.2, shape: 'dot' },
    meth:     { count: 40, speed: 0.6, size: [0.8, 2.2], color: ['#38bdf8', '#22d3ee', '#e0f2fe'], drift: 0.5, shape: 'crystal' },
    pills:    { count: 16, speed: 0.3, size: [1.5, 3], color: ['#fb923c', '#f97316', '#fed7aa'], drift: 0.1, shape: 'dot' },
    mushroom: { count: 24, speed: 0.28, size: [1.2, 3.2], color: ['#c084fc', '#a855f7', '#e9d5ff'], drift: -0.25, shape: 'spore' },
    cocaine:  { count: 30, speed: 0.5, size: [0.6, 1.8], color: ['#f8fafc', '#e2e8f0', '#cbd5e1'], drift: 0.35, shape: 'dust' },
    amp:      { count: 20, speed: 0.7, size: [1, 2.5], color: ['#fde047', '#facc15', '#fef9c3'], drift: 0.4, shape: 'spark' },
    default:  { count: 20, speed: 0.35, size: [1, 3], color: ['#c084fc', '#a78bfa', '#e9d5ff'], drift: -0.2, shape: 'orb' },
  };

  const MODE_BOOST = {
    meth_crystal: { count: 18, shape: 'crystal' },
    meth_crush_pack: { count: 12, shape: 'crystal' },
    pills_press: { count: 10, shape: 'dot' },
    pills_blister: { count: 8, shape: 'dot' },
    mushroom_brush: { count: 12, shape: 'spore' },
    mushroom_jar: { count: 10, shape: 'spore' },
    mushroom_harvest: { count: 14, shape: 'spore' },
    moonshine_still: { count: 12, shape: 'steam' },
    vape_blend: { count: 14, shape: 'mist' },
    vape_dropper: { count: 10, shape: 'mist' },
    thc_scrape: { count: 16, shape: 'orb' },
    thc_cartridge: { count: 14, shape: 'orb' },
    weed_soil: { count: 12, shape: 'leaf' },
    weed_seed: { count: 10, shape: 'leaf' },
    weed_water: { count: 14, shape: 'mist' },
    weed_harvest: { count: 11, shape: 'leaf' },
    weed_dry: { count: 10, shape: 'dust' },
    weed_pack: { count: 8, shape: 'leaf' },
    cocaine_wash: { count: 14, shape: 'dust' },
    coca_harvest: { count: 10, shape: 'dust' },
    cocaine_brick: { count: 12, shape: 'dust' },
    amp_stamp: { count: 16, shape: 'spark' },
    heroin_cook: { count: 10, shape: 'steam' },
    heroin_fold: { count: 8, shape: 'dot' },
  };

  function getCanvas() {
    if (canvas) return canvas;
    canvas = document.getElementById('schParticleCanvas');
    if (!canvas) return null;
    ctx = canvas.getContext('2d');
    return canvas;
  }

  function resize() {
    const c = getCanvas();
    if (!c) return;
    const box = c.parentElement;
    if (!box) return;
    const r = box.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    c.width = Math.max(1, Math.floor(r.width * dpr));
    c.height = Math.max(1, Math.floor(r.height * dpr));
    c.style.width = `${r.width}px`;
    c.style.height = `${r.height}px`;
    if (ctx) ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function rand(a, b) {
    return a + Math.random() * (b - a);
  }

  function pick(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
  }

  function spawnOne(w, h, cfg) {
    const col = pick(cfg.color);
    return {
      x: rand(0, w),
      y: rand(0, h),
      vx: rand(-0.3, 0.3),
      vy: rand(-cfg.speed, cfg.speed) + cfg.drift,
      life: rand(0.4, 1),
      maxLife: 1,
      size: rand(cfg.size[0], cfg.size[1]),
      color: col,
      alpha: rand(0.15, 0.55),
      rot: rand(0, Math.PI * 2),
      vr: rand(-0.02, 0.02),
      shape: cfg.shape,
    };
  }

  function fillParticles(cfg, w, h) {
    particles = [];
    for (let i = 0; i < cfg.count; i += 1) {
      const p = spawnOne(w, h, cfg);
      p.life = rand(0, 1);
      particles.push(p);
    }
  }

  function drawParticle(p) {
    if (!ctx) return;
    ctx.save();
    ctx.globalAlpha = p.alpha * p.life;
    ctx.translate(p.x, p.y);
    ctx.rotate(p.rot);
    ctx.fillStyle = p.color;
    if (p.shape === 'steam' || p.shape === 'mist') {
      ctx.beginPath();
      ctx.ellipse(0, 0, p.size * 1.4, p.size * 0.7, 0, 0, Math.PI * 2);
      ctx.fill();
    } else if (p.shape === 'crystal') {
      ctx.beginPath();
      ctx.moveTo(0, -p.size);
      ctx.lineTo(p.size * 0.6, 0);
      ctx.lineTo(0, p.size);
      ctx.lineTo(-p.size * 0.6, 0);
      ctx.closePath();
      ctx.fill();
    } else if (p.shape === 'spark') {
      ctx.fillRect(-p.size * 0.3, -p.size, p.size * 0.6, p.size * 2);
    } else if (p.shape === 'leaf') {
      ctx.beginPath();
      ctx.ellipse(0, 0, p.size, p.size * 0.5, 0.4, 0, Math.PI * 2);
      ctx.fill();
    } else {
      ctx.beginPath();
      ctx.arc(0, 0, p.size, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  function tick() {
    const c = getCanvas();
    if (!c || !ctx) return;
    const w = c.clientWidth;
    const h = c.clientHeight;
    ctx.clearRect(0, 0, w, h);
    const cfg = { ...PROFILES[profile] || PROFILES.default };
    const boost = MODE_BOOST[modeClass];
    if (boost) Object.assign(cfg, boost);

    particles.forEach((p) => {
      p.x += p.vx;
      p.y += p.vy;
      p.rot += p.vr;
      p.life -= 0.004;
      if (p.life <= 0 || p.x < -20 || p.x > w + 20 || p.y < -20 || p.y > h + 20) {
        Object.assign(p, spawnOne(w, h, cfg));
      }
      drawParticle(p);
    });
    raf = requestAnimationFrame(tick);
  }

  function start() {
    resize();
    const c = getCanvas();
    if (!c) return;
    const cfg = { ...PROFILES[profile] || PROFILES.default };
    const boost = MODE_BOOST[modeClass];
    if (boost) Object.assign(cfg, boost);
    fillParticles(cfg, c.clientWidth, c.clientHeight);
    if (raf) cancelAnimationFrame(raf);
    raf = requestAnimationFrame(tick);
    c.classList.add('active');
  }

  function stop() {
    if (raf) {
      cancelAnimationFrame(raf);
      raf = null;
    }
    particles = [];
    if (canvas && ctx) {
      ctx.clearRect(0, 0, canvas.clientWidth, canvas.clientHeight);
      canvas.classList.remove('active');
    }
  }

  function prepareScreen(drug, mode) {
    profile = String(drug || 'default').toLowerCase();
    modeClass = mode ? String(mode).toLowerCase() : '';
    const box = document.querySelector('#mgSchedule .sch-box');
    if (box) {
      box.dataset.fxProfile = profile;
      if (modeClass) box.dataset.fxMode = modeClass;
    }
    const vignette = document.getElementById('schVignette');
    if (vignette) {
      vignette.className = 'sch-vignette';
      vignette.classList.add(`sch-vignette-${profile}`);
    }
    start();
  }

  function shake(intensity = 1) {
    const box = document.querySelector('#mgSchedule .sch-box');
    if (!box) return;
    box.classList.remove('mg-shake');
    void box.offsetWidth;
    box.classList.add('mg-shake');
    box.style.setProperty('--shake-i', String(intensity));
    setTimeout(() => box.classList.remove('mg-shake'), 380);
  }

  function flash(color) {
    const el = document.getElementById('schFlash');
    if (!el) return;
    el.style.setProperty('--flash-color', color || 'rgba(255,255,255,0.35)');
    el.classList.remove('active');
    void el.offsetWidth;
    el.classList.add('active');
    setTimeout(() => el.classList.remove('active'), 320);
  }

  function burst(type) {
    const cfg = PROFILES[profile] || PROFILES.default;
    flash(pick(cfg.color) + '55');
    if (window.MgAudio) {
      const map = { success: 'success', fail: 'fail', seal: 'seal', pour: 'pour', press: 'press', tap: 'tap' };
      MgAudio.play(map[type] || 'click');
    }
  }

  function cleanup() {
    stop();
    profile = 'default';
    modeClass = '';
    const box = document.querySelector('#mgSchedule .sch-box');
    if (box) {
      delete box.dataset.fxProfile;
      delete box.dataset.fxMode;
    }
  }

  window.addEventListener('resize', () => {
    if (raf) resize();
  });

  return { prepareScreen, start, stop, cleanup, shake, flash, burst, PROFILES };
})();
