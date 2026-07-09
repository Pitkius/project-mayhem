/**
 * Tabletės — premium Canvas minigame (presavimas + blisteris).
 * Naudoja esamą scheduleResult flow; nekeičia serverio logikos.
 */
window.MgPills = (() => {
  const ASSETS = {
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
    root.className = 'mg-pills-root mg-scene-pills';
    schBoard.appendChild(root);
    return root;
  }

  function makeStage(parent) {
    const wrap = document.createElement('div');
    wrap.className = 'mg-pills-stage-wrap';
    const canvas = document.createElement('canvas');
    canvas.className = 'mg-pills-canvas';
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
      vx: (Math.random() - 0.5) * 0.0008,
      vy: -0.0004 - Math.random() * 0.0006,
      life: 0.4 + Math.random() * 0.5,
      size: 1.5 + Math.random() * 3,
    }));
  }

  function drawPharmaLab(ctx, w, h) {
    const grd = ctx.createLinearGradient(0, 0, 0, h);
    grd.addColorStop(0, '#1a0c06');
    grd.addColorStop(0.5, '#241008');
    grd.addColorStop(1, '#120804');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, w, h);

    const lamp = ctx.createRadialGradient(w * 0.5, h * 0.1, 0, w * 0.5, h * 0.22, w * 0.5);
    lamp.addColorStop(0, 'rgba(251, 146, 60, 0.16)');
    lamp.addColorStop(1, 'rgba(251, 146, 60, 0)');
    ctx.fillStyle = lamp;
    ctx.fillRect(0, 0, w, h * 0.5);

    ctx.fillStyle = '#1c1208';
    ctx.fillRect(0, h * 0.8, w, h * 0.2);
    ctx.strokeStyle = 'rgba(251, 146, 60, 0.06)';
    for (let i = 0; i < 8; i += 1) {
      const y = h * 0.82 + i * 3;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }
  }

  function tickDust(ctx, parts, w, h, intensity) {
    parts.forEach((p) => {
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 0.004 * intensity;
      if (p.life <= 0) {
        p.x = 0.4 + Math.random() * 0.2;
        p.y = 0.7;
        p.life = 0.5 + Math.random() * 0.4;
      }
      const px = p.x * w;
      const py = p.y * h;
      const g = ctx.createRadialGradient(px, py, 0, px, py, p.size * 2);
      g.addColorStop(0, `rgba(251, 146, 60, ${p.life * 0.3 * intensity})`);
      g.addColorStop(1, 'rgba(251, 146, 60, 0)');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(px, py, p.size * 2, 0, Math.PI * 2);
      ctx.fill();
    });
  }

  function drawPill(ctx, cx, cy, rw, rh, colorTop, colorBot, defect) {
    ctx.save();
    ctx.translate(cx, cy);
    const g = ctx.createLinearGradient(-rw, -rh, rw, rh);
    g.addColorStop(0, defect ? '#fca5a5' : colorTop);
    g.addColorStop(1, defect ? '#f87171' : colorBot);
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.ellipse(0, 0, rw, rh, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.35)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(-rw * 0.85, 0);
    ctx.lineTo(rw * 0.85, 0);
    ctx.stroke();
    if (defect) {
      ctx.strokeStyle = 'rgba(185, 28, 28, 0.8)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(-rw * 0.4, -rh * 0.4);
      ctx.lineTo(rw * 0.4, rh * 0.4);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawPress(ctx, cx, cy, scale, plunge) {
    ctx.save();
    ctx.translate(cx, cy);
    const bw = 90 * scale;
    const bh = 70 * scale;

    ctx.fillStyle = '#334155';
    ctx.fillRect(-bw * 0.45, bh * 0.15, bw * 0.9, bh * 0.35);
    ctx.fillStyle = '#475569';
    ctx.fillRect(-bw * 0.35, -bh * 0.35, bw * 0.7, bh * 0.2);

    const py = -bh * 0.15 + plunge * bh * 0.35;
    ctx.fillStyle = '#64748b';
    ctx.fillRect(-bw * 0.12, py, bw * 0.24, bh * 0.45);

    ctx.fillStyle = '#1e293b';
    ctx.fillRect(-bw * 0.5, bh * 0.42, bw, bh * 0.12);

    const dieY = bh * 0.28;
    for (let i = -1; i <= 1; i += 1) {
      drawPill(ctx, i * 22 * scale, dieY, 10 * scale, 6 * scale, '#fef3c7', '#fdba74', false);
    }
    ctx.restore();
  }

  function drawHopper(ctx, cx, cy, scale, level) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.strokeStyle = 'rgba(254, 215, 170, 0.5)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-20 * scale, -30 * scale);
    ctx.lineTo(-28 * scale, 20 * scale);
    ctx.lineTo(28 * scale, 20 * scale);
    ctx.lineTo(20 * scale, -30 * scale);
    ctx.closePath();
    ctx.stroke();
    ctx.fillStyle = `rgba(251, 146, 60, ${0.3 + level * 0.4})`;
    ctx.fillRect(-24 * scale, -10 * scale, 48 * scale, 28 * scale * level);
    ctx.restore();
  }

  function drawGaugeBar(ctx, x, y, w, needle, zoneL, zoneW) {
    ctx.fillStyle = 'rgba(28, 12, 4, 0.9)';
    ctx.fillRect(x, y, w, 10);
    ctx.fillStyle = 'rgba(34, 197, 94, 0.6)';
    ctx.fillRect(x + w * (zoneL / 100), y, w * (zoneW / 100), 10);
    const nx = x + w * (needle / 100);
    ctx.fillStyle = '#fff7ed';
    ctx.beginPath();
    ctx.moveTo(nx, y - 5);
    ctx.lineTo(nx + 5, y + 14);
    ctx.lineTo(nx - 5, y + 14);
    ctx.closePath();
    ctx.fill();
  }

  function drawBlister(ctx, cx, cy, w, h, slots, filled, activeIdx) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.fillStyle = 'rgba(226, 232, 240, 0.15)';
    ctx.strokeStyle = 'rgba(251, 146, 60, 0.45)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.roundRect(-w / 2, -h / 2, w, h, 10);
    ctx.fill();
    ctx.stroke();

    const cols = slots.length <= 4 ? slots.length : 3;
    const rows = Math.ceil(slots.length / cols);
    const cellW = (w - 24) / cols;
    const cellH = (h - 20) / rows;

    slots.forEach((slot, i) => {
      const col = i % cols;
      const row = Math.floor(i / cols);
      const px = -w / 2 + 12 + cellW * col + cellW / 2;
      const py = -h / 2 + 10 + cellH * row + cellH / 2;
      slot.px = px;
      slot.py = py;

      ctx.beginPath();
      ctx.ellipse(px, py, cellW * 0.32, cellH * 0.35, 0, 0, Math.PI * 2);
      ctx.fillStyle = slot.done ? 'rgba(251, 146, 60, 0.25)' : 'rgba(15, 8, 4, 0.5)';
      ctx.fill();
      ctx.strokeStyle = i === activeIdx && !slot.done
        ? 'rgba(251, 146, 60, 0.95)'
        : 'rgba(254, 215, 170, 0.35)';
      ctx.lineWidth = i === activeIdx && !slot.done ? 2.5 : 1;
      ctx.stroke();

      if (slot.done) {
        drawPill(ctx, px, py, cellW * 0.22, cellH * 0.18, '#fef3c7', '#fb923c', false);
      }
    });
    ctx.restore();
  }

  function addStatus(parent, text) {
    const s = document.createElement('p');
    s.className = 'mg-pills-status';
    s.textContent = text;
    parent.appendChild(s);
    return s;
  }

  function addBtn(parent, text, cls, onClick) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `mg-pills-btn mg-pills-btn--${cls || 'ghost'}`;
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
    if (window.MgFx) MgFx.flash('rgba(251, 146, 60, 0.35)');
    cleanup();
    hooks.onWin(extra);
  }

  function armTimeout(ms, hooks) {
    const t = setTimeout(() => failHooks(hooks), ms);
    cleanups.push(() => clearTimeout(t));
  }

  /**
   * pills_process — presavimo ritmas → kokybės kontrolė
   */
  function runPress(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      const hitNeed = data.steps || 4;
      let phase = 'press';
      let hits = 0;
      let needle = 8;
      let nDir = 2.2;
      const zoneL = 38;
      const zoneW = 24;
      let plunge = 0;
      let plungeAnim = 0;
      const dust = createDust(14);
      let powderLevel = 0.6;

      let checked = 0;
      const checkNeed = 2;
      const defects = [
        { x: 0.32, y: 0.52, done: false, defect: true },
        { x: 0.68, y: 0.5, done: false, defect: true },
        { x: 0.5, y: 0.58, done: false, defect: false },
        { x: 0.42, y: 0.44, done: false, defect: false },
        { x: 0.58, y: 0.44, done: false, defect: false },
      ];

      const { canvas } = makeStage(root);
      const hud = document.createElement('div');
      hud.className = 'mg-pills-hud';
      root.appendChild(hud);
      const status = addStatus(root, 'Spausk „Presuoti“ kai žymeklis žalioje zonoje');
      const pressBtn = addBtn(hud, 'Presuoti', 'primary', null);

      hooks.setStep(1, 2, 'Presuok tabletes — tikslus ritmas');
      armTimeout(65000, hooks);

      function drawPressPhase(ctx, w, h) {
        drawPharmaLab(ctx, w, h);
        drawHopper(ctx, w * 0.5, h * 0.22, 1, powderLevel);
        drawPress(ctx, w * 0.5, h * 0.52, 1.15, plunge + plungeAnim);
        tickDust(ctx, dust, w, h, 0.5 + hits * 0.1);
        drawImg(ctx, ASSETS.gloves, w * 0.16, h * 0.62, 58, 0, 0.6);
        drawGaugeBar(ctx, w * 0.12, h * 0.78, w * 0.76, needle, zoneL, zoneW);
        ctx.fillStyle = 'rgba(254, 215, 170, 0.8)';
        ctx.font = '11px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Presavimai ${hits}/${hitNeed}`, w * 0.5, h * 0.72);
      }

      function drawQcPhase(ctx, w, h) {
        drawPharmaLab(ctx, w, h);
        ctx.fillStyle = 'rgba(254, 215, 170, 0.75)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText('Pažymėk brokuotas tabletes', w * 0.5, h * 0.18);
        ctx.fillStyle = '#334155';
        ctx.fillRect(w * 0.15, h * 0.32, w * 0.7, h * 0.35);
        defects.forEach((d) => {
          const px = w * d.x;
          const py = h * d.y;
          if (!d.done) {
            drawPill(ctx, px, py, 18, 11, '#fef3c7', '#fdba74', d.defect);
            if (d.defect && checked < checkNeed) {
              ctx.strokeStyle = `rgba(251, 146, 60, ${0.4 + Math.sin(Date.now() / 200) * 0.3})`;
              ctx.lineWidth = 2;
              ctx.beginPath();
              ctx.arc(px, py, 24, 0, Math.PI * 2);
              ctx.stroke();
            }
          } else {
            ctx.fillStyle = 'rgba(34, 197, 94, 0.5)';
            ctx.beginPath();
            ctx.arc(px, py, 14, 0, Math.PI * 2);
            ctx.fill();
          }
        });
        ctx.fillStyle = 'rgba(254, 215, 170, 0.8)';
        ctx.fillText(`Kontrolė ${checked}/${checkNeed}`, w * 0.5, h * 0.75);
      }

      bindResize(canvas, (ctx, w, h) => {
        if (phase === 'press') drawPressPhase(ctx, w, h);
        else drawQcPhase(ctx, w, h);
      });

      pressBtn.onclick = () => {
        if (phase !== 'press') return;
        const ok = needle >= zoneL && needle <= zoneL + zoneW;
        if (!ok) {
          failHooks(hooks);
          return;
        }
        hits += 1;
        plungeAnim = 1;
        powderLevel = Math.max(0.15, powderLevel - 0.1);
        sfx('press');
        if (window.MgFx) MgFx.shake(0.5);
        setTimeout(() => { plungeAnim = 0; }, 180);
        if (hits >= hitNeed) {
          phase = 'qc';
          pressBtn.style.display = 'none';
          stopLoop();
          hooks.setStep(2, 2, 'Patikrink tabletes');
          status.textContent = 'Spausk ant brokuotų tablečių';
        } else {
          status.textContent = `Presavimai ${hits}/${hitNeed}`;
        }
      };

      runLoop(() => {
        if (phase !== 'press') return;
        needle += nDir;
        if (needle >= 94) nDir = -2.2;
        if (needle <= 4) nDir = 2.2;
        plungeAnim = Math.max(0, plungeAnim - 0.08);
        const ctx = canvas.getContext('2d');
        const r = canvas.parentElement.getBoundingClientRect();
        drawPressPhase(ctx, r.width, r.height);
      });

      canvas.onclick = (ev) => {
        if (phase !== 'qc') return;
        const { x, y, w, h } = canvasPos(canvas, ev);
        for (let i = 0; i < defects.length; i += 1) {
          const d = defects[i];
          if (d.done || !d.defect) continue;
          if (Math.hypot(x - w * d.x, y - h * d.y) < 26) {
            d.done = true;
            checked += 1;
            sfx('click');
            if (checked >= checkNeed) winHooks(hooks, { score: 88 });
            else status.textContent = `Kontrolė ${checked}/${checkNeed}`;
            return;
          }
        }
        if (defects.some((d) => !d.defect && Math.hypot(x - w * d.x, y - h * d.y) < 22)) {
          sfx('fail');
          if (window.MgFx) MgFx.shake(0.9);
          status.textContent = 'Tai gera tabletė — ieškok broko';
        }
      };
    });
  }

  /**
   * pills_pack — blisterio pildymas → plėvelės užlydinimas
   */
  function runBlister(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      const slotCount = data.steps || 3;
      let phase = 'fill';
      const slots = Array.from({ length: slotCount }, () => ({ done: false, px: 0, py: 0 }));
      let fillIdx = 0;

      let seals = 0;
      const sealNeed = 3;
      let marker = 10;
      let mDir = 2.4;
      const sealZones = [20, 50, 80];
      let foldProgress = 0;

      const { canvas } = makeStage(root);
      const status = addStatus(root, 'Įspausk tabletes į tuščias blistro lizdas');
      hooks.setStep(1, 2, 'Įspausk tabletes į blisterį');
      armTimeout(60000, hooks);

      function drawFill(ctx, w, h) {
        drawPharmaLab(ctx, w, h);
        const bw = Math.min(w * 0.55, 320);
        const bh = Math.min(h * 0.38, 140);
        drawBlister(ctx, w * 0.5, h * 0.48, bw, bh, slots, fillIdx, fillIdx);
        ctx.fillStyle = 'rgba(254, 215, 170, 0.8)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Užpildyta ${fillIdx}/${slotCount}`, w * 0.5, h * 0.72);
      }

      function drawSeal(ctx, w, h) {
        drawPharmaLab(ctx, w, h);
        const bw = Math.min(w * 0.5, 280);
        const bh = Math.min(h * 0.32, 120);
        const cx = w * 0.5;
        const cy = h * 0.42;
        drawBlister(ctx, cx, cy, bw, bh, slots, slotCount, -1);
        ctx.fillStyle = 'rgba(248, 250, 252, 0.28)';
        ctx.fillRect(cx - bw / 2, cy - bh / 2 - foldProgress * 10, bw, bh * 0.38);
        ctx.strokeStyle = 'rgba(254, 215, 170, 0.4)';
        ctx.strokeRect(cx - bw / 2, cy - bh / 2 - foldProgress * 10, bw, bh * 0.38);

        ctx.fillStyle = 'rgba(254, 215, 170, 0.75)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText('Užlenk apsauginę plėvelę — tikslūs paspaudimai', w * 0.5, h * 0.2);

        const tx = w * 0.12;
        const tw = w * 0.76;
        const ty = h * 0.7;
        ctx.fillStyle = 'rgba(28, 12, 4, 0.9)';
        ctx.fillRect(tx, ty, tw, 10);
        sealZones.forEach((z, i) => {
          const zx = tx + tw * (z / 100);
          ctx.beginPath();
          ctx.arc(zx, ty + 5, i < seals ? 9 : 11, 0, Math.PI * 2);
          ctx.fillStyle = i < seals ? 'rgba(251, 146, 60, 0.9)' : 'rgba(251, 146, 60, 0.2)';
          ctx.fill();
          ctx.strokeStyle = '#ffedd5';
          ctx.stroke();
        });
        const mx = tx + tw * (marker / 100);
        ctx.fillStyle = '#fff7ed';
        ctx.beginPath();
        ctx.moveTo(mx, ty - 5);
        ctx.lineTo(mx + 5, ty + 14);
        ctx.lineTo(mx - 5, ty + 14);
        ctx.closePath();
        ctx.fill();
        ctx.fillStyle = 'rgba(254, 215, 170, 0.8)';
        ctx.fillText(`Užlydinimas ${seals}/${sealNeed}`, w * 0.5, h * 0.62);
      }

      bindResize(canvas, (ctx, w, h) => {
        if (phase === 'fill') drawFill(ctx, w, h);
        else drawSeal(ctx, w, h);
      });

      canvas.onclick = (ev) => {
        const { x, y, w, h } = canvasPos(canvas, ev);
        if (phase === 'fill') {
          const slot = slots[fillIdx];
          if (!slot || slot.done) return;
          const cx = w * 0.5 + slot.px;
          const cy = h * 0.48 + slot.py;
          if (Math.hypot(x - cx, y - cy) < 32) {
            slot.done = true;
            fillIdx += 1;
            sfx('tap');
            if (fillIdx >= slotCount) {
              phase = 'seal';
              hooks.setStep(2, 2, 'Užlenk apsauginę plėvelę');
              status.textContent = 'Spausk kai žymeklis ant užlydinimo taško';
              startSealLoop();
            } else {
              status.textContent = `Užpildyta ${fillIdx}/${slotCount}`;
            }
          }
        } else {
          const tx = w * 0.12;
          const tw = w * 0.76;
          const zone = sealZones[seals];
          if (zone == null) return;
          const zx = tx + tw * (zone / 100);
          const inMarker = marker >= zone - 8 && marker <= zone + 8;
          if (inMarker && Math.hypot(x - zx, y - h * 0.75) < 28) {
            seals += 1;
            foldProgress += 1;
            sfx('seal');
            if (window.MgFx) MgFx.flash('rgba(251, 146, 60, 0.25)');
            if (seals >= sealNeed) winHooks(hooks, { score: 89 });
            else status.textContent = `Užlydinta ${seals}/${sealNeed}`;
          } else if (!inMarker) {
            sfx('fail');
            if (window.MgFx) MgFx.shake(0.85);
          }
        }
      };

      function startSealLoop() {
        runLoop(() => {
          marker += mDir;
          if (marker >= 94) mDir = -2.4;
          if (marker <= 6) mDir = 2.4;
          const ctx = canvas.getContext('2d');
          const r = canvas.parentElement.getBoundingClientRect();
          drawSeal(ctx, r.width, r.height);
        });
      }
    });
  }

  return { runPress, runBlister, cleanup };
})();
