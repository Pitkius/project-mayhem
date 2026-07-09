/**
 * THC — premium Canvas minigames (distiliacija + kasetės pildymas).
 * Naudoja esamą scheduleResult flow; nekeičia serverio / item logikos.
 */
window.MgThc = (() => {
  const ASSETS = {
    scissors: 'icons/trimming_scissors.png',
    leaf: 'icons/weed_leaf.png',
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
    root.className = 'mg-thc-root mg-scene-thc';
    schBoard.appendChild(root);
    return root;
  }

  function makeStage(parent) {
    const wrap = document.createElement('div');
    wrap.className = 'mg-thc-stage-wrap';
    const canvas = document.createElement('canvas');
    canvas.className = 'mg-thc-canvas';
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

  function createOrbs(count) {
    return Array.from({ length: count }, () => ({
      x: Math.random(),
      y: Math.random(),
      vx: (Math.random() - 0.5) * 0.0012,
      vy: -0.0008 - Math.random() * 0.0015,
      life: 0.4 + Math.random() * 0.5,
      size: 2 + Math.random() * 4,
    }));
  }

  function tickOrbs(ctx, parts, w, h, intensity) {
    parts.forEach((p) => {
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 0.004 * intensity;
      if (p.life <= 0 || p.y < 0) {
        p.x = 0.3 + Math.random() * 0.4;
        p.y = 0.7 + Math.random() * 0.15;
        p.life = 0.5 + Math.random() * 0.4;
      }
      const px = p.x * w;
      const py = p.y * h;
      const g = ctx.createRadialGradient(px, py, 0, px, py, p.size * 3);
      g.addColorStop(0, `rgba(192, 132, 252, ${p.life * 0.45 * intensity})`);
      g.addColorStop(0.5, `rgba(124, 58, 237, ${p.life * 0.25 * intensity})`);
      g.addColorStop(1, 'rgba(167, 139, 250, 0)');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(px, py, p.size * 3, 0, Math.PI * 2);
      ctx.fill();
    });
  }

  function drawDistillLab(ctx, w, h) {
    const grd = ctx.createLinearGradient(0, 0, 0, h);
    grd.addColorStop(0, '#0c0618');
    grd.addColorStop(0.5, '#120a22');
    grd.addColorStop(1, '#08040f');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, w, h);

    const glow = ctx.createRadialGradient(w * 0.5, h * 0.2, 0, w * 0.5, h * 0.35, w * 0.5);
    glow.addColorStop(0, 'rgba(124, 58, 237, 0.18)');
    glow.addColorStop(1, 'rgba(124, 58, 237, 0)');
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, w, h * 0.55);

    ctx.fillStyle = '#140c20';
    ctx.fillRect(0, h * 0.78, w, h * 0.22);
    drawImg(ctx, ASSETS.gloves, w * 0.1, h * 0.86, Math.min(w, h) * 0.09, -0.15);
    drawImg(ctx, ASSETS.scale, w * 0.9, h * 0.86, Math.min(w, h) * 0.1);
  }

  function drawStill(ctx, cx, cy, scale, boil) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.fillStyle = '#334155';
    ctx.fillRect(-35 * scale, -50 * scale, 70 * scale, 90 * scale);
    ctx.fillStyle = `rgba(124, 58, 237, ${0.35 + boil * 0.4})`;
    ctx.fillRect(-30 * scale, -10 * scale, 60 * scale, 50 * scale);
    ctx.strokeStyle = 'rgba(196, 181, 253, 0.5)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(35 * scale, -30 * scale);
    ctx.lineTo(55 * scale, -55 * scale);
    ctx.lineTo(55 * scale, -70 * scale);
    ctx.stroke();
    ctx.fillStyle = 'rgba(167, 139, 250, 0.25)';
    ctx.fillRect(48 * scale, -72 * scale, 14 * scale, 30 * scale);
    ctx.restore();
  }

  function drawTrimBoard(ctx, cx, cy, scale, cuts, cutMarks) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.fillStyle = '#1e293b';
    ctx.beginPath();
    ctx.roundRect(-90 * scale, -55 * scale, 180 * scale, 110 * scale, 10);
    ctx.fill();
    drawImg(ctx, ASSETS.leaf, 0, 0, 100 * scale, 0.1, 0.85);
    cutMarks.forEach((m, i) => {
      if (cuts > i) {
        ctx.strokeStyle = 'rgba(34, 197, 94, 0.8)';
        ctx.lineWidth = 3;
      } else if (cuts === i) {
        ctx.strokeStyle = `rgba(250, 204, 21, ${0.6 + Math.sin(Date.now() / 180) * 0.3})`;
        ctx.lineWidth = 3;
      } else {
        ctx.strokeStyle = 'rgba(167, 139, 250, 0.35)';
        ctx.lineWidth = 2;
      }
      ctx.beginPath();
      ctx.moveTo(m.x1 * scale, m.y1 * scale);
      ctx.lineTo(m.x2 * scale, m.y2 * scale);
      ctx.stroke();
    });
    drawImg(ctx, ASSETS.scissors, 70 * scale, -40 * scale, 42 * scale, -0.4);
    ctx.restore();
  }

  function drawCartridge(ctx, cx, cy, scale, fill, coilGlow) {
    ctx.save();
    ctx.translate(cx, cy);
    const gw = 28 * scale;
    const gh = 95 * scale;
    ctx.fillStyle = 'rgba(226, 232, 240, 0.15)';
    ctx.strokeStyle = 'rgba(196, 181, 253, 0.6)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.roundRect(-gw / 2, -gh / 2, gw, gh, 6);
    ctx.fill();
    ctx.stroke();
    const fh = gh * 0.72 * fill;
    const lg = ctx.createLinearGradient(0, gh / 2 - fh, 0, gh / 2);
    lg.addColorStop(0, 'rgba(124, 58, 237, 0.9)');
    lg.addColorStop(1, 'rgba(192, 132, 252, 0.5)');
    ctx.fillStyle = lg;
    ctx.fillRect(-gw / 2 + 3, gh / 2 - fh, gw - 6, fh);
    ctx.fillStyle = '#475569';
    ctx.fillRect(-gw / 2 - 4, -gh / 2 - 8, gw + 8, 12);
    if (coilGlow > 0) {
      const cg = ctx.createRadialGradient(0, gh * 0.15, 0, 0, gh * 0.15, 22 * scale);
      cg.addColorStop(0, `rgba(250, 204, 21, ${coilGlow * 0.7})`);
      cg.addColorStop(1, 'rgba(250, 204, 21, 0)');
      ctx.fillStyle = cg;
      ctx.beginPath();
      ctx.arc(0, gh * 0.15, 22 * scale, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  function drawGaugeBar(ctx, x, y, w, needle, zoneL, zoneW) {
    ctx.fillStyle = 'rgba(20, 10, 35, 0.92)';
    ctx.fillRect(x, y, w, 10);
    if (zoneW > 0) {
      ctx.fillStyle = 'rgba(34, 197, 94, 0.55)';
      ctx.fillRect(x + w * (zoneL / 100), y, w * (zoneW / 100), 10);
    }
    const nx = x + w * (needle / 100);
    ctx.fillStyle = '#ede9fe';
    ctx.beginPath();
    ctx.moveTo(nx, y - 5);
    ctx.lineTo(nx + 5, y + 14);
    ctx.lineTo(nx - 5, y + 14);
    ctx.closePath();
    ctx.fill();
  }

  function addStatus(parent, text) {
    const s = document.createElement('p');
    s.className = 'mg-thc-status';
    s.textContent = text;
    parent.appendChild(s);
    return s;
  }

  function addBtn(parent, text, cls) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = `mg-thc-btn mg-thc-btn--${cls || 'ghost'}`;
    b.textContent = text;
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
    if (window.MgFx) MgFx.flash('rgba(167, 139, 250, 0.35)');
    cleanup();
    hooks.onWin(extra);
  }

  function armTimeout(ms, hooks) {
    const t = setTimeout(() => failHooks(hooks), ms);
    cleanups.push(() => clearTimeout(t));
  }

  /**
   * thc_process — trim → distiliato surinkimas → temperatūros stabilizacija
   */
  function runScrape(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      const cutNeed = data.steps || 4;
      let phase = 'trim';
      let cuts = 0;
      const cutMarks = [
        { x1: -50, y1: -20, x2: -10, y2: 10, hx: -30, hy: -5 },
        { x1: -20, y1: -30, x2: 20, y2: 5, hx: 0, hy: -12 },
        { x1: 10, y1: -15, x2: 50, y2: 25, hx: 30, hy: 5 },
        { x1: -40, y1: 15, x2: 40, y2: 35, hx: 0, hy: 25 },
        { x1: -15, y1: 0, x2: 35, y2: -25, hx: 10, hy: -10 },
      ].slice(0, cutNeed);

      const dropNeed = cutNeed;
      let drops = [];
      let collected = 0;

      let needle = 12;
      let nDir = 2.1;
      const zoneL = 36;
      const zoneW = 22;
      let holdMs = 0;
      const holdNeed = 2800;
      let holding = false;

      const orbs = createOrbs(20);
      const { canvas } = makeStage(root);
      const hud = document.createElement('div');
      hud.className = 'mg-thc-hud';
      root.appendChild(hud);
      const status = addStatus(root, 'Pažymėk pjūvio linijas ant trim medžiagos');
      hooks.setStep(1, 3, 'Paruošk trim medžiagą');
      armTimeout(75000, hooks);

      function spawnDrop() {
        drops.push({
          x: 0.52 + Math.random() * 0.12,
          y: 0.28,
          vy: 0.0012 + Math.random() * 0.0008,
          active: true,
        });
      }

      function drawTrim(ctx, w, h) {
        drawDistillLab(ctx, w, h);
        drawStill(ctx, w * 0.78, h * 0.38, 0.85, 0.3);
        drawTrimBoard(ctx, w * 0.42, h * 0.48, 1.1, cuts, cutMarks);
        tickOrbs(ctx, orbs, w, h, 0.5);
        ctx.fillStyle = 'rgba(221, 214, 254, 0.8)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Pjūviai ${cuts}/${cutNeed}`, w * 0.5, h * 0.78);
      }

      function drawCollect(ctx, w, h) {
        drawDistillLab(ctx, w, h);
        drawStill(ctx, w * 0.5, h * 0.4, 1.1, 0.7 + Math.sin(Date.now() / 400) * 0.15);
        tickOrbs(ctx, orbs, w, h, 0.9);
        drops.forEach((d) => {
          if (!d.active) return;
          d.y += d.vy;
          const px = d.x * w;
          const py = d.y * h;
          const g = ctx.createRadialGradient(px, py, 0, px, py, 14);
          g.addColorStop(0, 'rgba(192, 132, 252, 0.95)');
          g.addColorStop(1, 'rgba(124, 58, 237, 0)');
          ctx.fillStyle = g;
          ctx.beginPath();
          ctx.arc(px, py, 14, 0, Math.PI * 2);
          ctx.fill();
          if (d.y > 0.72) d.active = false;
        });
        ctx.fillStyle = 'rgba(221, 214, 254, 0.8)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Surinkta ${collected}/${dropNeed}`, w * 0.5, h * 0.78);
      }

      function drawStabilize(ctx, w, h) {
        drawDistillLab(ctx, w, h);
        drawStill(ctx, w * 0.5, h * 0.42, 1.15, clamp(holdMs / holdNeed, 0.2, 1));
        tickOrbs(ctx, orbs, w, h, 1.1);
        drawGaugeBar(ctx, w * 0.12, h * 0.72, w * 0.76, needle, zoneL, zoneW);
        const pct = Math.round((holdMs / holdNeed) * 100);
        ctx.fillStyle = holding ? '#a78bfa' : 'rgba(221, 214, 254, 0.8)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(holding ? 'Laikyk pelę / SPACE zonoje…' : 'Laikyk SPACE arba pelę ant scenos — žymeklis žalioje zonoje', w * 0.5, h * 0.62);
        ctx.fillText(`Stabilizacija ${pct}%`, w * 0.5, h * 0.82);
      }

      function drawAll(ctx, w, h) {
        if (phase === 'trim') drawTrim(ctx, w, h);
        else if (phase === 'collect') drawCollect(ctx, w, h);
        else drawStabilize(ctx, w, h);
      }

      bindResize(canvas, drawAll);

      function onHoldKey(down) {
        if (phase !== 'stabilize') return;
        holding = down;
      }

      const onKeyDown = (e) => {
        if (e.code === 'Space') {
          e.preventDefault();
          onHoldKey(true);
        }
      };
      const onKeyUp = (e) => {
        if (e.code === 'Space') onHoldKey(false);
      };
      window.addEventListener('keydown', onKeyDown);
      window.addEventListener('keyup', onKeyUp);
      cleanups.push(() => {
        window.removeEventListener('keydown', onKeyDown);
        window.removeEventListener('keyup', onKeyUp);
      });

      canvas.onmousedown = () => { if (phase === 'stabilize') holding = true; };
      canvas.onmouseup = () => { holding = false; };
      canvas.onmouseleave = () => { holding = false; };

      canvas.onclick = (ev) => {
        const { x, y, w, h } = canvasPos(canvas, ev);
        if (phase === 'trim') {
          const mark = cutMarks[cuts];
          if (!mark) return;
          const hx = w * 0.42 + mark.hx * 1.1;
          const hy = h * 0.48 + mark.hy * 1.1;
          if (Math.hypot(x - hx, y - hy) < 32) {
            cuts += 1;
            sfx('scrape');
            if (window.MgFx) MgFx.flash('rgba(124, 58, 237, 0.2)');
            if (cuts >= cutNeed) {
              phase = 'collect';
              hooks.setStep(2, 3, 'Surink distiliatą');
              status.textContent = 'Spausk ant krentančių lašų';
              for (let i = 0; i < dropNeed + 2; i += 1) {
                setTimeout(spawnDrop, i * 900);
              }
            } else {
              status.textContent = `Pjūviai ${cuts}/${cutNeed}`;
            }
          } else {
            sfx('fail');
            if (window.MgFx) MgFx.shake(0.6);
          }
        } else if (phase === 'collect') {
          let hit = false;
          drops.forEach((d) => {
            if (!d.active || hit) return;
            const px = d.x * w;
            const py = d.y * h;
            if (Math.hypot(x - px, y - py) < 24) {
              d.active = false;
              hit = true;
              collected += 1;
              sfx('drop');
              if (collected >= dropNeed) {
                phase = 'stabilize';
                hooks.setStep(3, 3, 'Stabilizuok distiliatą');
                status.textContent = 'Laikyk slėgį stabilioje zonoje';
              } else {
                status.textContent = `Surinkta ${collected}/${dropNeed}`;
              }
            }
          });
          if (!hit && phase === 'collect') {
            sfx('bubble');
          }
        }
      };

      runLoop(() => {
        const r = canvas.parentElement.getBoundingClientRect();
        const ctx = canvas.getContext('2d');
        if (phase === 'stabilize') {
          needle += nDir;
          if (needle >= 92) nDir = -2.1;
          if (needle <= 8) nDir = 2.1;
          const inZone = needle >= zoneL && needle <= zoneL + zoneW;
          if (holding && inZone) {
            holdMs += 16;
            if (Math.random() < 0.08) sfx('gauge_tick');
          } else if (holding && !inZone) {
            holdMs = Math.max(0, holdMs - 24);
            if (window.MgFx && Math.random() < 0.05) MgFx.shake(0.4);
          }
          if (holdMs >= holdNeed) winHooks(hooks, { score: 92 });
        }
        drawAll(ctx, r.width, r.height);
      });
    });
  }

  /**
   * thc_pack — slėgio pildymas → ritės įkaitinimas → antgalio sandarinimas
   */
  function runCartridge(data, hooks) {
    cleanup();
    loadAssets().then(() => {
      const root = mountBoard();
      if (!root) return hooks.onFail();

      let phase = 'fill';
      let fill = 0;
      let holding = false;
      let needle = 15;
      let nDir = 2.4;
      const zoneL = 34;
      const zoneW = 26;
      let overpressure = 0;

      const coilPads = [
        { x: 0.32, y: 0.55, id: 0 },
        { x: 0.5, y: 0.48, id: 1 },
        { x: 0.68, y: 0.55, id: 2 },
      ];
      const seq = [1, 0, 2];
      let seqStep = 0;
      let coilFlash = -1;
      let coilGlow = 0;
      let showSeq = true;
      let seqTimer = 0;

      let seals = 0;
      const sealNeed = 2;
      let marker = 12;
      let mDir = 2.3;
      const sealZones = [28, 72];

      const orbs = createOrbs(16);
      const { canvas } = makeStage(root);
      const hud = document.createElement('div');
      hud.className = 'mg-thc-hud';
      root.appendChild(hud);
      const fillBtn = addBtn(hud, 'Pildyti (laikyk)', 'primary');
      const status = addStatus(root, 'Laikyk „Pildyti“ — slėgis turi būti žalioje zonoje');
      hooks.setStep(1, 3, 'Užpildyk kasetę');
      armTimeout(70000, hooks);

      function drawFill(ctx, w, h) {
        drawDistillLab(ctx, w, h);
        drawCartridge(ctx, w * 0.5, h * 0.46, 1.2, fill, 0);
        drawGaugeBar(ctx, w * 0.12, h * 0.74, w * 0.76, needle, zoneL, zoneW);
        if (overpressure > 0) {
          ctx.fillStyle = `rgba(248, 113, 113, ${overpressure * 0.5})`;
          ctx.fillRect(0, 0, w, h);
        }
        tickOrbs(ctx, orbs, w, h, 0.6 + fill * 0.4);
        ctx.fillStyle = 'rgba(221, 214, 254, 0.85)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Pildymas ${Math.round(fill * 100)}%`, w * 0.5, h * 0.64);
      }

      function drawCoil(ctx, w, h) {
        drawDistillLab(ctx, w, h);
        drawCartridge(ctx, w * 0.5, h * 0.5, 1.15, 1, coilGlow);
        coilPads.forEach((p) => {
          const px = w * p.x;
          const py = h * p.y;
          const lit = coilFlash === p.id || (showSeq && seq[seqTimer] === p.id);
          const g = ctx.createRadialGradient(px, py, 0, px, py, 28);
          g.addColorStop(0, lit ? 'rgba(250, 204, 21, 0.9)' : 'rgba(71, 85, 105, 0.8)');
          g.addColorStop(1, lit ? 'rgba(251, 191, 36, 0)' : 'rgba(30, 41, 59, 0)');
          ctx.fillStyle = g;
          ctx.beginPath();
          ctx.arc(px, py, 28, 0, Math.PI * 2);
          ctx.fill();
          ctx.strokeStyle = lit ? '#fde68a' : 'rgba(167, 139, 250, 0.4)';
          ctx.lineWidth = 2;
          ctx.stroke();
          ctx.fillStyle = '#ede9fe';
          ctx.font = 'bold 11px system-ui';
          ctx.textAlign = 'center';
          ctx.fillText(String(p.id + 1), px, py + 4);
        });
        tickOrbs(ctx, orbs, w, h, 0.7);
        ctx.fillStyle = 'rgba(221, 214, 254, 0.85)';
        ctx.font = '11px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(showSeq ? 'Stebėk seką…' : `Pakartok seką (${seqStep}/${seq.length})`, w * 0.5, h * 0.2);
      }

      function drawSeal(ctx, w, h) {
        drawDistillLab(ctx, w, h);
        drawCartridge(ctx, w * 0.5, h * 0.44, 1.25, 1, 0.2);
        drawGaugeBar(ctx, w * 0.12, h * 0.76, w * 0.76, marker, 0, 0);
        sealZones.forEach((z, i) => {
          const zx = w * 0.12 + w * 0.76 * (z / 100);
          const zy = h * 0.5 + (i === 0 ? -18 : 18);
          ctx.beginPath();
          ctx.arc(zx, zy, i < seals ? 10 : 13, 0, Math.PI * 2);
          ctx.fillStyle = i < seals ? 'rgba(167, 139, 250, 0.9)' : 'rgba(124, 58, 237, 0.25)';
          ctx.fill();
          ctx.strokeStyle = '#ede9fe';
          ctx.stroke();
        });
        tickOrbs(ctx, orbs, w, h, 0.5);
        ctx.fillStyle = 'rgba(221, 214, 254, 0.85)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`Antgalio sandarinimas ${seals}/${sealNeed}`, w * 0.5, h * 0.68);
      }

      function drawAll(ctx, w, h) {
        if (phase === 'fill') drawFill(ctx, w, h);
        else if (phase === 'coil') drawCoil(ctx, w, h);
        else drawSeal(ctx, w, h);
      }

      bindResize(canvas, drawAll);

      fillBtn.onmousedown = () => { if (phase === 'fill') { holding = true; fillBtn.classList.add('holding'); } };
      fillBtn.onmouseup = () => { holding = false; fillBtn.classList.remove('holding'); };
      fillBtn.onmouseleave = () => { holding = false; fillBtn.classList.remove('holding'); };

      let lastSeqTick = 0;
      runLoop(() => {
        const r = canvas.parentElement.getBoundingClientRect();
        const ctx = canvas.getContext('2d');
        if (phase === 'fill') {
          needle += nDir;
          if (needle >= 93) nDir = -2.4;
          if (needle <= 7) nDir = 2.4;
          const inZone = needle >= zoneL && needle <= zoneL + zoneW;
          if (holding) {
            if (inZone) {
              fill = clamp(fill + 0.0045, 0, 1);
              overpressure = Math.max(0, overpressure - 0.03);
              if (Math.random() < 0.06) sfx('pour');
            } else {
              overpressure = clamp(overpressure + 0.04, 0, 1);
              if (overpressure >= 1) failHooks(hooks);
            }
          }
          if (fill >= 1) {
            phase = 'coil';
            fillBtn.style.display = 'none';
            showSeq = true;
            seqTimer = 0;
            lastSeqTick = Date.now();
            coilFlash = seq[0];
            hooks.setStep(2, 3, 'Įkaitink ritę');
            status.textContent = 'Stebėk šviesų seką ir pakartok';
          }
        } else if (phase === 'coil') {
          coilGlow = 0.3 + Math.sin(Date.now() / 300) * 0.2;
          if (showSeq) {
            if (Date.now() - lastSeqTick > 650) {
              seqTimer += 1;
              lastSeqTick = Date.now();
              if (seqTimer >= seq.length) {
                showSeq = false;
                coilFlash = -1;
                status.textContent = 'Spausk ant ritės pagal seką';
              } else {
                coilFlash = seq[seqTimer];
                sfx('bubble');
              }
            }
          }
        } else if (phase === 'seal') {
          marker += mDir;
          if (marker >= 92) mDir = -2.3;
          if (marker <= 8) mDir = 2.3;
        }
        drawAll(ctx, r.width, r.height);
      });

      canvas.onclick = (ev) => {
        const { x, y, w, h } = canvasPos(canvas, ev);
        if (phase === 'coil' && !showSeq) {
          const expected = seq[seqStep];
          let hit = false;
          coilPads.forEach((p) => {
            if (p.id !== expected || hit) return;
            const px = w * p.x;
            const py = h * p.y;
            if (Math.hypot(x - px, y - py) < 30) {
              hit = true;
              seqStep += 1;
              coilFlash = p.id;
              setTimeout(() => { coilFlash = -1; }, 200);
              sfx('tap');
              if (seqStep >= seq.length) {
                phase = 'seal';
                hooks.setStep(3, 3, 'Užsandarink kasetę');
                status.textContent = 'Spausk ant žymės kai žymeklis sutampa';
              }
            }
          });
          if (!hit) {
            sfx('fail');
            if (window.MgFx) MgFx.shake(0.85);
            seqStep = 0;
            status.textContent = 'Klaida — seką reikia kartoti nuo pradžių';
          }
        } else if (phase === 'seal') {
          const zone = sealZones[seals];
          if (zone == null) return;
          const zx = w * 0.12 + w * 0.76 * (zone / 100);
          const zy = h * 0.5 + (seals === 0 ? -18 : 18);
          const inMarker = marker >= zone - 8 && marker <= zone + 8;
          if (inMarker && Math.hypot(x - zx, y - zy) < 26) {
            seals += 1;
            sfx('seal');
            if (window.MgFx) MgFx.flash('rgba(167, 139, 250, 0.3)');
            if (seals >= sealNeed) winHooks(hooks, { score: 90 });
            else status.textContent = `Sandarinimas ${seals}/${sealNeed}`;
          } else if (!inMarker) {
            sfx('fail');
            if (window.MgFx) MgFx.shake(0.7);
            status.textContent = 'Lauk tinkamo momento — žymeklis turi sutapti';
          }
        }
      };
    });
  }

  return { runScrape, runCartridge, cleanup };
})();
