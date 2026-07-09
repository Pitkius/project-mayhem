/**
 * Kokainas — premium Canvas minigame (derlius + plovimas + blokas).
 * Naudoja esamą scheduleResult flow; nekeičia serverio logikos.
 */
window.MgCocaine = (() => {
  const ASSETS = {
    gloves: 'icons/gloves_item.png',
    scissors: 'icons/trimming_scissors.png',
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
    root.className = 'mg-cocaine-root mg-scene-cocaine';
    schBoard.appendChild(root);
    return root;
  }

  function makeStage(parent) {
    const wrap = document.createElement('div');
    wrap.className = 'mg-cocaine-stage-wrap';
    const canvas = document.createElement('canvas');
    canvas.className = 'mg-cocaine-canvas';
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

  function createDust(count) {
    return Array.from({ length: count }, () => ({
      x: Math.random(),
      y: Math.random(),
      vx: (Math.random() - 0.5) * 0.001,
      vy: -0.0003 - Math.random() * 0.0008,
      life: 0.4 + Math.random() * 0.5,
      size: 1 + Math.random() * 2.5,
    }));
  }

  function tickDust(ctx, parts, w, h, intensity) {
    parts.forEach((p) => {
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 0.003 * intensity;
      if (p.life <= 0) {
        p.x = Math.random();
        p.y = 0.65;
        p.life = 0.5 + Math.random() * 0.4;
      }
      const px = p.x * w;
      const py = p.y * h;
      const g = ctx.createRadialGradient(px, py, 0, px, py, p.size * 2);
      g.addColorStop(0, `rgba(248, 250, 252, ${p.life * 0.35 * intensity})`);
      g.addColorStop(1, 'rgba(226, 232, 240, 0)');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(px, py, p.size * 2, 0, Math.PI * 2);
      ctx.fill();
    });
  }

  function drawLuxLab(ctx, w, h) {
    const grd = ctx.createLinearGradient(0, 0, 0, h);
    grd.addColorStop(0, '#0a0e14');
    grd.addColorStop(0.5, '#101820');
    grd.addColorStop(1, '#080c10');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, w, h);

    const sweep = ctx.createLinearGradient(0, h * 0.1, w, h * 0.3);
    sweep.addColorStop(0, 'rgba(255,255,255,0)');
    sweep.addColorStop(0.5, 'rgba(255,255,255,0.06)');
    sweep.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = sweep;
    ctx.fillRect(0, 0, w, h * 0.45);

    ctx.fillStyle = '#1a1510';
    ctx.fillRect(0, h * 0.82, w, h * 0.18);
  }

  function drawJungle(ctx, w, h) {
    const grd = ctx.createLinearGradient(0, 0, 0, h);
    grd.addColorStop(0, '#061208');
    grd.addColorStop(0.6, '#0a1a0e');
    grd.addColorStop(1, '#142018');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, w, h);
    for (let i = 0; i < 5; i += 1) {
      const tx = w * (0.08 + i * 0.18);
      ctx.fillStyle = 'rgba(20, 60, 35, 0.4)';
      ctx.beginPath();
      ctx.moveTo(tx, h);
      ctx.lineTo(tx + 25, h * (0.35 + (i % 2) * 0.1));
      ctx.lineTo(tx + 50, h);
      ctx.fill();
    }
  }

  function drawCocaLeaf(ctx, cx, cy, scale, rot, alpha) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(rot);
    ctx.globalAlpha = alpha;
    const g = ctx.createLinearGradient(-20 * scale, 0, 20 * scale, 0);
    g.addColorStop(0, '#166534');
    g.addColorStop(0.5, '#22c55e');
    g.addColorStop(1, '#15803d');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(0, -22 * scale);
    ctx.quadraticCurveTo(28 * scale, 0, 0, 22 * scale);
    ctx.quadraticCurveTo(-28 * scale, 0, 0, -22 * scale);
    ctx.fill();
    ctx.strokeStyle = 'rgba(187, 247, 208, 0.4)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, -18 * scale);
    ctx.lineTo(0, 18 * scale);
    ctx.stroke();
    ctx.restore();
  }

  function drawBranch(ctx, cx, cy, w) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.strokeStyle = '#3d2817';
    ctx.lineWidth = 8;
    ctx.beginPath();
    ctx.moveTo(-w * 0.4, 20);
    ctx.quadraticCurveTo(0, -10, w * 0.4, 15);
    ctx.stroke();
    ctx.restore();
  }

  function drawWashTub(ctx, cx, cy, scale, fillLevel, bubbles) {
    ctx.save();
    ctx.translate(cx, cy);
    const tw = 120 * scale;
    const th = 50 * scale;
    ctx.strokeStyle = 'rgba(226, 232, 240, 0.45)';
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(-tw / 2, -th / 2);
    ctx.lineTo(-tw / 2 - 8, th / 2);
    ctx.lineTo(tw / 2 + 8, th / 2);
    ctx.lineTo(tw / 2, -th / 2);
    ctx.closePath();
    ctx.stroke();
    const lg = ctx.createLinearGradient(0, th / 2, 0, -th / 2);
    lg.addColorStop(0, `rgba(148, 163, 184, ${0.35 + fillLevel * 0.3})`);
    lg.addColorStop(1, `rgba(226, 232, 240, ${0.15 + fillLevel * 0.2})`);
    ctx.fillStyle = lg;
    ctx.fillRect(-tw / 2 + 4, -th / 2 + fillLevel * th * 0.15, tw - 8, th / 2 + fillLevel * th * 0.35);
    bubbles.forEach((b) => {
      ctx.fillStyle = `rgba(248, 250, 252, ${b.life * 0.5})`;
      ctx.beginPath();
      ctx.arc(b.x * tw, -th / 4 + b.y * th, b.r, 0, Math.PI * 2);
      ctx.fill();
    });
    ctx.restore();
  }

  function drawRingGauge(ctx, cx, cy, r, needle, zoneStart, zoneSweep, holdPct, label) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.strokeStyle = 'rgba(15, 23, 42, 0.92)';
    ctx.lineWidth = 14;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.stroke();
    ctx.strokeStyle = 'rgba(34, 197, 94, 0.85)';
    ctx.beginPath();
    ctx.arc(0, 0, r, zoneStart, zoneStart + zoneSweep);
    ctx.stroke();
    const arc = -Math.PI * 0.75 + (needle / 100) * Math.PI * 1.5;
    ctx.strokeStyle = '#f8fafc';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(Math.cos(arc) * (r - 8), Math.sin(arc) * (r - 8));
    ctx.stroke();
    ctx.fillStyle = 'rgba(226, 232, 240, 0.18)';
    ctx.beginPath();
    ctx.arc(0, 0, r * 0.55, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#f1f5f9';
    ctx.font = 'bold 13px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(`${Math.round(holdPct)}%`, 0, 5);
    if (label) {
      ctx.font = '10px system-ui';
      ctx.fillStyle = 'rgba(226, 232, 240, 0.65)';
      ctx.fillText(label, 0, r + 18);
    }
    ctx.restore();
  }

  function drawGaugeBar(ctx, x, y, w, needle, zoneL, zoneW) {
    ctx.fillStyle = 'rgba(15, 23, 42, 0.9)';
    ctx.fillRect(x, y, w, 10);
    ctx.fillStyle = 'rgba(34, 197, 94, 0.6)';
    ctx.fillRect(x + w * (zoneL / 100), y, w * (zoneW / 100), 10);
    const nx = x + w * (needle / 100);
    ctx.fillStyle = '#f8fafc';
    ctx.beginPath();
    ctx.moveTo(nx, y - 5);
    ctx.lineTo(nx + 5, y + 14);
    ctx.lineTo(nx - 5, y + 14);
    ctx.closePath();
    ctx.fill();
  }

  function drawBrick(ctx, cx, cy, scale, foilWrap) {
    ctx.save();
    ctx.translate(cx, cy);
    const bw = 90 * scale;
    const bh = 40 * scale;
    const g = ctx.createLinearGradient(-bw / 2, 0, bw / 2, 0);
    g.addColorStop(0, '#d4d4d8');
    g.addColorStop(0.5, '#fafafa');
    g.addColorStop(1, '#a1a1aa');
    ctx.fillStyle = g;
    ctx.fillRect(-bw / 2, -bh / 2, bw, bh);
    ctx.strokeStyle = 'rgba(255,255,255,0.5)';
    ctx.strokeRect(-bw / 2, -bh / 2, bw, bh);
    if (foilWrap > 0) {
      ctx.strokeStyle = `rgba(226, 232, 240, ${0.4 + foilWrap * 0.2})`;
      ctx.lineWidth = 2;
      for (let i = 0; i < foilWrap; i += 1) {
        ctx.strokeRect(-bw / 2 - 4 - i * 2, -bh / 2 - 4 - i * 2, bw + 8 + i * 4, bh + 8 + i * 4);
      }
    }
    ctx.restore();
  }

  function drawPress(ctx, cx, cy, scale, plunge) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.fillStyle = '#334155';
    ctx.fillRect(-50 * scale, 30 * scale, 100 * scale, 25 * scale);
    const py = -20 * scale + plunge * 35 * scale;
    ctx.fillStyle = '#64748b';
    ctx.fillRect(-18 * scale, py, 36 * scale, 50 * scale);
    drawBrick(ctx, 0, 55 * scale, 0.85, 0);
    ctx.restore();
  }

  function addStatus(parent, text) {
    const s = document.createElement('p');
    s.className = 'mg-cocaine-status';
    s.textContent = text;
    parent.appendChild(s);
    return s;
  }

  function addBtn(parent, text, cls, onClick) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `mg-cocaine-btn mg-cocaine-btn--${cls || 'ghost'}`;
    b.textContent = text;
    if (onClick) b.onclick = onClick;
    parent.appendChild(b);
    return b;
  }

  function failHooks(hooks) {
    sfx('fail');
    if (window.MgFx) MgFx.shake(1.1);
    cleanup();
    hooks.onFail();
  }

  function winHooks(hooks, extra) {
    sfx('success');
    if (window.MgFx) MgFx.flash('rgba(248, 250, 252, 0.3)');
    cleanup();
    hooks.onWin(extra);
  }

  function armTimeout(ms, hooks) {
    const t = setTimeout(() => failHooks(hooks), ms);
    cleanups.push(() => clearTimeout(t));
  }

  /** coca_harvest — lapų nuėmimas nuo šakos */
  function runHarvest(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      const need = data.steps || 5;
      let stripped = 0;
      const positions = [0.18, 0.32, 0.46, 0.6, 0.74, 0.88].slice(0, need)
        .map((x) => ({ x, y: 0.42 + (Math.random() - 0.5) * 0.08, done: false }));

      const { canvas } = makeStage(root);
      const status = addStatus(root, 'Nuimk lapus nuo šakos');
      hooks.setStep(1, 1, 'Nuimk lapus nuo šakos');
      armTimeout(50000, hooks);

      function draw(ctx, w, h) {
        drawJungle(ctx, w, h);
        drawBranch(ctx, w * 0.5, h * 0.48, w * 0.7);
        positions.forEach((p) => {
          if (!p.done) {
            drawCocaLeaf(ctx, w * p.x, h * p.y, 1.1, 0.2, 1);
            ctx.strokeStyle = 'rgba(248, 250, 252, 0.35)';
            ctx.setLineDash([4, 3]);
            ctx.beginPath();
            ctx.arc(w * p.x, h * p.y, 28, 0, Math.PI * 2);
            ctx.stroke();
            ctx.setLineDash([]);
          }
        });
        drawImg(ctx, ASSETS.gloves, w * 0.15, h * 0.62, 58, 0, 0.65);
        ctx.fillStyle = 'rgba(226, 232, 240, 0.85)';
        ctx.font = '13px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Nuimta ${stripped}/${need}`, w * 0.5, h * 0.15);
      }

      bindResize(canvas, draw);

      canvas.onclick = (ev) => {
        const { x, y, w, h } = canvasPos(canvas, ev);
        for (let i = 0; i < positions.length; i += 1) {
          const p = positions[i];
          if (p.done) continue;
          if (Math.hypot(x - w * p.x, y - h * p.y) < 30) {
            p.done = true;
            stripped += 1;
            sfx('scrape');
            if (window.MgFx) MgFx.flash('rgba(34, 197, 94, 0.2)');
            if (stripped >= need) winHooks(hooks, { score: 88 });
            else status.textContent = `Nuimta ${stripped}/${need}`;
            return;
          }
        }
      };
    });
  }

  /** cocaine_process — lapų plovimas → tirpalo maišymas */
  function runWash(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      const need = data.steps || 4;
      let phase = 'wash';
      let washed = 0;
      const leaves = Array.from({ length: need }, (_, i) => ({
        x: 0.22 + (i % 2) * 0.35 + Math.random() * 0.1,
        y: 0.28 + Math.floor(i / 2) * 0.12,
        done: false,
        float: Math.random() * Math.PI * 2,
      }));
      const bubbles = Array.from({ length: 8 }, () => ({
        x: Math.random(), y: Math.random(), r: 2 + Math.random() * 3, life: Math.random(),
      }));
      const dust = createDust(16);

      let needle = 10;
      let dir = 1.4;
      let hold = 0;
      const needHold = 45;
      const zoneLeft = 25 + Math.floor(Math.random() * 38);
      const zoneWidth = 22;
      const zoneStart = -Math.PI * 0.75 + (zoneLeft / 100) * Math.PI * 1.5;
      const zoneSweep = (zoneWidth / 100) * Math.PI * 1.5;
      let spaceDown = false;

      const { canvas } = makeStage(root);
      const status = addStatus(root, 'Panardink lapus į cheminį tirpalą');
      hooks.setStep(1, 2, 'Cheminis plovimas');
      armTimeout(70000, hooks);

      function inZone() {
        return needle >= zoneLeft && needle <= zoneLeft + zoneWidth;
      }

      function bindMixKeys() {
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

      function drawWash(ctx, w, h) {
        drawLuxLab(ctx, w, h);
        const fill = washed / need;
        bubbles.forEach((b) => {
          b.y -= 0.008;
          b.life = 0.5 + Math.sin(Date.now() / 200 + b.x * 10) * 0.5;
          if (b.y < 0) b.y = 1;
        });
        drawWashTub(ctx, w * 0.5, h * 0.58, 1.15, fill, bubbles);
        leaves.forEach((lf) => {
          if (lf.done) return;
          const fy = lf.y + Math.sin(lf.float + Date.now() / 400) * 0.02;
          drawCocaLeaf(ctx, w * lf.x, h * fy, 0.85, 0.15, 1);
        });
        tickDust(ctx, dust, w, h, 0.5);
        ctx.fillStyle = 'rgba(226, 232, 240, 0.8)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Panardinta ${washed}/${need}`, w * 0.5, h * 0.78);
      }

      function drawMix(ctx, w, h) {
        drawLuxLab(ctx, w, h);
        drawWashTub(ctx, w * 0.48, h * 0.52, 1.1, 1, bubbles);
        tickDust(ctx, dust, w, h, 0.9);
        const pct = Math.min(100, (hold / needHold) * 100);
        drawRingGauge(ctx, w * 0.78, h * 0.42, Math.min(w, h) * 0.14, needle, zoneStart, zoneSweep, pct, 'Maišymas');
      }

      bindResize(canvas, (ctx, w, h) => {
        if (phase === 'wash') drawWash(ctx, w, h);
        else drawMix(ctx, w, h);
      });

      canvas.onclick = (ev) => {
        if (phase !== 'wash') return;
        const { x, y, w, h } = canvasPos(canvas, ev);
        for (let i = 0; i < leaves.length; i += 1) {
          const lf = leaves[i];
          if (lf.done) continue;
          const fy = lf.y + Math.sin(lf.float + Date.now() / 400) * 0.02;
          if (Math.hypot(x - w * lf.x, y - h * fy) < 28) {
            lf.done = true;
            washed += 1;
            sfx('pour');
            if (washed >= need) {
              phase = 'mix';
              hooks.setStep(2, 2, 'Maišyk tirpalą — SPACE žalioje zonoje');
              status.textContent = 'Laikyk SPACE stabilizuodamas tirpalą';
              bindMixKeys();
              runLoop(() => {
                needle += dir;
                if (needle >= 98) dir = -1.4;
                if (needle <= 2) dir = 1.4;
                if (spaceDown && inZone()) {
                  hold += 1;
                  if (hold % 10 === 0) sfx('bubble');
                }
                if (hooks.hint) hooks.hint.textContent = `Maišymas — ${Math.min(100, Math.floor((hold / needHold) * 100))}%`;
                if (hold >= needHold) winHooks(hooks, { score: 86 });
                const ctx = canvas.getContext('2d');
                const r = canvas.parentElement.getBoundingClientRect();
                drawMix(ctx, r.width, r.height);
              });
            } else {
              status.textContent = `Panardinta ${washed}/${need}`;
            }
            return;
          }
        }
      };
    });
  }

  /** cocaine_pack — presas → folija → sandarinimas */
  function runBrick(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      let phase = 'press';
      let hits = 0;
      const hitNeed = 4;
      let needle = 8;
      let nDir = 2.2;
      const zoneL = 38;
      const zoneW = 24;
      let plunge = 0;

      let wraps = 0;
      const wrapNeed = 3;
      const wrapPoints = [
        { x: 0.35, y: 0.42 }, { x: 0.65, y: 0.4 }, { x: 0.5, y: 0.55 },
      ];

      let seals = 0;
      const sealNeed = 3;
      let marker = 10;
      let mDir = 2.5;
      const sealZones = [22, 50, 78];

      const dust = createDust(20);
      const { canvas } = makeStage(root);
      const hud = document.createElement('div');
      hud.className = 'mg-cocaine-hud';
      root.appendChild(hud);
      const status = addStatus(root, 'Spausk kai žymeklis žalioje zonoje');
      const pressBtn = addBtn(hud, 'Presuoti', 'primary', null);

      hooks.setStep(1, 3, 'Presuok į bloką');
      armTimeout(75000, hooks);

      function drawPressPhase(ctx, w, h) {
        drawLuxLab(ctx, w, h);
        drawPress(ctx, w * 0.5, h * 0.48, 1.1, plunge);
        tickDust(ctx, dust, w, h, 0.7);
        drawGaugeBar(ctx, w * 0.12, h * 0.78, w * 0.76, needle, zoneL, zoneW);
        ctx.fillStyle = 'rgba(226, 232, 240, 0.8)';
        ctx.font = '11px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Presavimai ${hits}/${hitNeed}`, w * 0.5, h * 0.72);
      }

      function drawFoilPhase(ctx, w, h) {
        drawLuxLab(ctx, w, h);
        drawBrick(ctx, w * 0.5, h * 0.48, 1.2, wraps);
        wrapPoints.forEach((pt, i) => {
          if (i < wraps) return;
          const px = w * pt.x;
          const py = h * pt.y;
          const active = i === wraps;
          ctx.beginPath();
          ctx.arc(px, py, active ? 16 : 12, 0, Math.PI * 2);
          ctx.strokeStyle = active ? 'rgba(248, 250, 252, 0.9)' : 'rgba(148, 163, 184, 0.35)';
          ctx.lineWidth = active ? 2.5 : 1;
          ctx.setLineDash(active ? [] : [4, 3]);
          ctx.stroke();
          ctx.setLineDash([]);
        });
        ctx.fillStyle = 'rgba(226, 232, 240, 0.75)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText('Apvyniok plėvele — spausk žymes iš eilės', w * 0.5, h * 0.2);
      }

      function drawSealPhase(ctx, w, h) {
        drawLuxLab(ctx, w, h);
        drawBrick(ctx, w * 0.5, h * 0.45, 1.15, wrapNeed);
        drawGaugeBar(ctx, w * 0.12, h * 0.72, w * 0.76, marker, 0, 0);
        sealZones.forEach((z, i) => {
          const zx = w * 0.12 + w * 0.76 * (z / 100);
          ctx.beginPath();
          ctx.arc(zx, h * 0.72 + 5, i < seals ? 9 : 11, 0, Math.PI * 2);
          ctx.fillStyle = i < seals ? 'rgba(226, 232, 240, 0.9)' : 'rgba(148, 163, 184, 0.25)';
          ctx.fill();
          ctx.strokeStyle = '#f8fafc';
          ctx.stroke();
        });
        ctx.fillStyle = 'rgba(226, 232, 240, 0.8)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Užlydinimas ${seals}/${sealNeed}`, w * 0.5, h * 0.58);
      }

      bindResize(canvas, (ctx, w, h) => {
        if (phase === 'press') drawPressPhase(ctx, w, h);
        else if (phase === 'foil') drawFoilPhase(ctx, w, h);
        else drawSealPhase(ctx, w, h);
      });

      pressBtn.onclick = () => {
        if (phase !== 'press') return;
        const ok = needle >= zoneL && needle <= zoneL + zoneW;
        if (!ok) {
          failHooks(hooks);
          return;
        }
        hits += 1;
        plunge = 1;
        sfx('press');
        if (window.MgFx) MgFx.shake(0.7);
        setTimeout(() => { plunge = 0; }, 200);
        if (hits >= hitNeed) {
          phase = 'foil';
          pressBtn.style.display = 'none';
          stopLoop();
          hooks.setStep(2, 3, 'Apvyniok plėvele');
          status.textContent = 'Spausk folijos taškus iš eilės';
        } else {
          status.textContent = `Presavimai ${hits}/${hitNeed}`;
        }
      };

      runLoop(() => {
        if (phase === 'press') {
          needle += nDir;
          if (needle >= 94) nDir = -2.2;
          if (needle <= 4) nDir = 2.2;
          plunge = Math.max(0, plunge - 0.06);
          const ctx = canvas.getContext('2d');
          const r = canvas.parentElement.getBoundingClientRect();
          drawPressPhase(ctx, r.width, r.height);
        } else if (phase === 'seal') {
          marker += mDir;
          if (marker >= 94) mDir = -2.5;
          if (marker <= 6) mDir = 2.5;
          const ctx = canvas.getContext('2d');
          const r = canvas.parentElement.getBoundingClientRect();
          drawSealPhase(ctx, r.width, r.height);
        }
      });

      canvas.onclick = (ev) => {
        const { x, y, w, h } = canvasPos(canvas, ev);
        if (phase === 'foil') {
          const pt = wrapPoints[wraps];
          if (!pt) return;
          if (Math.hypot(x - w * pt.x, y - h * pt.y) < 24) {
            wraps += 1;
            sfx('scrape');
            if (wraps >= wrapNeed) {
              phase = 'seal';
              hooks.setStep(3, 3, 'Užlydink siuntą');
              status.textContent = 'Spausk kai žymeklis ant užlydinimo taško';
            } else {
              status.textContent = `Apvyniota ${wraps}/${wrapNeed}`;
            }
          }
        } else if (phase === 'seal') {
          const zone = sealZones[seals];
          if (zone == null) return;
          const zx = w * 0.12 + w * 0.76 * (zone / 100);
          const inMarker = marker >= zone - 8 && marker <= zone + 8;
          if (inMarker && Math.hypot(x - zx, y - h * 0.77) < 28) {
            seals += 1;
            sfx('seal');
            if (seals >= sealNeed) winHooks(hooks, { score: 91 });
            else status.textContent = `Užlydinta ${seals}/${sealNeed}`;
          } else if (!inMarker) {
            sfx('fail');
            if (window.MgFx) MgFx.shake(0.85);
          }
        }
      };
    });
  }

  return { runHarvest, runWash, runBrick, cleanup };
})();
