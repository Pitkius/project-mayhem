/**
 * Grybai (Psilocybin) — premium Canvas minigame (valymas + stiklainis + derlius).
 * Naudoja esamą scheduleResult flow; nekeičia serverio logikos.
 */
window.MgMushroom = (() => {
  const ASSETS = {
    gloves: 'icons/gloves_item.png',
    scissors: 'icons/trimming_scissors.png',
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
    root.className = 'mg-mushroom-root mg-scene-mushroom';
    schBoard.appendChild(root);
    return root;
  }

  function makeStage(parent) {
    const wrap = document.createElement('div');
    wrap.className = 'mg-mushroom-stage-wrap';
    const canvas = document.createElement('canvas');
    canvas.className = 'mg-mushroom-canvas';
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

  function createSpores(count) {
    return Array.from({ length: count }, () => ({
      x: Math.random(),
      y: Math.random(),
      vx: (Math.random() - 0.5) * 0.001,
      vy: -0.0006 - Math.random() * 0.0012,
      life: 0.4 + Math.random() * 0.6,
      size: 2 + Math.random() * 4,
    }));
  }

  function tickSpores(ctx, parts, w, h, intensity) {
    parts.forEach((p) => {
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 0.0035 * intensity;
      if (p.life <= 0) {
        p.x = Math.random();
        p.y = 0.7 + Math.random() * 0.2;
        p.life = 0.5 + Math.random() * 0.5;
      }
      const px = p.x * w;
      const py = p.y * h;
      const g = ctx.createRadialGradient(px, py, 0, px, py, p.size * 2.5);
      g.addColorStop(0, `rgba(192, 132, 252, ${p.life * 0.4 * intensity})`);
      g.addColorStop(1, 'rgba(168, 85, 247, 0)');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(px, py, p.size * 2.5, 0, Math.PI * 2);
      ctx.fill();
    });
  }

  function drawForestLab(ctx, w, h) {
    const grd = ctx.createLinearGradient(0, 0, 0, h);
    grd.addColorStop(0, '#0c0618');
    grd.addColorStop(0.45, '#140a24');
    grd.addColorStop(1, '#080412');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, w, h);

    const moss = ctx.createRadialGradient(w * 0.3, h * 0.85, 0, w * 0.3, h * 0.85, w * 0.4);
    moss.addColorStop(0, 'rgba(34, 120, 60, 0.2)');
    moss.addColorStop(1, 'rgba(34, 120, 60, 0)');
    ctx.fillStyle = moss;
    ctx.fillRect(0, h * 0.5, w, h * 0.5);

    ctx.fillStyle = '#1a1208';
    ctx.fillRect(0, h * 0.82, w, h * 0.18);
  }

  function drawForestFloor(ctx, w, h) {
    const grd = ctx.createLinearGradient(0, 0, 0, h);
    grd.addColorStop(0, '#061208');
    grd.addColorStop(0.35, '#0a1a0e');
    grd.addColorStop(1, '#142018');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, w, h);

    for (let i = 0; i < 6; i += 1) {
      const tx = w * (0.1 + i * 0.15);
      const th = h * (0.25 + (i % 3) * 0.08);
      ctx.fillStyle = 'rgba(20, 50, 30, 0.35)';
      ctx.beginPath();
      ctx.moveTo(tx, h);
      ctx.lineTo(tx + 20, h - th);
      ctx.lineTo(tx + 40, h);
      ctx.fill();
    }
  }

  function drawMushroom(ctx, cx, cy, scale, glow) {
    ctx.save();
    ctx.translate(cx, cy);
    if (glow > 0) {
      const rg = ctx.createRadialGradient(0, -8 * scale, 0, 0, -8 * scale, 40 * scale);
      rg.addColorStop(0, `rgba(192, 132, 252, ${glow * 0.35})`);
      rg.addColorStop(1, 'rgba(168, 85, 247, 0)');
      ctx.fillStyle = rg;
      ctx.beginPath();
      ctx.arc(0, -8 * scale, 40 * scale, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.fillStyle = '#f5f5f4';
    ctx.beginPath();
    ctx.ellipse(0, 8 * scale, 10 * scale, 16 * scale, 0, 0, Math.PI * 2);
    ctx.fill();
    const capG = ctx.createRadialGradient(-8 * scale, -12 * scale, 0, 0, -8 * scale, 28 * scale);
    capG.addColorStop(0, '#e9d5ff');
    capG.addColorStop(0.5, '#c084fc');
    capG.addColorStop(1, '#7e22ce');
    ctx.fillStyle = capG;
    ctx.beginPath();
    ctx.ellipse(0, -10 * scale, 28 * scale, 18 * scale, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,0.35)';
    ctx.beginPath();
    ctx.ellipse(-8 * scale, -16 * scale, 5 * scale, 3 * scale, -0.4, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  function drawJar(ctx, cx, cy, scale, fillPct, capAngle) {
    ctx.save();
    ctx.translate(cx, cy);
    const w = 44 * scale;
    const h = 72 * scale;
    ctx.strokeStyle = 'rgba(233, 213, 255, 0.5)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-w * 0.35, -h * 0.4);
    ctx.lineTo(-w * 0.4, h * 0.35);
    ctx.quadraticCurveTo(0, h * 0.42, w * 0.4, h * 0.35);
    ctx.lineTo(w * 0.35, -h * 0.4);
    ctx.closePath();
    ctx.stroke();
    const fh = h * 0.55 * clamp(fillPct / 100, 0, 1);
    ctx.fillStyle = 'rgba(126, 34, 206, 0.45)';
    ctx.fillRect(-w * 0.36, h * 0.32 - fh, w * 0.72, fh);
    for (let i = 0; i < 3 && fillPct > 20; i += 1) {
      drawMushroom(ctx, (i - 1) * 14 * scale, h * 0.2 - fh * 0.3, 0.45 * scale, 0.2);
    }
    ctx.save();
    ctx.translate(0, -h * 0.44);
    ctx.rotate(capAngle);
    ctx.fillStyle = '#64748b';
    ctx.fillRect(-w * 0.3, -h * 0.06, w * 0.6, h * 0.08);
    ctx.restore();
    ctx.restore();
  }

  function drawDryRack(ctx, cx, cy, w, hooks) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.strokeStyle = 'rgba(192, 132, 252, 0.45)';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(-w / 2, -30);
    ctx.lineTo(w / 2, -30);
    ctx.stroke();
    hooks.forEach((h) => {
      ctx.beginPath();
      ctx.arc(h.x, h.y, 10, 0, Math.PI * 2);
      ctx.fillStyle = h.done ? 'rgba(192, 132, 252, 0.8)' : 'rgba(192, 132, 252, 0.2)';
      ctx.fill();
      if (h.done) drawMushroom(ctx, h.x, h.y + 22, 0.55, 0.3);
    });
    ctx.restore();
  }

  function drawGauge(ctx, x, y, w, needle, zoneL, zoneW) {
    ctx.fillStyle = 'rgba(20, 8, 36, 0.9)';
    ctx.fillRect(x, y, w, 10);
    ctx.fillStyle = 'rgba(34, 197, 94, 0.6)';
    ctx.fillRect(x + w * (zoneL / 100), y, w * (zoneW / 100), 10);
    const nx = x + w * (needle / 100);
    ctx.fillStyle = '#f3e8ff';
    ctx.beginPath();
    ctx.moveTo(nx, y - 5);
    ctx.lineTo(nx + 5, y + 14);
    ctx.lineTo(nx - 5, y + 14);
    ctx.closePath();
    ctx.fill();
  }

  function addStatus(parent, text) {
    const s = document.createElement('p');
    s.className = 'mg-mushroom-status';
    s.textContent = text;
    parent.appendChild(s);
    return s;
  }

  function addBtn(parent, text, cls, onClick) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `mg-mushroom-btn mg-mushroom-btn--${cls || 'ghost'}`;
    b.textContent = text;
    if (onClick) b.onclick = onClick;
    parent.appendChild(b);
    return b;
  }

  function addMeter(parent, label, id) {
    const m = document.createElement('div');
    m.className = 'mg-mushroom-meter';
    m.innerHTML = `<label>${label}</label><div class="mg-mushroom-meter-bar"><div class="mg-mushroom-meter-fill" id="${id}"></div></div>`;
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
    if (window.MgFx) MgFx.flash('rgba(192, 132, 252, 0.38)');
    cleanup();
    hooks.onWin(extra);
  }

  function armTimeout(ms, hooks) {
    const t = setTimeout(() => failHooks(hooks), ms);
    cleanups.push(() => clearTimeout(t));
  }

  /**
   * mushroom_process — šepečio valymas → džiovinimo stovas
   */
  function runBrush(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      const need = data.steps || 4;
      let phase = 'brush';
      let brushed = 0;
      const spores = createSpores(18);
      const dirt = [
        { x: 0.38, y: 0.4 }, { x: 0.55, y: 0.35 }, { x: 0.48, y: 0.52 },
        { x: 0.62, y: 0.48 }, { x: 0.42, y: 0.58 },
      ].slice(0, need).map((p) => ({ ...p, done: false }));

      let hung = 0;
      const hookNeed = 3;
      const hooks_rack = [
        { x: -80, y: -10, done: false }, { x: 0, y: -10, done: false }, { x: 80, y: -10, done: false },
      ];

      const { canvas } = makeStage(root);
      const status = addStatus(root, 'Nušveisk purvo dėmes nuo grybo');
      hooks.setStep(1, 2, 'Nuvalyk grybus');
      armTimeout(65000, hooks);

      function drawBrush(ctx, w, h) {
        drawForestLab(ctx, w, h);
        drawMushroom(ctx, w * 0.5, h * 0.5, 1.6, 0.5);
        dirt.forEach((d) => {
          if (d.done) return;
          const px = w * d.x;
          const py = h * d.y;
          ctx.fillStyle = 'rgba(87, 65, 45, 0.75)';
          ctx.beginPath();
          ctx.ellipse(px, py, 14, 10, 0.3, 0, Math.PI * 2);
          ctx.fill();
          ctx.strokeStyle = 'rgba(251, 146, 60, 0.5)';
          ctx.setLineDash([4, 3]);
          ctx.stroke();
          ctx.setLineDash([]);
        });
        drawImg(ctx, ASSETS.scissors, w * 0.2, h * 0.55, 64, -0.3, 0.7);
        tickSpores(ctx, spores, w, h, 0.7);
        ctx.fillStyle = 'rgba(233, 213, 255, 0.8)';
        ctx.font = '11px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Nuvalyta ${brushed}/${need}`, w * 0.5, h * 0.78);
      }

      function drawDry(ctx, w, h) {
        drawForestLab(ctx, w, h);
        drawDryRack(ctx, w * 0.5, h * 0.45, Math.min(w * 0.55, 280), hooks_rack);
        tickSpores(ctx, spores, w, h, 0.5);
        ctx.fillStyle = 'rgba(233, 213, 255, 0.8)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Pakabinta ${hung}/${hookNeed}`, w * 0.5, h * 0.72);
      }

      bindResize(canvas, (ctx, w, h) => {
        if (phase === 'brush') drawBrush(ctx, w, h);
        else drawDry(ctx, w, h);
      });

      canvas.onclick = (ev) => {
        const { x, y, w, h } = canvasPos(canvas, ev);
        if (phase === 'brush') {
          for (let i = 0; i < dirt.length; i += 1) {
            const d = dirt[i];
            if (d.done) continue;
            if (Math.hypot(x - w * d.x, y - h * d.y) < 22) {
              d.done = true;
              brushed += 1;
              sfx('scrape');
              if (brushed >= need) {
                phase = 'dry';
                hooks.setStep(2, 2, 'Paruošk džiovinimui');
                status.textContent = 'Pakabink grybus ant stovo';
              } else {
                status.textContent = `Nuvalyta ${brushed}/${need}`;
              }
              return;
            }
          }
        } else {
          const cx = w * 0.5;
          const cy = h * 0.45;
          hooks_rack.forEach((hook) => {
            if (hook.done) return;
            const hx = cx + hook.x;
            const hy = cy + hook.y;
            if (Math.hypot(x - hx, y - hy) < 24) {
              hook.done = true;
              hung += 1;
              sfx('click');
              if (hung >= hookNeed) winHooks(hooks, { score: 85 });
              else status.textContent = `Pakabinta ${hung}/${hookNeed}`;
            }
          });
        }
      };
    });
  }

  /**
   * mushroom_pack — pildymas → dangtelis → sandarinimas
   */
  function runJar(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      let phase = 'pour';
      let fill = 0;
      let speed = 0;
      let hold = false;
      let overflows = 0;
      const spores = createSpores(14);

      let capTurns = 0;
      const capNeed = 3;
      let capAngle = 0;
      const capTargets = [0, Math.PI * 0.4, Math.PI * 0.8];

      let seals = 0;
      const sealNeed = 2;
      let marker = 12;
      let mDir = 2.5;
      const sealZones = [28, 68];

      const { canvas } = makeStage(root);
      const hud = document.createElement('div');
      hud.className = 'mg-mushroom-hud';
      root.appendChild(hud);
      const status = addStatus(root, 'Laikyk „Pilti“ — žalias greitis, tikslas 95%');
      const pourBtn = addBtn(hud, 'Pilti grybus', 'primary', null);
      const fillBar = addMeter(hud, 'Stiklainis', 'mgMushFill');

      hooks.setStep(1, 3, 'Supilk į stiklainį');
      armTimeout(70000, hooks);

      function paintFill() {
        if (fillBar) fillBar.style.width = `${Math.min(100, fill)}%`;
      }

      function drawPour(ctx, w, h) {
        drawForestLab(ctx, w, h);
        drawJar(ctx, w * 0.52, h * 0.52, 1.2, fill, capAngle);
        if (hold && speed > 10) {
          for (let i = 0; i < 4; i += 1) {
            drawMushroom(ctx, w * 0.35 + i * 8, h * 0.28 + i * 6, 0.35, 0.15);
          }
        }
        drawGauge(ctx, w * 0.12, h * 0.78, w * 0.76, speed, 35, 30);
        tickSpores(ctx, spores, w, h, 0.6);
      }

      function drawCap(ctx, w, h) {
        drawForestLab(ctx, w, h);
        drawJar(ctx, w * 0.5, h * 0.5, 1.35, 95, capAngle);
        const cx = w * 0.5;
        const cy = h * 0.5 - 72 * 1.35 * 0.44;
        capTargets.forEach((ang, i) => {
          const rx = cx + Math.cos(ang - Math.PI / 2) * 50;
          const ry = cy + Math.sin(ang - Math.PI / 2) * 50;
          ctx.beginPath();
          ctx.arc(rx, ry, i < capTurns ? 9 : 11, 0, Math.PI * 2);
          ctx.fillStyle = i < capTurns ? 'rgba(192, 132, 252, 0.9)' : 'rgba(192, 132, 252, 0.25)';
          ctx.fill();
          ctx.strokeStyle = '#f3e8ff';
          ctx.stroke();
          ctx.fillStyle = '#1e0a32';
          ctx.font = 'bold 10px system-ui';
          ctx.textAlign = 'center';
          ctx.fillText(String(i + 1), rx, ry + 4);
        });
        ctx.fillStyle = 'rgba(233, 213, 255, 0.8)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText('Spausk dangtelio žymes iš eilės', w * 0.5, h * 0.2);
      }

      function drawSealPhase(ctx, w, h) {
        drawForestLab(ctx, w, h);
        drawJar(ctx, w * 0.5, h * 0.48, 1.2, 95, capAngle);
        drawGauge(ctx, w * 0.12, h * 0.72, w * 0.76, marker, 0, 0);
        sealZones.forEach((z, i) => {
          const zx = w * 0.12 + w * 0.76 * (z / 100);
          ctx.beginPath();
          ctx.arc(zx, h * 0.72 + 5, i < seals ? 9 : 11, 0, Math.PI * 2);
          ctx.fillStyle = i < seals ? 'rgba(192, 132, 252, 0.9)' : 'rgba(192, 132, 252, 0.22)';
          ctx.fill();
          ctx.strokeStyle = '#f3e8ff';
          ctx.stroke();
        });
        ctx.fillStyle = 'rgba(233, 213, 255, 0.8)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Sandarinimas ${seals}/${sealNeed}`, w * 0.5, h * 0.58);
      }

      bindResize(canvas, (ctx, w, h) => {
        if (phase === 'pour') drawPour(ctx, w, h);
        else if (phase === 'cap') drawCap(ctx, w, h);
        else drawSealPhase(ctx, w, h);
      });

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
        if (phase === 'pour') {
          speed = hold ? Math.min(100, speed + 4) : Math.max(0, speed - 3);
          if (hold && speed > 10) {
            const rate = speed > 75 ? 2.4 : speed > 40 ? 1.3 : 0.5;
            fill += rate;
            if (fill > 102) {
              overflows += 1;
              fill = 100;
              status.textContent = 'Perpylė! Lėčiau…';
            } else if (fill >= 93 && fill <= 98 && speed >= 35 && speed <= 68) {
              phase = 'cap';
              pourBtn.style.display = 'none';
              hooks.setStep(2, 3, 'Užsukuvok dangtelį');
              status.textContent = 'Spausk žymes ant dangtelio (1 → 2 → 3)';
            }
            paintFill();
            if (hooks.hint) hooks.hint.textContent = `Pildymas ${Math.round(fill)}%`;
          }
          const ctx = canvas.getContext('2d');
          const r = canvas.parentElement.getBoundingClientRect();
          drawPour(ctx, r.width, r.height);
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
        if (phase === 'cap') {
          const ang = capTargets[capTurns];
          if (ang == null) return;
          const cx = w * 0.5;
          const cy = h * 0.5 - 72 * 1.35 * 0.44;
          const tx = cx + Math.cos(ang - Math.PI / 2) * 50;
          const ty = cy + Math.sin(ang - Math.PI / 2) * 50;
          if (Math.hypot(x - tx, y - ty) < 22) {
            capTurns += 1;
            capAngle += Math.PI * 0.35;
            sfx('seal');
            if (capTurns >= capNeed) {
              phase = 'seal';
              hooks.setStep(3, 3, 'Užsandarink');
              status.textContent = 'Spausk kai žymeklis ant violetinės zonos';
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
            if (seals >= sealNeed) winHooks(hooks, { score: 87 });
            else status.textContent = `Užsandarinta ${seals}/${sealNeed}`;
          } else if (!inMarker) {
            sfx('fail');
            if (window.MgFx) MgFx.shake(0.85);
          }
        }
      };
    });
  }

  /**
   * mushroom_harvest — lauko derlius (spore catcher)
   */
  function runHarvest(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      const need = data.steps || 5;
      let picked = 0;
      const spores = createSpores(24);
      const spawns = [];
      let spawnTimer = 0;

      const { canvas } = makeStage(root);
      const status = addStatus(root, 'Spausk ant grybų kol jie neišnyko');
      hooks.setStep(1, 1, 'Surink grybus laiku');
      armTimeout(45000, hooks);

      function spawnOne(w, h) {
        if (picked + spawns.length >= need + 2) return;
        spawns.push({
          x: 0.12 + Math.random() * 0.76,
          y: 0.2 + Math.random() * 0.55,
          life: 1,
          maxLife: 2.8 + Math.random() * 1.2,
          scale: 0.7 + Math.random() * 0.5,
          id: Date.now() + Math.random(),
        });
      }

      bindResize(canvas, (ctx, w, h) => {
        drawForestFloor(ctx, w, h);
        tickSpores(ctx, spores, w, h, 1);
        spawns.forEach((s) => {
          const alpha = clamp(s.life / s.maxLife, 0, 1);
          drawMushroom(ctx, w * s.x, h * s.y, s.scale, alpha * 0.8);
          if (s.life < 0.4) {
            ctx.strokeStyle = `rgba(248, 113, 113, ${1 - s.life * 2})`;
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.arc(w * s.x, h * s.y, 30 * s.scale, 0, Math.PI * 2);
            ctx.stroke();
          }
        });
        ctx.fillStyle = 'rgba(233, 213, 255, 0.85)';
        ctx.font = '13px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Surinkta ${picked}/${need}`, w * 0.5, h * 0.12);
      });

      spawnOne(800, 450);
      runLoop(() => {
        spawnTimer += 1;
        if (spawnTimer % 50 === 0 && picked < need) spawnOne(800, 450);
        for (let i = spawns.length - 1; i >= 0; i -= 1) {
          spawns[i].life -= 0.016;
          if (spawns[i].life <= 0) {
            spawns.splice(i, 1);
            if (picked < need) {
              sfx('fail');
              status.textContent = 'Praleidai grybą — greičiau!';
            }
          }
        }
        const ctx = canvas.getContext('2d');
        const r = canvas.parentElement.getBoundingClientRect();
        drawForestFloor(ctx, r.width, r.height);
        tickSpores(ctx, spores, r.width, r.height, 1);
        spawns.forEach((s) => {
          const alpha = clamp(s.life / s.maxLife, 0, 1);
          drawMushroom(ctx, r.width * s.x, r.height * s.y, s.scale, alpha * 0.8);
        });
        ctx.fillStyle = 'rgba(233, 213, 255, 0.85)';
        ctx.font = '13px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Surinkta ${picked}/${need}`, r.width * 0.5, r.height * 0.12);
      });

      canvas.onclick = (ev) => {
        const { x, y, w, h } = canvasPos(canvas, ev);
        for (let i = spawns.length - 1; i >= 0; i -= 1) {
          const s = spawns[i];
          if (Math.hypot(x - w * s.x, y - h * s.y) < 32 * s.scale) {
            spawns.splice(i, 1);
            picked += 1;
            sfx('click');
            if (window.MgFx) MgFx.flash('rgba(192, 132, 252, 0.25)');
            if (picked >= need) winHooks(hooks, { score: 90 });
            else {
              status.textContent = `Surinkta ${picked}/${need}`;
              setTimeout(() => spawnOne(w, h), 400);
            }
            return;
          }
        }
      };
    });
  }

  return { runBrush, runJar, runHarvest, cleanup };
})();
