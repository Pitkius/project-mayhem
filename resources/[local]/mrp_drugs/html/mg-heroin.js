/**
 * Heroinas — premium Canvas minigame (redukcija + folijos pakavimas).
 * Naudoja esamą scheduleResult flow; nekeičia serverio logikos.
 */
window.MgHeroin = (() => {
  const COLORS = {
    accent: '#f87171',
    accent2: '#b91c1c',
    liquid: '#92400e',
    liquid2: '#78350f',
    glow: 'rgba(248, 113, 113, 0.45)',
    foil: '#cbd5e1',
  };

  const ASSETS = {
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
      Object.entries(ASSETS).map(([, src]) => new Promise((resolve) => {
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
    root.className = 'mg-heroin-root mg-scene-heroin';
    schBoard.appendChild(root);
    return root;
  }

  function makeStage(parent) {
    const wrap = document.createElement('div');
    wrap.className = 'mg-heroin-stage-wrap';
    const canvas = document.createElement('canvas');
    canvas.className = 'mg-heroin-canvas';
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

  function createSteam(count) {
    const parts = [];
    for (let i = 0; i < count; i += 1) {
      parts.push({
        x: 0.4 + Math.random() * 0.2,
        y: 0.5 + Math.random() * 0.15,
        vx: (Math.random() - 0.5) * 0.001,
        vy: -0.001 - Math.random() * 0.0015,
        life: 0.4 + Math.random() * 0.5,
        size: 3 + Math.random() * 6,
      });
    }
    return parts;
  }

  function drawSteam(ctx, w, h, parts, cx, cy, intensity) {
    parts.forEach((p) => {
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 0.004 * intensity;
      if (p.life <= 0) {
        p.x = 0.45 + Math.random() * 0.1;
        p.y = 0.55;
        p.life = 0.5 + Math.random() * 0.4;
      }
      const px = (cx / w + p.x * 0.08) * w;
      const py = (cy / h + p.y * 0.08) * h;
      const g = ctx.createRadialGradient(px, py, 0, px, py, p.size * 2.5);
      g.addColorStop(0, `rgba(254, 202, 202, ${p.life * 0.35 * intensity})`);
      g.addColorStop(1, 'rgba(248, 113, 113, 0)');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(px, py, p.size * 2.5, 0, Math.PI * 2);
      ctx.fill();
    });
  }

  function drawMedLab(ctx, w, h) {
    const grd = ctx.createLinearGradient(0, 0, 0, h);
    grd.addColorStop(0, '#140608');
    grd.addColorStop(0.5, '#1c0a0c');
    grd.addColorStop(1, '#0c0406');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, w, h);

    ctx.fillStyle = '#1a1008';
    ctx.fillRect(0, h * 0.76, w, h * 0.24);

    const scan = ctx.createLinearGradient(0, h * 0.05, 0, h * 0.15);
    scan.addColorStop(0, 'rgba(248, 113, 113, 0.12)');
    scan.addColorStop(1, 'rgba(248, 113, 113, 0)');
    ctx.fillStyle = scan;
    ctx.fillRect(0, 0, w, h * 0.2);

    ctx.strokeStyle = 'rgba(248, 113, 113, 0.06)';
    for (let i = 0; i < 10; i += 1) {
      const y = h * 0.78 + i * 3;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }
  }

  function drawBurner(ctx, cx, cy, scale, flameIntensity) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.fillStyle = '#1f2937';
    ctx.fillRect(-28 * scale, 8 * scale, 56 * scale, 18 * scale);
    const f = flameIntensity || 0.5;
    const fg = ctx.createRadialGradient(0, -8 * scale, 0, 0, -8 * scale, 22 * scale);
    fg.addColorStop(0, `rgba(253, 224, 71, ${0.5 + f * 0.4})`);
    fg.addColorStop(0.45, `rgba(249, 115, 22, ${0.35 + f * 0.35})`);
    fg.addColorStop(1, 'rgba(239, 68, 68, 0)');
    ctx.fillStyle = fg;
    ctx.beginPath();
    ctx.ellipse(0, -6 * scale, 14 * scale, 22 * scale * (0.7 + f * 0.3), 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  function drawFlask(ctx, cx, cy, scale, fillPct, heat) {
    const bw = 36 * scale;
    const bh = 58 * scale;
    ctx.save();
    ctx.translate(cx, cy);

    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    ctx.beginPath();
    ctx.ellipse(0, bh * 0.52, bw * 0.85, bh * 0.1, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = 'rgba(254, 202, 202, 0.45)';
    ctx.lineWidth = 2 * scale;
    ctx.beginPath();
    ctx.moveTo(-bw * 0.3, -bh * 0.42);
    ctx.lineTo(-bw * 0.4, bh * 0.32);
    ctx.quadraticCurveTo(0, bh * 0.45, bw * 0.4, bh * 0.32);
    ctx.lineTo(bw * 0.3, -bh * 0.42);
    ctx.closePath();
    ctx.stroke();

    const fh = bh * 0.65 * clamp(fillPct, 0, 1);
    const hue = 18 + (heat || 0) * 0.15;
    const lg = ctx.createLinearGradient(0, bh * 0.3, 0, bh * 0.3 - fh);
    lg.addColorStop(0, `hsla(${hue}, 65%, 32%, 0.92)`);
    lg.addColorStop(1, `hsla(${hue + 10}, 70%, 42%, 0.55)`);
    ctx.fillStyle = lg;
    ctx.beginPath();
    ctx.moveTo(-bw * 0.36, bh * 0.28);
    ctx.lineTo(-bw * 0.36, bh * 0.28 - fh);
    ctx.lineTo(bw * 0.36, bh * 0.28 - fh);
    ctx.lineTo(bw * 0.36, bh * 0.28);
    ctx.closePath();
    ctx.fill();

    if (heat > 0.3) {
      ctx.strokeStyle = `rgba(248, 113, 113, ${heat * 0.4})`;
      ctx.lineWidth = 1.5 * scale;
      ctx.beginPath();
      ctx.arc(0, bh * 0.05, bw * 0.5, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawBeaker(ctx, cx, cy, scale, fillPct, stirAngle) {
    const w = 58 * scale;
    const h = 68 * scale;
    ctx.save();
    ctx.translate(cx, cy);
    ctx.strokeStyle = 'rgba(254, 202, 202, 0.5)';
    ctx.lineWidth = 2.2 * scale;
    ctx.beginPath();
    ctx.rect(-w / 2, -h * 0.35, w, h);
    ctx.stroke();

    const fh = h * 0.8 * clamp(fillPct, 0, 1);
    const g = ctx.createLinearGradient(0, h * 0.45, 0, h * 0.45 - fh);
    g.addColorStop(0, 'rgba(146, 64, 14, 0.9)');
    g.addColorStop(0.5, 'rgba(180, 83, 9, 0.75)');
    g.addColorStop(1, 'rgba(217, 119, 6, 0.4)');
    ctx.fillStyle = g;
    ctx.fillRect(-w / 2 + 3, h * 0.45 - fh, w - 6, fh);

    if (stirAngle != null) {
      ctx.strokeStyle = 'rgba(254, 226, 226, 0.7)';
      ctx.lineWidth = 2;
      const r = 18 * scale;
      for (let i = 0; i < 3; i += 1) {
        const a = stirAngle + (i * Math.PI * 2) / 3;
        ctx.beginPath();
        ctx.moveTo(0, -h * 0.1);
        ctx.lineTo(Math.cos(a) * r, -h * 0.1 + Math.sin(a) * r * 0.4);
        ctx.stroke();
      }
    }
    ctx.restore();
  }

  function drawRingGauge(ctx, cx, cy, r, needle, zoneStart, zoneSweep, holdPct, label) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.strokeStyle = 'rgba(40, 8, 8, 0.9)';
    ctx.lineWidth = 14;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.stroke();

    ctx.strokeStyle = 'rgba(34, 197, 94, 0.85)';
    ctx.lineWidth = 14;
    ctx.beginPath();
    ctx.arc(0, 0, r, zoneStart, zoneStart + zoneSweep);
    ctx.stroke();

    const arc = -Math.PI * 0.75 + (needle / 100) * Math.PI * 1.5;
    ctx.strokeStyle = '#fecaca';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(Math.cos(arc) * (r - 8), Math.sin(arc) * (r - 8));
    ctx.stroke();

    ctx.fillStyle = 'rgba(248, 113, 113, 0.2)';
    ctx.beginPath();
    ctx.arc(0, 0, r * 0.55, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#fecaca';
    ctx.font = 'bold 13px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(`${Math.round(holdPct)}%`, 0, 5);
    if (label) {
      ctx.font = '10px system-ui';
      ctx.fillStyle = 'rgba(254, 202, 202, 0.65)';
      ctx.fillText(label, 0, r + 18);
    }
    ctx.restore();
  }

  function drawFoil(ctx, cx, cy, w, h, folds, productVisible) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(folds * 0.08);

    const foilG = ctx.createLinearGradient(-w / 2, 0, w / 2, 0);
    foilG.addColorStop(0, '#94a3b8');
    foilG.addColorStop(0.3, '#e2e8f0');
    foilG.addColorStop(0.5, '#f8fafc');
    foilG.addColorStop(0.7, '#e2e8f0');
    foilG.addColorStop(1, '#94a3b8');
    ctx.fillStyle = foilG;
    ctx.strokeStyle = 'rgba(148, 163, 184, 0.8)';
    ctx.lineWidth = 2;
    const shrink = folds * 0.04;
    ctx.beginPath();
    ctx.rect(-w / 2 * (1 - shrink), -h / 2 * (1 - shrink), w * (1 - shrink), h * (1 - shrink));
    ctx.fill();
    ctx.stroke();

    if (productVisible) {
      ctx.fillStyle = 'rgba(146, 64, 14, 0.85)';
      ctx.beginPath();
      ctx.ellipse(0, 0, w * 0.18, h * 0.12, 0, 0, Math.PI * 2);
      ctx.fill();
    }

    for (let i = 0; i < 3; i += 1) {
      const fy = -h * 0.25 + i * h * 0.22;
      ctx.strokeStyle = i < folds ? 'rgba(248, 113, 113, 0.9)' : 'rgba(248, 113, 113, 0.35)';
      ctx.setLineDash(i < folds ? [] : [5, 4]);
      ctx.beginPath();
      ctx.moveTo(-w * 0.4, fy);
      ctx.lineTo(w * 0.4, fy);
      ctx.stroke();
    }
    ctx.setLineDash([]);
    ctx.restore();
  }

  function drawSealTrack(ctx, x, y, w, marker, zones, sealed) {
    ctx.fillStyle = 'rgba(28, 6, 6, 0.88)';
    ctx.fillRect(x, y, w, 10);
    zones.forEach((z, i) => {
      const zx = x + w * (z / 100);
      ctx.beginPath();
      ctx.arc(zx, y + 5, i < sealed ? 9 : 11, 0, Math.PI * 2);
      ctx.fillStyle = i < sealed ? 'rgba(248, 113, 113, 0.9)' : 'rgba(248, 113, 113, 0.22)';
      ctx.fill();
      ctx.strokeStyle = '#fecaca';
      ctx.stroke();
    });
    ctx.fillStyle = '#fff';
    const mx = x + w * (marker / 100);
    ctx.beginPath();
    ctx.moveTo(mx, y - 5);
    ctx.lineTo(mx + 5, y + 14);
    ctx.lineTo(mx - 5, y + 14);
    ctx.closePath();
    ctx.fill();
  }

  function addStatus(parent, text) {
    const s = document.createElement('p');
    s.className = 'mg-heroin-status';
    s.textContent = text;
    parent.appendChild(s);
    return s;
  }

  function addBtn(parent, text, cls, onClick) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `mg-heroin-btn mg-heroin-btn--${cls || 'ghost'}`;
    b.textContent = text;
    b.onclick = onClick;
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
    if (window.MgFx) MgFx.flash('rgba(248, 113, 113, 0.35)');
    cleanup();
    hooks.onWin(extra);
  }

  function armTimeout(ms, hooks) {
    const t = setTimeout(() => failHooks(hooks), ms);
    cleanups.push(() => clearTimeout(t));
  }

  /**
   * heroin_process — kaitinimas → maišymas → redukcijos seka
   */
  function runCook(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      let phase = 'heat';
      let needle = 10;
      let dir = 1.55;
      let hold = 0;
      const needHold = 52;
      const zoneLeft = 25 + Math.floor(Math.random() * 38);
      const zoneWidth = 22;
      const zoneStart = -Math.PI * 0.75 + (zoneLeft / 100) * Math.PI * 1.5;
      const zoneSweep = (zoneWidth / 100) * Math.PI * 1.5;
      let spaceDown = false;
      let heatLevel = 0;
      const steam = createSteam(20);

      let stirs = 0;
      const stirNeed = 4;
      let stirAngle = 0;
      let stirPulse = 0;
      let stirActive = 0;

      const keys = ['W', 'A', 'S', 'D'];
      const seq = [];
      for (let i = 0; i < 3; i += 1) seq.push(keys[Math.floor(Math.random() * keys.length)]);
      let seqIdx = 0;

      const { canvas } = makeStage(root);
      const hud = document.createElement('div');
      hud.className = 'mg-heroin-hud';
      root.appendChild(hud);
      const status = addStatus(root, 'Laikyk SPACE — temperatūra žalioje zonoje');
      const keysRow = document.createElement('div');
      keysRow.className = 'mg-heroin-keys';
      keysRow.style.display = 'none';
      root.appendChild(keysRow);

      hooks.setStep(1, 3, 'Kaitink tirpalą');
      armTimeout(75000, hooks);

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

      function startStirPhase() {
        phase = 'stir';
        hooks.setStep(2, 3, 'Maišyk su mentoliu — spausk aktyvius taškus');
        status.textContent = 'Maišyk — spausk šviečiančius taškus ant indo';
        stirActive = 0;
        stirPulse = 0;
        runLoop(() => {
          stirAngle += 0.08;
          stirPulse += 0.06;
          const ctx = canvas.getContext('2d');
          const r = canvas.parentElement.getBoundingClientRect();
          drawStir(ctx, r.width, r.height);
        });
      }

      function startSeqPhase() {
        phase = 'seq';
        hooks.setStep(3, 3, 'Stabilizuok redukciją — sek seką');
        status.textContent = `Seka: ${seq.join(' → ')}`;
        keysRow.style.display = '';
        keysRow.innerHTML = '';
        keys.forEach((k) => {
          const b = document.createElement('button');
          b.type = 'button';
          b.className = 'mg-heroin-key';
          b.textContent = k;
          b.onclick = () => {
            if (k !== seq[seqIdx]) {
              failHooks(hooks);
              return;
            }
            b.classList.add('done');
            seqIdx += 1;
            sfx('tap');
            if (seqIdx >= seq.length) winHooks(hooks, { score: 84 });
          };
          keysRow.appendChild(b);
        });
        bindSeqKeys();
      }

      function bindSeqKeys() {
        const map = { KeyW: 'W', KeyA: 'A', KeyS: 'S', KeyD: 'D' };
        const onKey = (ev) => {
          const k = map[ev.code];
          if (!k) return;
          ev.preventDefault();
          if (k !== seq[seqIdx]) {
            failHooks(hooks);
            return;
          }
          const btn = [...keysRow.children].find((el) => el.textContent === k && !el.classList.contains('done'));
          if (btn) btn.classList.add('done');
          seqIdx += 1;
          sfx('tap');
          if (seqIdx >= seq.length) winHooks(hooks, { score: 84 });
        };
        window.addEventListener('keydown', onKey);
        cleanups.push(() => window.removeEventListener('keydown', onKey));
      }

      function drawHeat(ctx, w, h) {
        drawMedLab(ctx, w, h);
        heatLevel = Math.min(1, hold / needHold);
        drawBurner(ctx, w * 0.5, h * 0.72, 1.1, heatLevel);
        drawFlask(ctx, w * 0.5, h * 0.48, 1.15, 0.55 + heatLevel * 0.25, heatLevel);
        drawSteam(ctx, w, h, steam, w * 0.5, h * 0.35, 0.5 + heatLevel);
        drawImg(ctx, ASSETS.gloves, w * 0.18, h * 0.62, 64, 0, 0.7);
        const pct = Math.min(100, (hold / needHold) * 100);
        drawRingGauge(ctx, w * 0.78, h * 0.42, Math.min(w, h) * 0.14, needle, zoneStart, zoneSweep, pct, 'Temperatūra');
      }

      function drawStir(ctx, w, h) {
        drawMedLab(ctx, w, h);
        drawBeaker(ctx, w * 0.5, h * 0.5, 1.2, 0.7, stirAngle);
        drawSteam(ctx, w, h, steam, w * 0.5, h * 0.38, 0.6);
        const spots = [
          { x: 0.38, y: 0.38 }, { x: 0.62, y: 0.36 },
          { x: 0.42, y: 0.52 }, { x: 0.58, y: 0.54 },
        ];
        spots.forEach((s, i) => {
          const px = w * s.x;
          const py = h * s.y;
          const active = i === stirActive && stirs < stirNeed;
          const pulse = active ? 0.55 + Math.sin(stirPulse) * 0.35 : 0.15;
          ctx.beginPath();
          ctx.arc(px, py, active ? 16 : 10, 0, Math.PI * 2);
          ctx.fillStyle = i < stirs
            ? 'rgba(74, 222, 128, 0.85)'
            : `rgba(248, 113, 113, ${pulse})`;
          ctx.fill();
          if (active) {
            ctx.strokeStyle = '#fecaca';
            ctx.lineWidth = 2;
            ctx.stroke();
          }
        });
      }

      function drawSeq(ctx, w, h) {
        drawMedLab(ctx, w, h);
        drawBeaker(ctx, w * 0.5, h * 0.48, 1.15, 0.85, stirAngle);
        drawSteam(ctx, w, h, steam, w * 0.5, h * 0.35, 0.4);
        ctx.fillStyle = 'rgba(254, 202, 202, 0.85)';
        ctx.font = '13px system-ui';
        ctx.textAlign = 'center';
        const done = seq.slice(0, seqIdx).join(' ');
        const rest = seq.slice(seqIdx).join(' → ');
        ctx.fillText(done ? `${done} ▶ ${rest}` : seq.join(' → '), w * 0.5, h * 0.2);
      }

      bindResize(canvas, (ctx, w, h) => {
        if (phase === 'heat') drawHeat(ctx, w, h);
        else if (phase === 'stir') drawStir(ctx, w, h);
        else drawSeq(ctx, w, h);
      });

      bindHeatKeys();
      runLoop(() => {
        if (phase !== 'heat') return;
        needle += dir;
        if (needle >= 98) dir = -1.55;
        if (needle <= 2) dir = 1.55;
        if (spaceDown && inZone()) {
          hold += 1;
          if (hold % 10 === 0) sfx('bubble');
        }
        if (hooks.hint) hooks.hint.textContent = `Kaitinimas — ${Math.min(100, Math.floor((hold / needHold) * 100))}%`;
        if (hold >= needHold) {
          stopLoop();
          sfx('synth');
          startStirPhase();
        }
        const ctx = canvas.getContext('2d');
        const r = canvas.parentElement.getBoundingClientRect();
        drawHeat(ctx, r.width, r.height);
      });

      canvas.onclick = (ev) => {
        if (phase !== 'stir') return;
        const { x, y, w, h } = canvasPos(canvas, ev);
        const spots = [
          { x: 0.38, y: 0.38 }, { x: 0.62, y: 0.36 },
          { x: 0.42, y: 0.52 }, { x: 0.58, y: 0.54 },
        ];
        const s = spots[stirActive];
        if (!s || stirs >= stirNeed) return;
        if (Math.hypot(x - w * s.x, y - h * s.y) < 24) {
          stirs += 1;
          stirActive += 1;
          sfx('tap');
          if (window.MgFx) MgFx.flash('rgba(248, 113, 113, 0.25)');
          if (stirs >= stirNeed) {
            stopLoop();
            startSeqPhase();
          } else {
            status.textContent = `Maišymas ${stirs}/${stirNeed}`;
          }
        }
      };
    });
  }

  /**
   * heroin_pack — folijos lankstymai + terminis užlydinimas
   */
  function runFold(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      const foldNeed = data.steps || 3;
      let folds = 0;
      let phase = 'fold';
      let seals = 0;
      let marker = 10;
      let dir = 2.5;
      const sealZones = [24, 52, 78];

      const { canvas } = makeStage(root);
      const hud = document.createElement('div');
      hud.className = 'mg-heroin-hud';
      root.appendChild(hud);
      const status = addStatus(root, 'Spausk ant folijos lankstymo linijų');

      hooks.setStep(1, foldNeed + 1, 'Sulankstyk foliją');
      armTimeout(60000, hooks);

      const foldLines = [
        { y: 0.38, done: false },
        { y: 0.5, done: false },
        { y: 0.62, done: false },
      ].slice(0, foldNeed);

      function drawFoldScene(ctx, w, h) {
        drawMedLab(ctx, w, h);
        drawFoil(ctx, w * 0.5, h * 0.48, w * 0.42, h * 0.32, folds, true);
        drawImg(ctx, ASSETS.scale, w * 0.82, h * 0.72, 70, 0, 0.55);
        foldLines.forEach((line, i) => {
          if (line.done) return;
          const ly = h * line.y;
          const active = i === folds;
          ctx.strokeStyle = active ? 'rgba(248, 113, 113, 0.95)' : 'rgba(248, 113, 113, 0.3)';
          ctx.lineWidth = active ? 3 : 1.5;
          ctx.setLineDash(active ? [] : [6, 4]);
          ctx.beginPath();
          ctx.moveTo(w * 0.28, ly);
          ctx.lineTo(w * 0.72, ly);
          ctx.stroke();
          if (active) {
            ctx.fillStyle = 'rgba(254, 202, 202, 0.8)';
            ctx.font = '11px system-ui';
            ctx.textAlign = 'center';
            ctx.fillText('Spausk čia', w * 0.5, ly - 8);
          }
        });
        ctx.setLineDash([]);
      }

      function drawSealScene(ctx, w, h) {
        drawMedLab(ctx, w, h);
        drawFoil(ctx, w * 0.5, h * 0.42, w * 0.32, h * 0.22, foldNeed, false);
        ctx.fillStyle = 'rgba(254, 202, 202, 0.75)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText('Terminis užlydinimas — spausk žalią zoną', w * 0.5, h * 0.22);
        drawSealTrack(ctx, w * 0.12, h * 0.68, w * 0.76, marker, sealZones, seals);
      }

      bindResize(canvas, (ctx, w, h) => {
        if (phase === 'fold') drawFoldScene(ctx, w, h);
        else drawSealScene(ctx, w, h);
      });

      canvas.onclick = (ev) => {
        const { x, y, w, h } = canvasPos(canvas, ev);
        if (phase === 'fold') {
          const line = foldLines[folds];
          if (!line || line.done) return;
          const ly = h * line.y;
          if (y > ly - 18 && y < ly + 18 && x > w * 0.25 && x < w * 0.75) {
            line.done = true;
            folds += 1;
            sfx('scrape');
            if (window.MgFx) MgFx.flash('rgba(248, 113, 113, 0.2)');
            status.textContent = `Sulankstyta ${folds}/${foldNeed}`;
            if (folds >= foldNeed) {
              phase = 'seal';
              hooks.setStep(2, foldNeed + 1, 'Užlydink maišelį');
              status.textContent = 'Laikyk žymeklį ant užlydinimo taškų';
              startSealLoop();
            }
          }
        } else {
          const trackX = w * 0.12;
          const trackW = w * 0.76;
          const zone = sealZones[seals];
          if (zone == null) return;
          const zx = trackX + trackW * (zone / 100);
          const inMarker = marker >= zone - 8 && marker <= zone + 8;
          if (inMarker && Math.hypot(x - zx, y - h * 0.73) < 28) {
            seals += 1;
            sfx('seal');
            status.textContent = `Užlydinta ${seals}/3`;
            if (seals >= 3) winHooks(hooks, { score: 86 });
          } else if (!inMarker) {
            sfx('fail');
            if (window.MgFx) MgFx.shake(0.85);
          }
        }
      };

      function startSealLoop() {
        runLoop(() => {
          marker += dir;
          if (marker >= 94) dir = -2.5;
          if (marker <= 6) dir = 2.5;
          const ctx = canvas.getContext('2d');
          const r = canvas.parentElement.getBoundingClientRect();
          drawSealScene(ctx, r.width, r.height);
        });
      }
    });
  }

  return { runCook, runFold, cleanup };
})();
