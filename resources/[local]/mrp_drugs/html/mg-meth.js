/**
 * Metamfetaminas — premium Canvas minigame (kristalizacija + smulkinimas/pakavimas).
 * Naudoja esamą scheduleResult flow; nekeičia serverio logikos.
 */
window.MgMeth = (() => {
  const ASSETS = {
    scale: 'icons/drug_scale.png',
    gloves: 'icons/gloves_item.png',
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
      Object.values(ASSETS).map((src) => new Promise((resolve) => {
        const img = new Image();
        img.onload = () => { images[src] = img; resolve(); };
        img.onerror = () => resolve();
        img.src = src;
      })),
    );
    return assetsReady;
  }

  function drawImg(ctx, src, cx, cy, size, rot = 0, alpha = 1) {
    const img = images[src];
    if (!img) return false;
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(rot);
    ctx.globalAlpha = alpha;
    ctx.drawImage(img, -size / 2, -size / 2, size, size);
    ctx.restore();
    return true;
  }

  function mountBoard() {
    if (typeof schBoard === 'undefined' || !schBoard) return null;
    schBoard.innerHTML = '';
    const root = document.createElement('div');
    root.className = 'mg-meth-root mg-scene-meth';
    schBoard.appendChild(root);
    return root;
  }

  function makeStage(parent) {
    const wrap = document.createElement('div');
    wrap.className = 'mg-meth-stage-wrap';
    const canvas = document.createElement('canvas');
    canvas.className = 'mg-meth-canvas';
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
    const tick = () => {
      fn();
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

  function createCrystals(count) {
    return Array.from({ length: count }, () => ({
      x: Math.random(),
      y: Math.random(),
      vx: (Math.random() - 0.5) * 0.0012,
      vy: -0.0005 - Math.random() * 0.001,
      life: 0.4 + Math.random() * 0.5,
      size: 2 + Math.random() * 4,
      rot: Math.random() * Math.PI,
    }));
  }

  function drawCrystalLab(ctx, w, h) {
    const grd = ctx.createLinearGradient(0, 0, 0, h);
    grd.addColorStop(0, '#040c18');
    grd.addColorStop(0.45, '#081828');
    grd.addColorStop(1, '#030a12');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, w, h);

    ctx.strokeStyle = 'rgba(56, 189, 248, 0.05)';
    for (let i = 0; i < 14; i += 1) {
      const x = (i / 14) * w;
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x + h * 0.3, h);
      ctx.stroke();
    }

    const glow = ctx.createRadialGradient(w * 0.5, h * 0.2, 0, w * 0.5, h * 0.35, w * 0.45);
    glow.addColorStop(0, 'rgba(56, 189, 248, 0.18)');
    glow.addColorStop(1, 'rgba(56, 189, 248, 0)');
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, w, h * 0.55);

    ctx.fillStyle = '#0f172a';
    ctx.fillRect(0, h * 0.78, w, h * 0.22);
  }

  function drawCrystalPart(ctx, px, py, size, rot, alpha) {
    ctx.save();
    ctx.translate(px, py);
    ctx.rotate(rot);
    ctx.globalAlpha = alpha;
    const g = ctx.createLinearGradient(-size, -size, size, size);
    g.addColorStop(0, '#e0f2fe');
    g.addColorStop(0.5, '#38bdf8');
    g.addColorStop(1, '#0ea5e9');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(0, -size);
    ctx.lineTo(size * 0.6, 0);
    ctx.lineTo(0, size);
    ctx.lineTo(-size * 0.6, 0);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = 'rgba(224, 242, 254, 0.6)';
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.restore();
  }

  function tickCrystalParts(ctx, parts, w, h, intensity) {
    parts.forEach((p) => {
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 0.003 * intensity;
      p.rot += 0.02;
      if (p.life <= 0 || p.y < -0.05) {
        p.x = 0.35 + Math.random() * 0.3;
        p.y = 0.65 + Math.random() * 0.2;
        p.life = 0.5 + Math.random() * 0.4;
      }
      drawCrystalPart(ctx, p.x * w, p.y * h, p.size * 2.5, p.rot, p.life * 0.45 * intensity);
    });
  }

  function drawReactor(ctx, cx, cy, scale, fillPct, heat) {
    ctx.save();
    ctx.translate(cx, cy);
    const bw = 70 * scale;
    const bh = 90 * scale;

    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.beginPath();
    ctx.ellipse(0, bh * 0.42, bw * 0.55, bh * 0.08, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = 'rgba(186, 230, 253, 0.5)';
    ctx.lineWidth = 2.5 * scale;
    ctx.beginPath();
    ctx.moveTo(-bw * 0.35, -bh * 0.38);
    ctx.lineTo(-bw * 0.42, bh * 0.28);
    ctx.lineTo(bw * 0.42, bh * 0.28);
    ctx.lineTo(bw * 0.35, -bh * 0.38);
    ctx.closePath();
    ctx.stroke();

    const fh = bh * 0.55 * clamp(fillPct, 0, 1);
    const lg = ctx.createLinearGradient(0, bh * 0.22, 0, bh * 0.22 - fh);
    lg.addColorStop(0, `rgba(14, 165, 233, ${0.75 + heat * 0.2})`);
    lg.addColorStop(0.5, `rgba(56, 189, 248, ${0.55 + heat * 0.15})`);
    lg.addColorStop(1, 'rgba(186, 230, 253, 0.25)');
    ctx.fillStyle = lg;
    ctx.fillRect(-bw * 0.38, bh * 0.22 - fh, bw * 0.76, fh);

    if (heat > 0.2) {
      const rg = ctx.createRadialGradient(0, bh * 0.05, 0, 0, bh * 0.05, bw * 0.5);
      rg.addColorStop(0, `rgba(103, 232, 249, ${heat * 0.35})`);
      rg.addColorStop(1, 'rgba(56, 189, 248, 0)');
      ctx.fillStyle = rg;
      ctx.fillRect(-bw * 0.5, -bh * 0.4, bw, bh * 0.5);
    }
    ctx.restore();
  }

  function drawCrystalCluster(ctx, cx, cy, scale, count, pulse, crushed) {
    const shards = Math.max(1, count);
    for (let i = 0; i < shards; i += 1) {
      const ang = (i / shards) * Math.PI * 2 - Math.PI / 2;
      const dist = (12 + (i % 3) * 8) * scale * (crushed ? 0.6 : 1);
      const px = cx + Math.cos(ang) * dist;
      const py = cy + Math.sin(ang) * dist * 0.6;
      const sz = (14 + (i % 2) * 6) * scale * (crushed ? 0.55 : 1);
      const a = crushed ? 0.5 : 0.75 + (i === pulse ? Math.sin(Date.now() / 120) * 0.25 : 0);
      drawCrystalPart(ctx, px, py, sz, ang + 0.4, a);
    }
  }

  function drawRingGauge(ctx, cx, cy, r, needle, zoneStart, zoneSweep, holdPct, label) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.strokeStyle = 'rgba(6, 24, 40, 0.92)';
    ctx.lineWidth = 14;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.stroke();
    ctx.strokeStyle = 'rgba(34, 197, 94, 0.85)';
    ctx.beginPath();
    ctx.arc(0, 0, r, zoneStart, zoneStart + zoneSweep);
    ctx.stroke();
    const arc = -Math.PI * 0.75 + (needle / 100) * Math.PI * 1.5;
    ctx.strokeStyle = '#e0f2fe';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(Math.cos(arc) * (r - 8), Math.sin(arc) * (r - 8));
    ctx.stroke();
    ctx.fillStyle = 'rgba(56, 189, 248, 0.22)';
    ctx.beginPath();
    ctx.arc(0, 0, r * 0.55, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#e0f2fe';
    ctx.font = 'bold 13px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(`${Math.round(holdPct)}%`, 0, 5);
    if (label) {
      ctx.font = '10px system-ui';
      ctx.fillStyle = 'rgba(186, 230, 253, 0.7)';
      ctx.fillText(label, 0, r + 18);
    }
    ctx.restore();
  }

  function drawGaugeBar(ctx, x, y, w, needle, zoneL, zoneW) {
    ctx.fillStyle = 'rgba(4, 16, 28, 0.9)';
    ctx.fillRect(x, y, w, 10);
    ctx.fillStyle = 'rgba(34, 197, 94, 0.6)';
    ctx.fillRect(x + w * (zoneL / 100), y, w * (zoneW / 100), 10);
    const nx = x + w * (needle / 100);
    ctx.fillStyle = '#f0f9ff';
    ctx.beginPath();
    ctx.moveTo(nx, y - 5);
    ctx.lineTo(nx + 5, y + 14);
    ctx.lineTo(nx - 5, y + 14);
    ctx.closePath();
    ctx.fill();
  }

  function addStatus(parent, text) {
    const s = document.createElement('p');
    s.className = 'mg-meth-status';
    s.textContent = text;
    parent.appendChild(s);
    return s;
  }

  function addBtn(parent, text, cls, onClick) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `mg-meth-btn mg-meth-btn--${cls || 'ghost'}`;
    b.textContent = text;
    if (onClick) b.onclick = onClick;
    parent.appendChild(b);
    return b;
  }

  function failHooks(hooks) {
    sfx('fail');
    if (window.MgFx) MgFx.shake(1.15);
    cleanup();
    hooks.onFail();
  }

  function winHooks(hooks, extra) {
    sfx('success');
    if (window.MgFx) MgFx.flash('rgba(56, 189, 248, 0.38)');
    cleanup();
    hooks.onWin(extra);
  }

  function armTimeout(ms, hooks) {
    const t = setTimeout(() => failHooks(hooks), ms);
    cleanups.push(() => clearTimeout(t));
  }

  /**
   * meth_process — kaitinimas → QWER seka → kristalizacija
   */
  function runCrystal(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      const difficulty = data.difficulty || 2;
      let phase = 'heat';
      let needle = 10;
      let dir = 1.6;
      let hold = 0;
      const needHold = 52;
      const zoneLeft = 25 + Math.floor(Math.random() * 38);
      const zoneWidth = 20;
      const zoneStart = -Math.PI * 0.75 + (zoneLeft / 100) * Math.PI * 1.5;
      const zoneSweep = (zoneWidth / 100) * Math.PI * 1.5;
      let spaceDown = false;
      let heatLevel = 0;
      const parts = createCrystals(22);

      const keys = ['Q', 'W', 'E', 'R'];
      const seqLen = 4 + difficulty;
      const seq = [];
      for (let i = 0; i < seqLen; i += 1) seq.push(keys[Math.floor(Math.random() * keys.length)]);
      let seqIdx = 0;

      let grows = 0;
      const growNeed = 3;
      let growPulse = 0;
      let growActive = 0;

      const { canvas } = makeStage(root);
      const hud = document.createElement('div');
      hud.className = 'mg-meth-hud';
      root.appendChild(hud);
      const status = addStatus(root, 'Laikyk SPACE — reaktorius žalioje zonoje');
      const keysRow = document.createElement('div');
      keysRow.className = 'mg-meth-keys';
      keysRow.style.display = 'none';
      root.appendChild(keysRow);

      hooks.setStep(1, 3, 'Kristalizacijos procesas');
      armTimeout(80000, hooks);

      function inZone() {
        return needle >= zoneLeft && needle <= zoneLeft + zoneWidth;
      }

      function bindHeatKeys() {
        const onKeyDown = (ev) => {
          if (ev.code === 'Space') {
            ev.preventDefault();
            spaceDown = true;
            if (!inZone()) failHooks(hooks);
          }
        };
        const onKeyUp = (ev) => {
          if (ev.code === 'Space') spaceDown = false;
        };
        window.addEventListener('keydown', onKeyDown);
        window.addEventListener('keyup', onKeyUp);
        cleanups.push(() => {
          window.removeEventListener('keydown', onKeyDown);
          window.removeEventListener('keyup', onKeyUp);
        });
      }

      function startSeqPhase() {
        phase = 'seq';
        hooks.setStep(2, 3, 'Stabilizuok molekulinę seką');
        status.textContent = `Seka: ${seq.join(' → ')}`;
        keysRow.style.display = '';
        keysRow.innerHTML = '';
        keys.forEach((k) => {
          const b = document.createElement('button');
          b.type = 'button';
          b.className = 'mg-meth-key';
          b.textContent = k;
          b.onclick = () => {
            if (k !== seq[seqIdx]) { failHooks(hooks); return; }
            b.classList.add('done');
            seqIdx += 1;
            sfx('tap');
            if (seqIdx >= seq.length) startGrowPhase();
          };
          keysRow.appendChild(b);
        });
        const map = { KeyQ: 'Q', KeyW: 'W', KeyE: 'E', KeyR: 'R' };
        const onKey = (ev) => {
          const k = map[ev.code];
          if (!k) return;
          ev.preventDefault();
          if (k !== seq[seqIdx]) { failHooks(hooks); return; }
          const btn = [...keysRow.children].find((el) => el.textContent === k && !el.classList.contains('done'));
          if (btn) btn.classList.add('done');
          seqIdx += 1;
          sfx('tap');
          if (seqIdx >= seq.length) startGrowPhase();
        };
        window.addEventListener('keydown', onKey);
        cleanups.push(() => window.removeEventListener('keydown', onKey));
      }

      function startGrowPhase() {
        phase = 'grow';
        keysRow.style.display = 'none';
        hooks.setStep(3, 3, 'Kristalizuok — spausk augančius kristalus');
        status.textContent = 'Spausk šviečiančius kristalus ant reaktoriaus';
        growActive = 0;
        growPulse = 0;
        runLoop(() => {
          growPulse += 0.07;
          const ctx = canvas.getContext('2d');
          const r = canvas.parentElement.getBoundingClientRect();
          drawGrow(ctx, r.width, r.height);
        });
      }

      function drawHeat(ctx, w, h) {
        drawCrystalLab(ctx, w, h);
        heatLevel = Math.min(1, hold / needHold);
        drawReactor(ctx, w * 0.48, h * 0.52, 1.1, 0.4 + heatLevel * 0.35, heatLevel);
        tickCrystalParts(ctx, parts, w, h, 0.6 + heatLevel);
        drawImg(ctx, ASSETS.gloves, w * 0.18, h * 0.65, 62, 0, 0.65);
        const pct = Math.min(100, (hold / needHold) * 100);
        drawRingGauge(ctx, w * 0.78, h * 0.42, Math.min(w, h) * 0.14, needle, zoneStart, zoneSweep, pct, 'Reakcijos temp.');
      }

      function drawSeq(ctx, w, h) {
        drawCrystalLab(ctx, w, h);
        drawReactor(ctx, w * 0.48, h * 0.5, 1.05, 0.78, 0.6);
        tickCrystalParts(ctx, parts, w, h, 0.9);
        ctx.fillStyle = 'rgba(186, 230, 253, 0.9)';
        ctx.font = '13px system-ui';
        ctx.textAlign = 'center';
        const done = seq.slice(0, seqIdx).join(' ');
        const rest = seq.slice(seqIdx).join(' → ');
        ctx.fillText(done ? `${done} ▶ ${rest}` : seq.join(' → '), w * 0.5, h * 0.18);
      }

      function drawGrow(ctx, w, h) {
        drawCrystalLab(ctx, w, h);
        drawReactor(ctx, w * 0.48, h * 0.5, 1.05, 0.85, 0.5);
        const spots = [
          { x: 0.38, y: 0.36 }, { x: 0.58, y: 0.34 }, { x: 0.48, y: 0.48 },
        ];
        spots.forEach((s, i) => {
          const px = w * s.x;
          const py = h * s.y;
          const active = i === growActive && grows < growNeed;
          if (i < grows) {
            drawCrystalCluster(ctx, px, py, 0.9, 3, -1, false);
          } else if (active) {
            const pulse = 0.6 + Math.sin(growPulse) * 0.35;
            ctx.beginPath();
            ctx.arc(px, py, 20, 0, Math.PI * 2);
            ctx.strokeStyle = `rgba(103, 232, 249, ${pulse})`;
            ctx.lineWidth = 2;
            ctx.stroke();
            drawCrystalCluster(ctx, px, py, 0.7, 2, i, false);
          }
        });
        tickCrystalParts(ctx, parts, w, h, 1.1);
      }

      bindResize(canvas, (ctx, w, h) => {
        if (phase === 'heat') drawHeat(ctx, w, h);
        else if (phase === 'seq') drawSeq(ctx, w, h);
        else drawGrow(ctx, w, h);
      });

      bindHeatKeys();
      runLoop(() => {
        if (phase !== 'heat') return;
        needle += dir;
        if (needle >= 98) dir = -1.6;
        if (needle <= 2) dir = 1.6;
        if (spaceDown && inZone()) {
          hold += 1;
          if (hold % 10 === 0) sfx('bubble');
        }
        if (hooks.hint) hooks.hint.textContent = `Kaitinimas — ${Math.min(100, Math.floor((hold / needHold) * 100))}%`;
        if (hold >= needHold) {
          stopLoop();
          sfx('synth');
          startSeqPhase();
        }
        const ctx = canvas.getContext('2d');
        const r = canvas.parentElement.getBoundingClientRect();
        drawHeat(ctx, r.width, r.height);
      });

      canvas.onclick = (ev) => {
        if (phase !== 'grow') return;
        const { x, y, w, h } = canvasPos(canvas, ev);
        const spots = [{ x: 0.38, y: 0.36 }, { x: 0.58, y: 0.34 }, { x: 0.48, y: 0.48 }];
        const s = spots[growActive];
        if (!s || grows >= growNeed) return;
        if (Math.hypot(x - w * s.x, y - h * s.y) < 26) {
          grows += 1;
          growActive += 1;
          sfx('press');
          if (window.MgFx) MgFx.flash('rgba(56, 189, 248, 0.3)');
          if (grows >= growNeed) winHooks(hooks, { score: 90 });
          else status.textContent = `Kristalai ${grows}/${growNeed}`;
        }
      };
    });
  }

  /**
   * meth_pack — smulkinimas → svėrimas → pakavimas → užlydinimas
   */
  function runCrushPack(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      let phase = 'crush';
      let hits = 0;
      const hitNeed = 4;
      let needle = 8;
      let nDir = 2.2;
      const zoneL = 38;
      const zoneW = 24;
      let crushLevel = 0;

      let weighed = false;
      let picked = false;
      let bagFilled = false;
      let seals = 0;
      let sealMarker = 10;
      let sealDir = 2.5;
      const sealZones = [22, 50, 78];
      let budPos = { x: 0.28, y: 0.55 };
      let drag = null;

      const { canvas } = makeStage(root);
      const hud = document.createElement('div');
      hud.className = 'mg-meth-hud';
      root.appendChild(hud);
      const status = addStatus(root, 'Spausk kai žymeklis žalioje zonoje');
      const crushBtn = addBtn(hud, 'Smūgiuoti', 'primary', null);
      crushBtn.style.display = '';

      hooks.setStep(1, 3, 'Sutraišk kristalus');
      armTimeout(70000, hooks);

      function drawCrush(ctx, w, h) {
        drawCrystalLab(ctx, w, h);
        ctx.fillStyle = '#1e293b';
        ctx.fillRect(w * 0.22, h * 0.62, w * 0.56, h * 0.08);
        drawCrystalCluster(ctx, w * 0.5, h * 0.52, 1.2, 5, -1, crushLevel > 0);
        if (crushLevel > 0) {
          for (let i = 0; i < crushLevel * 3; i += 1) {
            drawCrystalPart(ctx, w * (0.4 + Math.random() * 0.2), h * (0.48 + Math.random() * 0.1), 6, Math.random(), 0.4);
          }
        }
        drawGaugeBar(ctx, w * 0.15, h * 0.78, w * 0.7, needle, zoneL, zoneW);
        ctx.fillStyle = 'rgba(186, 230, 253, 0.75)';
        ctx.font = '11px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Smūgiai ${hits}/${hitNeed}`, w * 0.5, h * 0.72);
      }

      function drawWeigh(ctx, w, h) {
        drawCrystalLab(ctx, w, h);
        drawImg(ctx, ASSETS.scale, w * 0.55, h * 0.52, 115, 0, 1);
        drawCrystalCluster(ctx, w * 0.28, h * 0.55, 1, 4, -1, true);
        if (weighed) drawCrystalCluster(ctx, w * 0.55, h * 0.4, 0.75, 3, -1, true);
        ctx.fillStyle = 'rgba(186, 230, 253, 0.85)';
        ctx.font = '14px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(weighed ? '1.92 g' : '0.00 g', w * 0.55, h * 0.68);
      }

      function drawPack(ctx, w, h) {
        drawCrystalLab(ctx, w, h);
        if (!bagFilled) drawCrystalCluster(ctx, w * budPos.x, h * budPos.y, 0.9, 3, -1, true);
        ctx.fillStyle = bagFilled ? 'rgba(186, 230, 253, 0.2)' : 'rgba(186, 230, 253, 0.1)';
        ctx.strokeStyle = 'rgba(56, 189, 248, 0.5)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.roundRect(w * 0.62 - 45, h * 0.4, 90, 110, 10);
        ctx.fill();
        ctx.stroke();
        if (bagFilled) drawCrystalCluster(ctx, w * 0.62, h * 0.46, 0.65, 2, -1, true);
        ctx.fillStyle = 'rgba(186, 230, 253, 0.7)';
        ctx.font = '11px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText('Mylar maišelis', w * 0.62, h * 0.56);
      }

      function drawSeal(ctx, w, h) {
        drawCrystalLab(ctx, w, h);
        ctx.fillStyle = 'rgba(186, 230, 253, 0.15)';
        ctx.strokeStyle = 'rgba(56, 189, 248, 0.55)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.roundRect(w * 0.35, h * 0.34, 130, 100, 12);
        ctx.fill();
        ctx.stroke();
        drawGaugeBar(ctx, w * 0.12, h * 0.72, w * 0.76, sealMarker, 0, 0);
        sealZones.forEach((z, i) => {
          const zx = w * 0.12 + w * 0.76 * (z / 100);
          ctx.beginPath();
          ctx.arc(zx, h * 0.72 + 5, i < seals ? 9 : 11, 0, Math.PI * 2);
          ctx.fillStyle = i < seals ? 'rgba(56, 189, 248, 0.9)' : 'rgba(56, 189, 248, 0.2)';
          ctx.fill();
          ctx.strokeStyle = '#e0f2fe';
          ctx.stroke();
        });
        ctx.fillStyle = 'rgba(186, 230, 253, 0.8)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Užlydinimas ${seals}/3`, w * 0.5, h * 0.58);
      }

      bindResize(canvas, (ctx, w, h) => {
        if (phase === 'crush') drawCrush(ctx, w, h);
        else if (phase === 'weigh') drawWeigh(ctx, w, h);
        else if (phase === 'pack') drawPack(ctx, w, h);
        else drawSeal(ctx, w, h);
      });

      crushBtn.onclick = () => {
        if (phase !== 'crush') return;
        const ok = needle >= zoneL && needle <= zoneL + zoneW;
        if (!ok) {
          failHooks(hooks);
          return;
        }
        hits += 1;
        crushLevel += 1;
        sfx('press');
        if (window.MgFx) MgFx.shake(0.6);
        if (hits >= hitNeed) {
          phase = 'weigh';
          crushBtn.style.display = 'none';
          stopLoop();
          hooks.setStep(2, 3, 'Sverti ir supakuoti');
          status.textContent = 'Paspausk kristalus, tada svarstykles';
        } else {
          status.textContent = `Smūgiai ${hits}/${hitNeed}`;
        }
      };

      runLoop(() => {
        if (phase === 'crush') {
          needle += nDir;
          if (needle >= 94) nDir = -2.2;
          if (needle <= 4) nDir = 2.2;
        } else if (phase === 'seal') {
          sealMarker += sealDir;
          if (sealMarker >= 94) sealDir = -2.5;
          if (sealMarker <= 6) sealDir = 2.5;
        } else return;
        const ctx = canvas.getContext('2d');
        const r = canvas.parentElement.getBoundingClientRect();
        if (phase === 'crush') drawCrush(ctx, r.width, r.height);
        else drawSeal(ctx, r.width, r.height);
      });

      canvas.onmousedown = (ev) => {
        if (phase !== 'pack' || bagFilled) return;
        const { x, y, w, h } = canvasPos(canvas, ev);
        if (Math.hypot(x - w * budPos.x, y - h * budPos.y) < 40) {
          drag = { ox: x - w * budPos.x, oy: y - h * budPos.y };
          picked = true;
        }
      };
      canvas.onmousemove = (ev) => {
        if (!drag || phase !== 'pack') return;
        const { x, y, w, h } = canvasPos(canvas, ev);
        budPos.x = clamp((x - drag.ox) / w, 0.1, 0.9);
        budPos.y = clamp((y - drag.oy) / h, 0.2, 0.8);
      };
      const endDrag = () => {
        if (!drag || phase !== 'pack') return;
        drag = null;
        const r = canvas.parentElement.getBoundingClientRect();
        if (Math.hypot(budPos.x * r.width - r.width * 0.62, budPos.y * r.height - r.height * 0.46) < 55) {
          bagFilled = true;
          sfx('pour');
          setTimeout(() => {
            phase = 'seal';
            hooks.setStep(3, 3, 'Užlydink maišelį');
            status.textContent = 'Spausk kai žymeklis ant užlydinimo taško';
          }, 400);
        }
      };
      canvas.onmouseup = endDrag;
      canvas.onmouseleave = endDrag;

      canvas.onclick = (ev) => {
        const { x, y, w, h } = canvasPos(canvas, ev);
        if (phase === 'weigh') {
          if (!weighed && Math.hypot(x - w * 0.28, y - h * 0.55) < 45) {
            weighed = true;
            sfx('click');
            status.textContent = 'Spausk svarstykles';
          } else if (weighed && Math.hypot(x - w * 0.55, y - h * 0.52) < 60) {
            phase = 'pack';
            budPos = { x: 0.28, y: 0.55 };
            status.textContent = 'Nutempk kristalus į maišelį';
          }
        } else if (phase === 'seal') {
          const trackX = w * 0.12;
          const trackW = w * 0.76;
          const zone = sealZones[seals];
          if (zone == null) return;
          const zx = trackX + trackW * (zone / 100);
          const inMarker = sealMarker >= zone - 8 && sealMarker <= zone + 8;
          if (inMarker && Math.hypot(x - zx, y - h * 0.77) < 28) {
            seals += 1;
            sfx('seal');
            if (seals >= 3) winHooks(hooks, { score: 90 });
            else status.textContent = `Užlydinta ${seals}/3`;
          } else if (!inMarker) {
            sfx('fail');
            if (window.MgFx) MgFx.shake(0.8);
          }
        }
      };
    });
  }

  return { runCrystal, runCrushPack, cleanup };
})();
