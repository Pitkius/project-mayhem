/**
 * Žolė (Weed) — premium Canvas minigame (grow + lab).
 * Naudoja esamą scheduleResult flow; nekeičia serverio logikos.
 */
window.MgWeed = (() => {
  const COLORS = {
    accent: '#4ade80',
    accent2: '#16a34a',
    soil: '#5c4033',
    glow: 'rgba(74, 222, 128, 0.42)',
    tent: '#0a1f12',
  };

  const ASSETS = {
    pot: 'icons/grow_pot.png',
    can: 'icons/watering_can.png',
    leaf: 'icons/weed_leaf.png',
    scissors: 'icons/trimming_scissors.png',
    gloves: 'icons/gloves_item.png',
    scale: 'icons/drug_scale.png',
  };

  const images = {};
  let assetsReady = null;
  let raf = null;
  const cleanups = [];

  function sfx(name) {
    if (window.MgAudio) MgAudio.play(name);
  }

  function clamp(v, a, b) {
    return Math.max(a, Math.min(b, v));
  }

  function loadAssets() {
    if (assetsReady) return assetsReady;
    assetsReady = Promise.all(
      Object.entries(ASSETS).map(([key, src]) => new Promise((resolve) => {
        const img = new Image();
        img.onload = () => { images[key] = img; resolve(); };
        img.onerror = () => resolve();
        img.src = src;
      })),
    );
    return assetsReady;
  }

  function mountBoard() {
    if (typeof schBoard === 'undefined' || !schBoard) return null;
    schBoard.innerHTML = '';
    const root = document.createElement('div');
    root.className = 'mg-weed-root mg-scene-weed';
    schBoard.appendChild(root);
    return root;
  }

  function makeStage(parent) {
    const wrap = document.createElement('div');
    wrap.className = 'mg-weed-stage-wrap';
    const canvas = document.createElement('canvas');
    canvas.className = 'mg-weed-canvas';
    wrap.appendChild(canvas);
    parent.appendChild(wrap);
    return { wrap, canvas };
  }

  function bindResize(canvas, draw) {
    const ro = new ResizeObserver(() => {
      const r = canvas.parentElement.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      canvas.width = Math.max(1, Math.floor(r.width * dpr));
      canvas.height = Math.max(1, Math.floor(r.height * dpr));
      canvas.style.width = `${r.width}px`;
      canvas.style.height = `${r.height}px`;
      const ctx = canvas.getContext('2d');
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      draw(ctx, r.width, r.height);
    });
    ro.observe(canvas.parentElement);
    cleanups.push(() => ro.disconnect());
  }

  function stopLoop() {
    if (raf) {
      cancelAnimationFrame(raf);
      raf = null;
    }
  }

  function runLoop(fn) {
    stopLoop();
    const tick = (ts) => {
      fn(ts);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    cleanups.push(stopLoop);
  }

  function cleanup() {
    stopLoop();
    while (cleanups.length) {
      const fn = cleanups.pop();
      try { fn(); } catch (_) { /* ignore */ }
    }
  }

  function canvasPos(canvas, ev) {
    const r = canvas.getBoundingClientRect();
    return { x: ev.clientX - r.left, y: ev.clientY - r.top, w: r.width, h: r.height };
  }

  function drawImg(ctx, key, cx, cy, size, rot = 0, alpha = 1) {
    const img = images[key];
    if (!img) return false;
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(rot);
    ctx.globalAlpha = alpha;
    ctx.drawImage(img, -size / 2, -size / 2, size, size);
    ctx.restore();
    return true;
  }

  function createParticles(count, type) {
    const parts = [];
    for (let i = 0; i < count; i += 1) {
      parts.push({
        x: Math.random(),
        y: Math.random(),
        vx: (Math.random() - 0.5) * 0.001,
        vy: type === 'dust' ? -0.0004 - Math.random() * 0.0008 : -0.0008 - Math.random() * 0.001,
        life: 0.4 + Math.random() * 0.6,
        size: 2 + Math.random() * 4,
        hue: 110 + Math.random() * 40,
      });
    }
    return parts;
  }

  function tickParticles(parts, w, h, intensity) {
    parts.forEach((p) => {
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 0.004 * intensity;
      if (p.life <= 0 || p.y < -0.05) {
        p.x = Math.random();
        p.y = 0.6 + Math.random() * 0.3;
        p.life = 0.5 + Math.random() * 0.5;
      }
      const px = p.x * w;
      const py = p.y * h;
      const g = ctx => {
        const grd = ctx.createRadialGradient(px, py, 0, px, py, p.size * 2.5);
        grd.addColorStop(0, `hsla(${p.hue}, 70%, 55%, ${p.life * 0.35})`);
        grd.addColorStop(1, 'rgba(74, 222, 128, 0)');
        return grd;
      };
      return { px, py, g, size: p.size };
    });
  }

  function drawGrowTent(ctx, w, h) {
    const grd = ctx.createLinearGradient(0, 0, 0, h);
    grd.addColorStop(0, '#041208');
    grd.addColorStop(0.45, '#0a2214');
    grd.addColorStop(1, '#061a0e');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, w, h);

    const lamp = ctx.createRadialGradient(w * 0.5, h * 0.12, 0, w * 0.5, h * 0.25, w * 0.5);
    lamp.addColorStop(0, 'rgba(74, 222, 128, 0.22)');
    lamp.addColorStop(0.5, 'rgba(34, 197, 94, 0.08)');
    lamp.addColorStop(1, 'rgba(74, 222, 128, 0)');
    ctx.fillStyle = lamp;
    ctx.fillRect(0, 0, w, h * 0.55);

    ctx.fillStyle = '#1a1208';
    ctx.fillRect(0, h * 0.78, w, h * 0.22);
    ctx.strokeStyle = 'rgba(74, 222, 128, 0.06)';
    for (let i = 0; i < 8; i += 1) {
      const y = h * 0.8 + i * 4;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }
  }

  function drawLabBench(ctx, w, h) {
    const grd = ctx.createLinearGradient(0, 0, 0, h);
    grd.addColorStop(0, '#0c1410');
    grd.addColorStop(0.6, '#142018');
    grd.addColorStop(1, '#0a120c');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = 'rgba(22, 101, 52, 0.15)';
    ctx.fillRect(0, h * 0.7, w, h * 0.3);
  }

  function drawPot(ctx, cx, cy, scale, fillPct, label) {
    if (drawImg(ctx, 'pot', cx, cy, 120 * scale)) {
      const fh = 38 * scale * clamp(fillPct / 100, 0, 1);
      ctx.fillStyle = COLORS.soil;
      ctx.beginPath();
      ctx.ellipse(cx, cy + 18 * scale, 34 * scale, 8 * scale, 0, 0, Math.PI * 2);
      ctx.fill();
      if (fh > 2) {
        ctx.fillStyle = '#6b4f3a';
        ctx.fillRect(cx - 30 * scale, cy + 18 * scale - fh, 60 * scale, fh);
      }
    } else {
      ctx.save();
      ctx.translate(cx, cy);
      ctx.fillStyle = '#2d1810';
      ctx.beginPath();
      ctx.moveTo(-40 * scale, -20 * scale);
      ctx.lineTo(-48 * scale, 40 * scale);
      ctx.quadraticCurveTo(0, 52 * scale, 48 * scale, 40 * scale);
      ctx.lineTo(40 * scale, -20 * scale);
      ctx.closePath();
      ctx.fill();
      const fh = 42 * scale * clamp(fillPct / 100, 0, 1);
      ctx.fillStyle = COLORS.soil;
      ctx.fillRect(-36 * scale, 10 * scale - fh, 72 * scale, fh);
      ctx.restore();
    }
    if (label) {
      ctx.fillStyle = 'rgba(187, 247, 208, 0.75)';
      ctx.font = '11px system-ui, sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(label, cx, cy + 58 * scale);
    }
  }

  function drawPlant(ctx, cx, cy, scale, stage) {
    const s = stage || 1;
    ctx.save();
    ctx.translate(cx, cy - 40 * scale);
    ctx.strokeStyle = '#166534';
    ctx.lineWidth = 3 * scale;
    ctx.beginPath();
    ctx.moveTo(0, 50 * scale);
    ctx.quadraticCurveTo(4 * scale, 10 * scale, 0, -20 * scale);
    ctx.stroke();
    const leaves = s >= 2 ? 4 : 2;
    for (let i = 0; i < leaves; i += 1) {
      const ang = (i / leaves) * Math.PI * 2 - Math.PI / 2;
      const lx = Math.cos(ang) * 28 * scale;
      const ly = Math.sin(ang) * 18 * scale - 10 * scale;
      if (!drawImg(ctx, 'leaf', cx + lx, cy - 40 * scale + ly, 36 * scale, ang + 0.4)) {
        ctx.fillStyle = `rgba(34, 197, 94, ${0.7 + i * 0.05})`;
        ctx.beginPath();
        ctx.ellipse(lx, ly, 18 * scale, 10 * scale, ang, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.restore();
  }

  function drawSoilBag(ctx, cx, cy, scale, open, cuts) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.fillStyle = '#3d2817';
    ctx.strokeStyle = 'rgba(187, 247, 208, 0.35)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.roundRect(-50 * scale, -35 * scale, 100 * scale, 70 * scale, 8 * scale);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = '#6b4f3a';
    ctx.fillRect(-42 * scale, -10 * scale, 84 * scale, 40 * scale);
    if (open) {
      ctx.fillStyle = 'rgba(107, 79, 58, 0.9)';
      ctx.beginPath();
      ctx.moveTo(-42 * scale, -10 * scale);
      ctx.lineTo(-50 * scale, -45 * scale);
      ctx.lineTo(50 * scale, -45 * scale);
      ctx.lineTo(42 * scale, -10 * scale);
      ctx.closePath();
      ctx.fill();
    }
    for (let i = 0; i < 3; i += 1) {
      const y = -20 * scale + i * 18 * scale;
      ctx.strokeStyle = cuts[i] ? '#4ade80' : 'rgba(248, 113, 113, 0.85)';
      ctx.setLineDash(cuts[i] ? [] : [6, 4]);
      ctx.beginPath();
      ctx.moveTo(-35 * scale, y);
      ctx.lineTo(35 * scale, y);
      ctx.stroke();
    }
    ctx.setLineDash([]);
    ctx.restore();
  }

  function drawGauge(ctx, x, y, w, needle, zoneL, zoneW, label) {
    ctx.fillStyle = 'rgba(4, 20, 12, 0.85)';
    ctx.fillRect(x, y, w, 10);
    ctx.fillStyle = 'rgba(74, 222, 128, 0.55)';
    ctx.fillRect(x + w * (zoneL / 100), y, w * (zoneW / 100), 10);
    ctx.fillStyle = '#ecfdf5';
    const nx = x + w * (needle / 100);
    ctx.beginPath();
    ctx.moveTo(nx, y - 5);
    ctx.lineTo(nx + 5, y + 14);
    ctx.lineTo(nx - 5, y + 14);
    ctx.closePath();
    ctx.fill();
    if (label) {
      ctx.fillStyle = 'rgba(187, 247, 208, 0.7)';
      ctx.font = '10px system-ui';
      ctx.textAlign = 'center';
      ctx.fillText(label, x + w / 2, y - 10);
    }
  }

  function addHudBtn(parent, text, cls, onClick) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `mg-weed-btn mg-weed-btn--${cls || 'ghost'}`;
    b.textContent = text;
    b.onclick = onClick;
    parent.appendChild(b);
    return b;
  }

  function addStatus(parent, text) {
    const s = document.createElement('p');
    s.className = 'mg-weed-status';
    s.textContent = text;
    parent.appendChild(s);
    return s;
  }

  function addMeter(parent, label, id) {
    const m = document.createElement('div');
    m.className = 'mg-weed-meter';
    m.innerHTML = `<label>${label}</label><div class="mg-weed-meter-bar"><div class="mg-weed-meter-fill" id="${id}"></div></div>`;
    parent.appendChild(m);
    return m.querySelector(`#${id}`);
  }

  function failHooks(hooks) {
    sfx('fail');
    if (window.MgFx) MgFx.shake(1.1);
    cleanup();
    hooks.onFail();
  }

  function winHooks(hooks, extra) {
    sfx('success');
    if (window.MgFx) MgFx.flash('rgba(74, 222, 128, 0.35)');
    cleanup();
    hooks.onWin(extra);
  }

  function armTimeout(ms, hooks) {
    const t = setTimeout(() => failHooks(hooks), ms);
    cleanups.push(() => clearTimeout(t));
  }

  /* ─── weed_soil: pjūviai + pylimo greitis ─── */
  function runSoil(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      let cuts = [false, false, false];
      let scissorsOn = false;
      let phase = 'cut';
      let soilPct = 0;
      let overflows = 0;
      let speed = 0;
      let hold = false;
      const mist = createParticles(16, 'dust');

      const { canvas } = makeStage(root);
      const hud = document.createElement('div');
      hud.className = 'mg-weed-hud';
      root.appendChild(hud);
      const status = addStatus(root, 'Pasirink žirkles ir praskirk maišą');
      const pourBtn = addHudBtn(hud, 'Pilti substratą', 'primary', () => {});
      pourBtn.style.display = 'none';
      const scissorBtn = addHudBtn(hud, 'Žirklės', 'ghost', () => {
        scissorsOn = true;
        scissorBtn.classList.add('active');
        sfx('click');
        status.textContent = 'Spausk ant pjūvio linijų maiše';
      });

      hooks.setStep(1, 2, 'Pasirink žirkles, tada praskirk maišą');
      armTimeout(45000, hooks);

      function calcScore() {
        const diff = Math.abs(soilPct - 100);
        return Math.max(35, Math.min(100, Math.round(100 - diff * 1.2 - overflows * 15)));
      }

      function drawCut(ctx, w, h) {
        drawGrowTent(ctx, w, h);
        drawSoilBag(ctx, w * 0.55, h * 0.48, 1.1, cuts.every(Boolean), cuts);
        drawImg(ctx, 'scissors', w * 0.22, h * 0.5, 72, scissorsOn ? -0.3 : 0.2, scissorsOn ? 1 : 0.55);
        mist.forEach((p) => {
          p.x += p.vx;
          p.y += p.vy;
          p.life -= 0.003;
          if (p.life <= 0) { p.life = 0.6; p.y = 0.7; }
          const px = p.x * w;
          const py = p.y * h;
          const g = ctx.createRadialGradient(px, py, 0, px, py, p.size * 2);
          g.addColorStop(0, `hsla(${p.hue}, 60%, 50%, ${p.life * 0.25})`);
          g.addColorStop(1, 'rgba(74, 222, 128, 0)');
          ctx.fillStyle = g;
          ctx.beginPath();
          ctx.arc(px, py, p.size * 2, 0, Math.PI * 2);
          ctx.fill();
        });
      }

      function drawPour(ctx, w, h) {
        drawGrowTent(ctx, w, h);
        drawPot(ctx, w * 0.5, h * 0.58, 1.15, soilPct, `Žemė ${Math.round(soilPct)}%`);
        if (hold && speed > 10) {
          ctx.strokeStyle = 'rgba(187, 247, 208, 0.5)';
          ctx.lineWidth = 3;
          ctx.beginPath();
          ctx.moveTo(w * 0.72, h * 0.25);
          ctx.quadraticCurveTo(w * 0.6, h * 0.4, w * 0.52, h * 0.35);
          ctx.stroke();
          for (let i = 0; i < 5; i += 1) {
            ctx.fillStyle = `rgba(107, 79, 58, ${0.4 + Math.random() * 0.3})`;
            ctx.beginPath();
            ctx.arc(w * 0.52 + (Math.random() - 0.5) * 20, h * 0.32 + i * 8, 3, 0, Math.PI * 2);
            ctx.fill();
          }
        }
        drawGauge(ctx, w * 0.15, h * 0.82, w * 0.7, speed, 35, 30, 'Pylimo greitis');
      }

      bindResize(canvas, (ctx, w, h) => {
        if (phase === 'cut') drawCut(ctx, w, h);
        else drawPour(ctx, w, h);
      });

      canvas.onclick = (ev) => {
        if (phase !== 'cut' || !scissorsOn) return;
        const { x, y, w, h } = canvasPos(canvas, ev);
        const lines = [0.42, 0.5, 0.58].map((fy) => h * fy);
        for (let i = 0; i < 3; i += 1) {
          if (cuts[i]) continue;
          if (Math.abs(y - lines[i]) < 22 && x > w * 0.38 && x < w * 0.72) {
            cuts[i] = true;
            sfx('slice');
            if (window.MgFx) MgFx.flash('rgba(74, 222, 128, 0.2)');
            if (cuts.every(Boolean)) {
              phase = 'pour';
              hooks.setStep(2, 2, 'Laikyk PYLIMO — žalias greitis, sustok ties 100%');
              status.textContent = 'Laikyk „Pilti“ — žalioje zonoje';
              scissorBtn.style.display = 'none';
              pourBtn.style.display = '';
              canvas.onclick = null;
              startPourLoop();
            } else {
              status.textContent = `Pjūviai ${cuts.filter(Boolean).length}/3`;
            }
            break;
          }
        }
      };

      function startPourLoop() {
        const startHold = (ev) => { if (ev) ev.preventDefault(); hold = true; pourBtn.classList.add('active'); };
        const endHold = () => { hold = false; pourBtn.classList.remove('active'); };
        pourBtn.addEventListener('mousedown', startHold);
        pourBtn.addEventListener('mouseup', endHold);
        pourBtn.addEventListener('mouseleave', endHold);
        pourBtn.addEventListener('touchstart', startHold, { passive: false });
        pourBtn.addEventListener('touchend', endHold);
        cleanups.push(() => {
          pourBtn.removeEventListener('mousedown', startHold);
          pourBtn.removeEventListener('mouseup', endHold);
          pourBtn.removeEventListener('mouseleave', endHold);
          pourBtn.removeEventListener('touchstart', startHold);
          pourBtn.removeEventListener('touchend', endHold);
        });

        runLoop(() => {
          speed = hold ? Math.min(100, speed + 4) : Math.max(0, speed - 3);
          if (hold && speed > 10) {
            const rate = speed > 75 ? 2.6 : speed > 40 ? 1.35 : 0.55;
            soilPct += rate;
            if (soilPct > 108) {
              overflows += 1;
              soilPct = 102;
              hold = false;
              status.textContent = 'Perpylė! Atleisk ir pilti lėčiau';
              sfx('fail');
            } else if (soilPct >= 98 && speed <= 68) {
              winHooks(hooks, { score: calcScore(), quality: calcScore() });
            } else {
              status.textContent = `Tikslas 100% · dabar ${Math.round(soilPct)}%`;
            }
          }
          const ctx = canvas.getContext('2d');
          const r = canvas.parentElement.getBoundingClientRect();
          drawPour(ctx, r.width, r.height);
        });
      }
    });
  }

  /* ─── weed_seed: pirštinės + sėklų seka ─── */
  function runSeed(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      let glovesOn = false;
      let placed = 0;
      const need = 3;
      const slots = [
        { x: 0.38, y: 0.72 }, { x: 0.5, y: 0.76 }, { x: 0.62, y: 0.72 },
      ].map((s) => ({ ...s, done: false }));

      const { canvas } = makeStage(root);
      const status = addStatus(root, 'Užsimaok pirštines ant stalo');
      hooks.setStep(1, 2, 'Užsimaok pirštines');
      armTimeout(40000, hooks);

      function draw(ctx, w, h) {
        drawGrowTent(ctx, w, h);
        drawPot(ctx, w * 0.5, h * 0.45, 1.2, 88, 'Paruošta žemė');
        drawImg(ctx, 'gloves', w * 0.2, h * 0.55, 80, 0, glovesOn ? 1 : 0.65);
        slots.forEach((s, i) => {
          const px = w * s.x;
          const py = h * s.y;
          ctx.beginPath();
          ctx.arc(px, py, s.done ? 8 : 14, 0, Math.PI * 2);
          ctx.fillStyle = s.done ? 'rgba(74, 222, 128, 0.9)' : (i === placed && glovesOn ? 'rgba(74, 222, 128, 0.35)' : 'rgba(74, 222, 128, 0.12)');
          ctx.fill();
          ctx.strokeStyle = 'rgba(187, 247, 208, 0.5)';
          ctx.stroke();
          if (s.done) drawImg(ctx, 'leaf', px, py - 20, 28, 0, 0.9);
        });
      }

      bindResize(canvas, draw);

      canvas.onclick = (ev) => {
        const { x, y, w, h } = canvasPos(canvas, ev);
        if (!glovesOn) {
          if (Math.hypot(x - w * 0.2, y - h * 0.55) < 55) {
            glovesOn = true;
            sfx('click');
            hooks.setStep(2, 2, 'Paspausk aktyvias sėklų vietas po vazonu');
            status.textContent = 'Sodink sėklas iš eilės';
          }
          return;
        }
        const s = slots[placed];
        if (!s || s.done) return;
        const px = w * s.x;
        const py = h * s.y;
        if (Math.hypot(x - px, y - py) < 28) {
          s.done = true;
          placed += 1;
          sfx('bubble');
          if (placed >= need) {
            const score = Math.max(50, Math.min(100, 68 + placed * 10));
            winHooks(hooks, { score, quality: score });
          } else {
            status.textContent = `Sėklos ${placed}/${need}`;
          }
        }
      };
    });
  }

  /* ─── weed_water: laistytuvas + drėgmės zonos ─── */
  function runWater(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      let phase = 'fill';
      let spoutOpen = false;
      let canFill = 0;
      let zoneIdx = 0;
      const zonesNeeded = 3;
      const zoneNames = ['Dirvožemis', 'Stiebas', 'Lapai', 'Šaknys', 'Briauna'];
      const picked = zoneNames.sort(() => Math.random() - 0.5).slice(0, zonesNeeded);
      let moisture = 22;
      let hold = false;
      const moistureHits = [];

      const { canvas } = makeStage(root);
      const hud = document.createElement('div');
      hud.className = 'mg-weed-hud';
      root.appendChild(hud);
      const status = addStatus(root, 'Atidaryk laistytuvo snapą');
      const actionBtn = addHudBtn(hud, 'Atidaryti snapą', 'primary', () => {});
      const moistFill = addMeter(hud, 'Drėgmė', 'mgWeedMoist');

      hooks.setStep(1, 2, 'Atidaryk snapą ir pripildyk laistytuvą');
      armTimeout(55000, hooks);

      function paintMoist() {
        if (moistFill) moistFill.style.width = `${moisture}%`;
      }

      function drawFill(ctx, w, h) {
        drawGrowTent(ctx, w, h);
        drawImg(ctx, 'can', w * 0.45, h * 0.5, 100, 0, 1);
        ctx.fillStyle = 'rgba(187, 247, 208, 0.8)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`${canFill}%`, w * 0.45, h * 0.62);
        if (spoutOpen) {
          ctx.fillStyle = 'rgba(56, 189, 248, 0.6)';
          ctx.fillRect(w * 0.52, h * 0.42, w * 0.25, 8);
        }
      }

      function drawWater(ctx, w, h) {
        drawGrowTent(ctx, w, h);
        drawPot(ctx, w * 0.48, h * 0.55, 1, 70, '');
        drawPlant(ctx, w * 0.48, h * 0.55, 1.1, 2);
        if (hold) {
          ctx.strokeStyle = 'rgba(56, 189, 248, 0.5)';
          ctx.lineWidth = 2;
          for (let i = 0; i < 6; i += 1) {
            ctx.beginPath();
            ctx.moveTo(w * 0.58, h * 0.35);
            ctx.lineTo(w * 0.5 + (Math.random() - 0.5) * 30, h * 0.45 + i * 12);
            ctx.stroke();
          }
        }
        ctx.fillStyle = 'rgba(187, 247, 208, 0.85)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Zona: ${picked[zoneIdx] || '—'}`, w * 0.5, h * 0.18);
        drawGauge(ctx, w * 0.12, h * 0.82, w * 0.76, moisture, 42, 26, 'Drėgmės tikslas 42–68%');
      }

      bindResize(canvas, (ctx, w, h) => {
        if (phase === 'fill') drawFill(ctx, w, h);
        else drawWater(ctx, w, h);
      });

      actionBtn.onclick = () => {
        if (phase === 'fill') {
          if (!spoutOpen) {
            spoutOpen = true;
            actionBtn.textContent = 'Pilti vandenį';
            status.textContent = 'Spausk „Pilti vandenį“ kol 100%';
            sfx('click');
          } else {
            canFill = Math.min(100, canFill + 34);
            sfx('pour');
            if (canFill >= 100) {
              phase = 'water';
              hooks.setStep(2, 2, 'Laistyk — laikyk mygtuką ir atleisk žalioje zonoje');
              actionBtn.textContent = 'Laistyti';
              status.textContent = 'Laikyk ir atleisk kai drėgmė žalioje zonoje';
              startWaterLoop();
            }
          }
        }
      };

      function startWaterLoop() {
        const startHold = (ev) => { if (ev) ev.preventDefault(); hold = true; actionBtn.classList.add('active'); };
        const endHold = () => {
          if (!hold) return;
          hold = false;
          actionBtn.classList.remove('active');
          moistureHits.push(moisture);
          zoneIdx += 1;
          if (zoneIdx >= zonesNeeded) {
            const avg = moistureHits.reduce((a, b) => a + b, 0) / moistureHits.length;
            const score = Math.max(45, Math.min(100, Math.round(70 + (avg >= 42 && avg <= 68 ? 18 : -Math.abs(avg - 55) * 0.8))));
            winHooks(hooks, { moisture: Math.round(avg), score, quality: score });
          } else {
            moisture = 18 + Math.random() * 12;
            paintMoist();
            status.textContent = moisture >= 42 && moisture <= 68 ? 'Puiku! Kitas plotas…' : 'Tęsk kitą zoną';
          }
        };
        actionBtn.addEventListener('mousedown', startHold);
        actionBtn.addEventListener('mouseup', endHold);
        actionBtn.addEventListener('mouseleave', endHold);
        actionBtn.addEventListener('touchstart', startHold, { passive: false });
        actionBtn.addEventListener('touchend', endHold);
        cleanups.push(() => {
          actionBtn.removeEventListener('mousedown', startHold);
          actionBtn.removeEventListener('mouseup', endHold);
          actionBtn.removeEventListener('mouseleave', endHold);
          actionBtn.removeEventListener('touchstart', startHold);
          actionBtn.removeEventListener('touchend', endHold);
        });

        runLoop(() => {
          if (hold) moisture = Math.min(100, moisture + 2.4);
          else moisture = Math.max(0, moisture - 1.1);
          paintMoist();
          const ctx = canvas.getContext('2d');
          const r = canvas.parentElement.getBoundingClientRect();
          drawWater(ctx, r.width, r.height);
        });
      }
    });
  }

  /* ─── weed_harvest: kirpimas + svarstyklės ─── */
  function runHarvest(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      const need = data.steps || 3;
      let phase = 'gloves';
      let glovesOn = false;
      let trimmed = 0;
      let mistakes = 0;
      let lastCut = 0;
      let onScale = false;
      const points = [[0.35, 0.32], [0.62, 0.28], [0.48, 0.42], [0.68, 0.48]].slice(0, need)
        .map((p, i) => ({ x: p[0], y: p[1], done: false, i }));

      const { canvas } = makeStage(root);
      const status = addStatus(root, 'Užsimaok pirštines');
      hooks.setStep(1, 3, 'Užsimaok pirštines');
      armTimeout(60000, hooks);

      function score() {
        return Math.max(40, Math.min(100, Math.round(62 + trimmed * 11 - mistakes * 14)));
      }

      function draw(ctx, w, h) {
        drawGrowTent(ctx, w, h);
        if (phase === 'gloves') {
          drawPot(ctx, w * 0.55, h * 0.5, 1, 70, 'Brandu');
          drawImg(ctx, 'gloves', w * 0.25, h * 0.52, 85, 0, glovesOn ? 1 : 0.6);
          drawImg(ctx, 'scissors', w * 0.75, h * 0.52, 70, 0.2, 0.4);
        } else if (phase === 'trim') {
          drawPlant(ctx, w * 0.5, h * 0.55, 1.4, 3);
          drawImg(ctx, 'scissors', w * 0.78, h * 0.35, 64, -0.4, 0.95);
          points.forEach((p, idx) => {
            const px = w * p.x;
            const py = h * p.y;
            if (!p.done && idx === trimmed) {
              ctx.strokeStyle = '#4ade80';
              ctx.lineWidth = 2;
              ctx.beginPath();
              ctx.arc(px, py, 16, 0, Math.PI * 2);
              ctx.stroke();
            }
          });
        } else {
          drawImg(ctx, 'scale', w * 0.55, h * 0.52, 110, 0, 1);
          drawImg(ctx, 'leaf', w * 0.28, h * 0.55, onScale ? 0 : 56, 0, onScale ? 0 : 1);
          if (onScale) drawImg(ctx, 'leaf', w * 0.55, h * 0.42, 48, 0.2, 1);
          ctx.fillStyle = 'rgba(187, 247, 208, 0.8)';
          ctx.font = '13px system-ui';
          ctx.textAlign = 'center';
          ctx.fillText(onScale ? '1.24 g' : 'Pasvęsk derlių', w * 0.55, h * 0.68);
        }
      }

      bindResize(canvas, draw);

      canvas.onclick = (ev) => {
        const { x, y, w, h } = canvasPos(canvas, ev);
        if (phase === 'gloves') {
          if (Math.hypot(x - w * 0.25, y - h * 0.52) < 50) {
            glovesOn = true;
            phase = 'trim';
            hooks.setStep(2, 3, 'Kirpk pažymėtus lapus — po vieną');
            status.textContent = 'Spausk žalius žiedus';
            sfx('click');
          }
        } else if (phase === 'trim') {
          const p = points[trimmed];
          if (!p || p.done) return;
          const px = w * p.x;
          const py = h * p.y;
          if (Math.hypot(x - px, y - py) < 22) {
            const now = Date.now();
            if (now - lastCut < 280) mistakes += 1;
            lastCut = now;
            p.done = true;
            trimmed += 1;
            sfx('slice');
            if (trimmed >= need) {
              phase = 'scale';
              hooks.setStep(3, 3, 'Pasvęsk derlių svarstyklėmis');
              status.textContent = 'Pasirink lapus, tada svarstykles';
            } else {
              status.textContent = `${trimmed}/${need} lapų`;
            }
          }
        } else {
          if (!onScale && Math.hypot(x - w * 0.28, y - h * 0.55) < 40) {
            onScale = true;
            sfx('click');
            status.textContent = 'Spausk svarstykles';
          } else if (onScale && Math.hypot(x - w * 0.55, y - h * 0.52) < 60) {
            winHooks(hooks, { score: score(), quality: score(), mistakes });
          }
        }
      };
    });
  }

  /* ─── weed_dry: pakabinti → oro srautas → surinkti ─── */
  function runDry(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      let phase = 'hang';
      let hung = 0;
      let drySec = 0;
      const needDry = 5;
      let pos = 22;
      let vel = 2.4;
      const hooksPos = [{ x: 0.32, y: 0.38, done: false }, { x: 0.68, y: 0.38, done: false }];

      const { canvas } = makeStage(root);
      const hud = document.createElement('div');
      hud.className = 'mg-weed-hud';
      root.appendChild(hud);
      const status = addStatus(root, 'Pakabink 2 lapus ant stovo');
      const lessBtn = addHudBtn(hud, 'Mažinti', 'ghost', () => { vel = Math.max(-5, vel - 1.4); });
      const moreBtn = addHudBtn(hud, 'Didinti', 'primary', () => { vel = Math.min(5, vel + 1.4); });
      lessBtn.style.display = 'none';
      moreBtn.style.display = 'none';
      const dryFill = addMeter(hud, 'Džiovinimas', 'mgWeedDry');

      hooks.setStep(1, 3, 'Pakabink 2 lapus ant džiovinimo stovo');
      armTimeout(70000, hooks);

      function drawRack(ctx, w, h) {
        drawLabBench(ctx, w, h);
        ctx.strokeStyle = 'rgba(187, 247, 208, 0.4)';
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(w * 0.15, h * 0.3);
        ctx.lineTo(w * 0.85, h * 0.3);
        ctx.stroke();
        hooksPos.forEach((hp) => {
          ctx.beginPath();
          ctx.arc(w * hp.x, h * hp.y, 10, 0, Math.PI * 2);
          ctx.fillStyle = hp.done ? 'rgba(74, 222, 128, 0.8)' : 'rgba(74, 222, 128, 0.2)';
          ctx.fill();
          if (hp.done) drawImg(ctx, 'leaf', w * hp.x, h * (hp.y + 0.12), 40, 0.1, 0.85);
        });
      }

      function drawDry(ctx, w, h) {
        drawLabBench(ctx, w, h);
        hooksPos.forEach((hp) => {
          if (hp.done) drawImg(ctx, 'leaf', w * hp.x, h * 0.42, 36, 0, 0.7 + Math.sin(Date.now() / 400) * 0.1);
        });
        drawGauge(ctx, w * 0.12, h * 0.75, w * 0.76, pos, 38, 22, 'Oro srautas');
        if (dryFill) dryFill.style.width = `${Math.min(100, (drySec / needDry) * 100)}%`;
      }

      function drawCollect(ctx, w, h) {
        drawLabBench(ctx, w, h);
        drawImg(ctx, 'leaf', w * 0.5, h * 0.45, 90, 0, 1);
        ctx.fillStyle = 'rgba(187, 247, 208, 0.85)';
        ctx.font = '13px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText('Išdžiovintas kanapių žiedas', w * 0.5, h * 0.62);
      }

      bindResize(canvas, (ctx, w, h) => {
        if (phase === 'hang') drawRack(ctx, w, h);
        else if (phase === 'dry') drawDry(ctx, w, h);
        else drawCollect(ctx, w, h);
      });

      canvas.onclick = (ev) => {
        const { x, y, w, h } = canvasPos(canvas, ev);
        if (phase === 'hang') {
          hooksPos.forEach((hp) => {
            if (hp.done) return;
            if (Math.hypot(x - w * hp.x, y - h * hp.y) < 28) {
              hp.done = true;
              hung += 1;
              sfx('click');
              if (hung >= 2) {
                phase = 'dry';
                hooks.setStep(2, 3, 'Reguliuok oro srautą — žalioje zonoje');
                status.textContent = 'Mažinti / Didinti — laikyk indikatorių žalioje';
                lessBtn.style.display = '';
                moreBtn.style.display = '';
                startDryLoop();
              }
            }
          });
        } else if (phase === 'collect') {
          if (Math.hypot(x - w * 0.5, y - h * 0.45) < 60) {
            winHooks(hooks, { score: 88 });
          }
        }
      };

      function startDryLoop() {
        runLoop(() => {
          pos += vel;
          if (pos <= 4 || pos >= 92) vel *= -1;
          pos = clamp(pos, 2, 96);
          if (pos >= 38 && pos <= 60) drySec += 0.1;
          status.textContent = `Džiovinimas ${Math.min(100, Math.floor((drySec / needDry) * 100))}%`;
          if (drySec >= needDry) {
            stopLoop();
            phase = 'collect';
            hooks.setStep(3, 3, 'Surink išdžiovintą žiedą');
            status.textContent = 'Spausk ant žiedo';
            lessBtn.style.display = 'none';
            moreBtn.style.display = 'none';
            sfx('success');
          }
          const ctx = canvas.getContext('2d');
          const r = canvas.parentElement.getBoundingClientRect();
          drawDry(ctx, r.width, r.height);
        });
      }
    });
  }

  /* ─── weed_pack: svarstyklės → maišelis → užlydinimas ─── */
  function runPack(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      let phase = 'weigh';
      let weighed = false;
      let picked = false;
      let bagFilled = false;
      let seals = 0;
      let drag = null;
      let budPos = { x: 0.28, y: 0.52 };
      let marker = 12;
      let dir = 2.6;
      const sealZones = [22, 50, 78];

      const { canvas } = makeStage(root);
      const status = addStatus(root, 'Padėk žiedą ant svarstyklių');
      hooks.setStep(1, 3, 'Padėk išdžiovintą žiedą ant svarstyklių');
      armTimeout(65000, hooks);

      function drawWeigh(ctx, w, h) {
        drawLabBench(ctx, w, h);
        drawImg(ctx, 'scale', w * 0.55, h * 0.52, 115, 0, 1);
        const bx = w * budPos.x;
        const by = h * budPos.y;
        drawImg(ctx, 'leaf', bx, by, weighed ? 0 : 52, 0, weighed ? 0 : 1);
        if (weighed) drawImg(ctx, 'leaf', w * 0.55, h * 0.4, 46, 0.15, 1);
        ctx.fillStyle = 'rgba(187, 247, 208, 0.85)';
        ctx.font = '14px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(weighed ? '1.00 g' : '0.00 g', w * 0.55, h * 0.68);
      }

      function drawBag(ctx, w, h) {
        drawLabBench(ctx, w, h);
        const bx = w * budPos.x;
        const by = h * budPos.y;
        if (!bagFilled) drawImg(ctx, 'leaf', bx, by, picked ? 50 : 52, 0, 1);
        ctx.fillStyle = bagFilled ? 'rgba(187, 247, 208, 0.25)' : 'rgba(187, 247, 208, 0.12)';
        ctx.strokeStyle = 'rgba(74, 222, 128, 0.5)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.roundRect(w * 0.62 - 45, h * 0.42, 90, 110, 10);
        ctx.fill();
        ctx.stroke();
        if (bagFilled) drawImg(ctx, 'leaf', w * 0.62, h * 0.48, 42, 0, 0.9);
        ctx.fillStyle = 'rgba(187, 247, 208, 0.7)';
        ctx.font = '11px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText('Mylar maišelis', w * 0.62, h * 0.58);
      }

      function drawSeal(ctx, w, h) {
        drawLabBench(ctx, w, h);
        ctx.fillStyle = 'rgba(187, 247, 208, 0.2)';
        ctx.strokeStyle = 'rgba(74, 222, 128, 0.55)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.roundRect(w * 0.35, h * 0.35, 130, 100, 12);
        ctx.fill();
        ctx.stroke();
        drawGauge(ctx, w * 0.15, h * 0.72, w * 0.7, marker, 0, 0, '');
        sealZones.forEach((z, i) => {
          const zx = w * 0.15 + w * 0.7 * (z / 100);
          ctx.beginPath();
          ctx.arc(zx, h * 0.72 + 5, i < seals ? 10 : 12, 0, Math.PI * 2);
          ctx.fillStyle = i < seals ? 'rgba(74, 222, 128, 0.9)' : 'rgba(74, 222, 128, 0.2)';
          ctx.fill();
          ctx.strokeStyle = '#bbf7d0';
          ctx.stroke();
        });
        ctx.fillStyle = 'rgba(187, 247, 208, 0.8)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Užlydinimas ${seals}/3 — spausk žalią zoną`, w * 0.5, h * 0.58);
      }

      bindResize(canvas, (ctx, w, h) => {
        if (phase === 'weigh') drawWeigh(ctx, w, h);
        else if (phase === 'bag') drawBag(ctx, w, h);
        else drawSeal(ctx, w, h);
      });

      canvas.onmousedown = (ev) => {
        if (phase !== 'bag' || bagFilled) return;
        const { x, y, w, h } = canvasPos(canvas, ev);
        if (Math.hypot(x - w * budPos.x, y - h * budPos.y) < 35) {
          drag = { ox: x - w * budPos.x, oy: y - h * budPos.y };
          picked = true;
        }
      };
      canvas.onmousemove = (ev) => {
        if (!drag || phase !== 'bag') return;
        const { x, y, w, h } = canvasPos(canvas, ev);
        budPos.x = clamp((x - drag.ox) / w, 0.1, 0.9);
        budPos.y = clamp((y - drag.oy) / h, 0.2, 0.8);
        const ctx = canvas.getContext('2d');
        drawBag(ctx, w, h);
      };
      const endDrag = () => {
        if (!drag || phase !== 'bag') return;
        drag = null;
        const w = canvas.parentElement.getBoundingClientRect().width;
        const h = canvas.parentElement.getBoundingClientRect().height;
        if (Math.hypot(budPos.x * w - w * 0.62, budPos.y * h - h * 0.48) < 55) {
          bagFilled = true;
          sfx('pour');
          setTimeout(() => {
            phase = 'seal';
            hooks.setStep(3, 3, 'Užlydink maišelį — 3 tikslūs paspaudimai');
            status.textContent = 'Spausk kai žymeklis ant žalios zonos';
            startSealLoop();
          }, 400);
        }
      };
      canvas.onmouseup = endDrag;
      canvas.onmouseleave = endDrag;

      canvas.onclick = (ev) => {
        const { x, y, w, h } = canvasPos(canvas, ev);
        if (phase === 'weigh') {
          if (!weighed && Math.hypot(x - w * budPos.x, y - h * budPos.y) < 40) {
            weighed = true;
            sfx('click');
            setTimeout(() => {
              phase = 'bag';
              budPos = { x: 0.28, y: 0.52 };
              hooks.setStep(2, 3, 'Perkelk žiedą į maišelį');
              status.textContent = 'Nutempk žiedą į maišelį';
            }, 500);
          }
        } else if (phase === 'seal') {
          const trackX = w * 0.15;
          const trackW = w * 0.7;
          const zone = sealZones[seals];
          if (zone == null) return;
          const zx = trackX + trackW * (zone / 100);
          const inMarker = marker >= zone - 8 && marker <= zone + 8;
          if (inMarker && Math.hypot(x - zx, y - h * 0.77) < 30) {
            seals += 1;
            sfx('seal');
            if (seals >= 3) winHooks(hooks, { score: 91 });
            else status.textContent = `Užlydinta ${seals}/3`;
          } else if (!inMarker) {
            sfx('fail');
            if (window.MgFx) MgFx.shake(0.8);
          }
        }
      };

      function startSealLoop() {
        runLoop(() => {
          marker += dir;
          if (marker >= 94) dir = -2.6;
          if (marker <= 6) dir = 2.6;
          const ctx = canvas.getContext('2d');
          const r = canvas.parentElement.getBoundingClientRect();
          drawSeal(ctx, r.width, r.height);
        });
      }
    });
  }

  return {
    runSoil,
    runSeed,
    runWater,
    runHarvest,
    runDry,
    runPack,
    cleanup,
  };
})();
