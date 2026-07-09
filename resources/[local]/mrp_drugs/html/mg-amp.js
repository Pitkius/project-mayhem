/**
 * Amfetaminas — premium Canvas minigame (maišelio antspaudas).
 * amp_process naudoja atskirą amp_lab quiz — čia tik amp_pack / amp_stamp.
 */
window.MgAmp = (() => {
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
    root.className = 'mg-amp-root mg-scene-amp';
    schBoard.appendChild(root);
    return root;
  }

  function makeStage(parent) {
    const wrap = document.createElement('div');
    wrap.className = 'mg-amp-stage-wrap';
    const canvas = document.createElement('canvas');
    canvas.className = 'mg-amp-canvas';
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

  function createSparks(count) {
    return Array.from({ length: count }, () => ({
      x: Math.random(),
      y: Math.random(),
      vx: (Math.random() - 0.5) * 0.002,
      vy: -0.001 - Math.random() * 0.002,
      life: 0.3 + Math.random() * 0.5,
      size: 1.5 + Math.random() * 3,
    }));
  }

  function tickSparks(ctx, parts, w, h, intensity) {
    parts.forEach((p) => {
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 0.005 * intensity;
      if (p.life <= 0) {
        p.x = 0.4 + Math.random() * 0.2;
        p.y = 0.6;
        p.life = 0.4 + Math.random() * 0.4;
      }
      const px = p.x * w;
      const py = p.y * h;
      const g = ctx.createRadialGradient(px, py, 0, px, py, p.size * 2.5);
      g.addColorStop(0, `rgba(253, 224, 71, ${p.life * 0.5 * intensity})`);
      g.addColorStop(0.5, `rgba(250, 204, 21, ${p.life * 0.3 * intensity})`);
      g.addColorStop(1, 'rgba(253, 224, 71, 0)');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(px, py, p.size * 2.5, 0, Math.PI * 2);
      ctx.fill();
    });
  }

  function drawLabBench(ctx, w, h) {
    const grd = ctx.createLinearGradient(0, 0, 0, h);
    grd.addColorStop(0, '#141008');
    grd.addColorStop(0.5, '#1c1608');
    grd.addColorStop(1, '#100c04');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, w, h);

    const glow = ctx.createRadialGradient(w * 0.5, h * 0.15, 0, w * 0.5, h * 0.3, w * 0.45);
    glow.addColorStop(0, 'rgba(253, 224, 71, 0.14)');
    glow.addColorStop(1, 'rgba(253, 224, 71, 0)');
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, w, h * 0.5);

    ctx.fillStyle = '#1a1408';
    ctx.fillRect(0, h * 0.8, w, h * 0.2);
    drawImg(ctx, ASSETS.scale, w * 0.88, h * 0.86, Math.min(w, h) * 0.11);
    drawImg(ctx, ASSETS.gloves, w * 0.1, h * 0.84, Math.min(w, h) * 0.09, -0.2);
  }

  function drawMylarBag(ctx, cx, cy, scale, sealed, stampCount) {
    ctx.save();
    ctx.translate(cx, cy);
    const bw = 100 * scale;
    const bh = 120 * scale;
    const g = ctx.createLinearGradient(-bw / 2, 0, bw / 2, 0);
    g.addColorStop(0, '#94a3b8');
    g.addColorStop(0.3, '#e2e8f0');
    g.addColorStop(0.7, '#f8fafc');
    g.addColorStop(1, '#94a3b8');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.roundRect(-bw / 2, -bh / 2, bw, bh, 8);
    ctx.fill();
    ctx.strokeStyle = sealed ? 'rgba(253, 224, 71, 0.7)' : 'rgba(148, 163, 184, 0.5)';
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.fillStyle = 'rgba(234, 179, 8, 0.35)';
    ctx.fillRect(-bw / 2 + 8, -bh / 2 + 20, bw - 16, bh - 40);
    if (stampCount > 0) {
      for (let i = 0; i < stampCount; i += 1) {
        ctx.fillStyle = 'rgba(202, 138, 4, 0.85)';
        ctx.font = `bold ${12 * scale}px system-ui`;
        ctx.textAlign = 'center';
        ctx.fillText('⚡', (i - 0.5) * 24 * scale, 8);
      }
    }
    ctx.restore();
  }

  function drawHeatSealer(ctx, cx, cy, scale, heat) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.fillStyle = '#334155';
    ctx.fillRect(-30 * scale, -8 * scale, 60 * scale, 16 * scale);
    const hg = ctx.createRadialGradient(0, 0, 0, 0, 0, 20 * scale);
    hg.addColorStop(0, `rgba(253, 224, 71, ${0.3 + heat * 0.5})`);
    hg.addColorStop(1, 'rgba(250, 204, 21, 0)');
    ctx.fillStyle = hg;
    ctx.fillRect(-35 * scale, -12 * scale, 70 * scale, 24 * scale);
    ctx.restore();
  }

  function drawStampPress(ctx, cx, cy, scale, plunge, flash) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.fillStyle = '#1e293b';
    ctx.fillRect(-55 * scale, 35 * scale, 110 * scale, 22 * scale);
    const py = -15 * scale + plunge * 40 * scale;
    ctx.fillStyle = '#475569';
    ctx.fillRect(-22 * scale, py, 44 * scale, 55 * scale);
    ctx.fillStyle = '#64748b';
    ctx.fillRect(-28 * scale, py - 12 * scale, 56 * scale, 14 * scale);
    if (flash > 0) {
      const fg = ctx.createRadialGradient(0, py + 50 * scale, 0, 0, py + 50 * scale, 40 * scale);
      fg.addColorStop(0, `rgba(253, 224, 71, ${flash * 0.6})`);
      fg.addColorStop(1, 'rgba(253, 224, 71, 0)');
      ctx.fillStyle = fg;
      ctx.beginPath();
      ctx.arc(0, py + 50 * scale, 40 * scale, 0, Math.PI * 2);
      ctx.fill();
    }
    drawMylarBag(ctx, 0, 70 * scale, 0.75, true, plunge > 0.5 ? 1 : 0);
    ctx.restore();
  }

  function drawGaugeBar(ctx, x, y, w, needle, zoneL, zoneW) {
    ctx.fillStyle = 'rgba(28, 20, 4, 0.9)';
    ctx.fillRect(x, y, w, 10);
    ctx.fillStyle = 'rgba(34, 197, 94, 0.6)';
    ctx.fillRect(x + w * (zoneL / 100), y, w * (zoneW / 100), 10);
    const nx = x + w * (needle / 100);
    ctx.fillStyle = '#fef9c3';
    ctx.beginPath();
    ctx.moveTo(nx, y - 5);
    ctx.lineTo(nx + 5, y + 14);
    ctx.lineTo(nx - 5, y + 14);
    ctx.closePath();
    ctx.fill();
  }

  function drawScanLine(ctx, w, h, scanY, marks, done) {
    ctx.strokeStyle = 'rgba(253, 224, 71, 0.85)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(w * 0.2, scanY);
    ctx.lineTo(w * 0.8, scanY);
    ctx.stroke();
    marks.forEach((m, i) => {
      const mx = w * m.x;
      const my = h * m.y;
      if (done[i]) {
        ctx.fillStyle = 'rgba(34, 197, 94, 0.8)';
        ctx.beginPath();
        ctx.arc(mx, my, 12, 0, Math.PI * 2);
        ctx.fill();
      } else {
        ctx.strokeStyle = 'rgba(253, 224, 71, 0.5)';
        ctx.beginPath();
        ctx.arc(mx, my, 14, 0, Math.PI * 2);
        ctx.stroke();
      }
    });
  }

  function addStatus(parent, text) {
    const s = document.createElement('p');
    s.className = 'mg-amp-status';
    s.textContent = text;
    parent.appendChild(s);
    return s;
  }

  function addBtn(parent, text, cls, onClick) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `mg-amp-btn mg-amp-btn--${cls || 'ghost'}`;
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
    if (window.MgFx) MgFx.flash('rgba(253, 224, 71, 0.35)');
    cleanup();
    hooks.onWin(extra);
  }

  function armTimeout(ms, hooks) {
    const t = setTimeout(() => failHooks(hooks), ms);
    cleanups.push(() => clearTimeout(t));
  }

  /**
   * amp_pack — užlydinimas → antspaudas → kontrolinis ženklas
   */
  function runStamp(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      let phase = 'seal';
      let seals = 0;
      const sealNeed = 2;
      let marker = 10;
      let mDir = 2.4;
      const sealZones = [30, 70];

      let hits = 0;
      const hitNeed = 3;
      let needle = 8;
      let nDir = 2.3;
      const zoneL = 38;
      const zoneW = 24;
      let plunge = 0;
      let stampFlash = 0;

      let scanned = 0;
      const scanNeed = 2;
      const scanMarks = [{ x: 0.38, y: 0.48 }, { x: 0.58, y: 0.52 }];
      const scanDone = [false, false];
      let scanY = 0;
      let scanDir = 1.8;

      const sparks = createSparks(18);
      const { canvas } = makeStage(root);
      const hud = document.createElement('div');
      hud.className = 'mg-amp-hud';
      root.appendChild(hud);
      const status = addStatus(root, 'Užlydink maišelį — spausk kai žymeklis žalioje zonoje');
      const stampBtn = addBtn(hud, 'Antspauduoti', 'primary', null);
      stampBtn.style.display = 'none';

      hooks.setStep(1, 3, 'Užlydink maišelį');
      armTimeout(70000, hooks);

      function drawSeal(ctx, w, h) {
        drawLabBench(ctx, w, h);
        drawMylarBag(ctx, w * 0.5, h * 0.48, 1.1, seals > 0, 0);
        drawHeatSealer(ctx, w * 0.72, h * 0.38, 0.9, seals / sealNeed);
        drawGaugeBar(ctx, w * 0.12, h * 0.75, w * 0.76, marker, 0, 0);
        sealZones.forEach((z, i) => {
          const zx = w * 0.12 + w * 0.76 * (z / 100);
          ctx.beginPath();
          ctx.arc(zx, h * 0.75 + 5, i < seals ? 9 : 11, 0, Math.PI * 2);
          ctx.fillStyle = i < seals ? 'rgba(253, 224, 71, 0.9)' : 'rgba(250, 204, 21, 0.22)';
          ctx.fill();
          ctx.strokeStyle = '#fef9c3';
          ctx.stroke();
        });
        tickSparks(ctx, sparks, w, h, 0.5);
        ctx.fillStyle = 'rgba(254, 240, 138, 0.8)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Užlydinimas ${seals}/${sealNeed}`, w * 0.5, h * 0.62);
      }

      function drawStamp(ctx, w, h) {
        drawLabBench(ctx, w, h);
        drawStampPress(ctx, w * 0.5, h * 0.42, 1.05, plunge, stampFlash);
        tickSparks(ctx, sparks, w, h, 0.8 + hits * 0.1);
        drawGaugeBar(ctx, w * 0.12, h * 0.78, w * 0.76, needle, zoneL, zoneW);
        ctx.fillStyle = 'rgba(254, 240, 138, 0.8)';
        ctx.font = '11px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Antspaudai ${hits}/${hitNeed}`, w * 0.5, h * 0.72);
      }

      function drawScan(ctx, w, h) {
        drawLabBench(ctx, w, h);
        drawMylarBag(ctx, w * 0.5, h * 0.48, 1.15, true, scanned);
        drawScanLine(ctx, w, h, scanY, scanMarks, scanDone);
        tickSparks(ctx, sparks, w, h, 0.6);
        ctx.fillStyle = 'rgba(254, 240, 138, 0.8)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText('Kontrolinis skenavimas — spausk ant ženklo kai linija praeina', w * 0.5, h * 0.18);
        ctx.fillText(`${scanned}/${scanNeed}`, w * 0.5, h * 0.68);
      }

      function drawAll(ctx, w, h) {
        if (phase === 'seal') drawSeal(ctx, w, h);
        else if (phase === 'stamp') drawStamp(ctx, w, h);
        else drawScan(ctx, w, h);
      }

      bindResize(canvas, drawAll);

      stampBtn.onclick = () => {
        if (phase !== 'stamp') return;
        const ok = needle >= zoneL && needle <= zoneL + zoneW;
        if (!ok) {
          failHooks(hooks);
          return;
        }
        hits += 1;
        plunge = 1;
        stampFlash = 1;
        sfx('press');
        if (window.MgFx) MgFx.shake(0.65);
        setTimeout(() => { plunge = 0; stampFlash = 0; }, 220);
        if (hits >= hitNeed) {
          phase = 'scan';
          scanY = canvas.parentElement.getBoundingClientRect().height * 0.35;
          stampBtn.style.display = 'none';
          hooks.setStep(3, 3, 'Kontrolinis ženklas');
          status.textContent = 'Suskenuok kokybės ženklus';
        } else {
          status.textContent = `Antspaudai ${hits}/${hitNeed}`;
        }
      };

      runLoop(() => {
        const r = canvas.parentElement.getBoundingClientRect();
        const ctx = canvas.getContext('2d');
        if (phase === 'seal') {
          marker += mDir;
          if (marker >= 94) mDir = -2.4;
          if (marker <= 6) mDir = 2.4;
        } else if (phase === 'stamp') {
          needle += nDir;
          if (needle >= 94) nDir = -2.3;
          if (needle <= 4) nDir = 2.3;
          plunge = Math.max(0, plunge - 0.05);
          stampFlash = Math.max(0, stampFlash - 0.04);
        } else if (phase === 'scan') {
          scanY += scanDir;
          if (scanY > r.height * 0.65 || scanY < r.height * 0.32) scanDir *= -1;
        }
        drawAll(ctx, r.width, r.height);
      });

      canvas.onclick = (ev) => {
        const { x, y, w, h } = canvasPos(canvas, ev);
        if (phase === 'seal') {
          const zone = sealZones[seals];
          if (zone == null) return;
          const zx = w * 0.12 + w * 0.76 * (zone / 100);
          const inMarker = marker >= zone - 8 && marker <= zone + 8;
          if (inMarker && Math.hypot(x - zx, y - h * 0.8) < 28) {
            seals += 1;
            sfx('seal');
            if (seals >= sealNeed) {
              phase = 'stamp';
              stampBtn.style.display = '';
              hooks.setStep(2, 3, 'Antspauduok');
              status.textContent = 'Spausk kai žymeklis žalioje zonoje';
            } else {
              status.textContent = `Užlydinta ${seals}/${sealNeed}`;
            }
          } else if (!inMarker) {
            sfx('fail');
            if (window.MgFx) MgFx.shake(0.8);
          }
        } else if (phase === 'scan') {
          const idx = scanned;
          if (idx >= scanNeed) return;
          const m = scanMarks[idx];
          const mx = w * m.x;
          const my = h * m.y;
          const lineNear = Math.abs(scanY - my) < 22;
          if (lineNear && Math.hypot(x - mx, y - my) < 28) {
            scanDone[idx] = true;
            scanned += 1;
            sfx('click');
            if (window.MgFx) MgFx.flash('rgba(253, 224, 71, 0.25)');
            if (scanned >= scanNeed) winHooks(hooks, { score: 90 });
          } else if (!lineNear) {
            sfx('fail');
            status.textContent = 'Lauk kol skenavimo linija pasiekia ženklą';
          }
        }
      };
    });
  }

  return { runStamp, cleanup };
})();
