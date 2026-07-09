/**
 * Vape skystis — premium Canvas minigame (blend + dropper/pack).
 * Naudoja esamą scheduleResult flow; nekeičia serverio logikos.
 */
window.MgVape = (() => {
  const COLORS = {
    accent: '#67e8f9',
    accent2: '#0891b2',
    glass: 'rgba(186, 230, 253, 0.35)',
    liquid: '#22d3ee',
    liquid2: '#a855f7',
    wood: '#1c1208',
    glow: 'rgba(103, 232, 249, 0.45)',
  };

  let raf = null;
  const cleanups = [];

  function sfx(name) {
    if (window.MgAudio) MgAudio.play(name);
  }

  function easeOutCubic(t) {
    return 1 - (1 - t) ** 3;
  }

  function clamp(v, a, b) {
    return Math.max(a, Math.min(b, v));
  }

  function mountBoard() {
    if (typeof schBoard === 'undefined' || !schBoard) return null;
    schBoard.innerHTML = '';
    const root = document.createElement('div');
    root.className = 'mg-vape-root mg-scene-vape';
    schBoard.appendChild(root);
    return root;
  }

  function makeStage(parent) {
    const wrap = document.createElement('div');
    wrap.className = 'mg-vape-stage-wrap';
    const canvas = document.createElement('canvas');
    canvas.className = 'mg-vape-canvas';
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
    return ro;
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

  /** Mišinio dalelės — garai / burbuliukai */
  function createMist(count) {
    const parts = [];
    for (let i = 0; i < count; i += 1) {
      parts.push({
        x: Math.random(),
        y: Math.random(),
        vx: (Math.random() - 0.5) * 0.0008,
        vy: -0.0006 - Math.random() * 0.0012,
        life: Math.random(),
        size: 2 + Math.random() * 5,
      });
    }
    return parts;
  }

  function drawMist(ctx, w, h, parts, intensity) {
    parts.forEach((p) => {
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 0.003 * intensity;
      if (p.life <= 0 || p.y < -0.05) {
        p.x = 0.35 + Math.random() * 0.3;
        p.y = 0.55 + Math.random() * 0.2;
        p.life = 0.6 + Math.random() * 0.4;
      }
      const alpha = p.life * 0.35 * intensity;
      const px = p.x * w;
      const py = p.y * h;
      const g = ctx.createRadialGradient(px, py, 0, px, py, p.size * 3);
      g.addColorStop(0, `rgba(165, 243, 252, ${alpha})`);
      g.addColorStop(1, 'rgba(103, 232, 249, 0)');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(px, py, p.size * 3, 0, Math.PI * 2);
      ctx.fill();
    });
  }

  function drawWorkbench(ctx, w, h) {
    const grd = ctx.createLinearGradient(0, 0, 0, h);
    grd.addColorStop(0, '#061820');
    grd.addColorStop(0.55, '#0a2834');
    grd.addColorStop(1, '#041018');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, w, h);

    ctx.fillStyle = 'rgba(8, 47, 73, 0.35)';
    ctx.fillRect(0, h * 0.72, w, h * 0.28);

    ctx.strokeStyle = 'rgba(103, 232, 249, 0.08)';
    for (let i = 0; i < 12; i += 1) {
      const y = h * 0.74 + i * 3;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }

    const lamp = ctx.createRadialGradient(w * 0.5, h * 0.08, 0, w * 0.5, h * 0.2, w * 0.45);
    lamp.addColorStop(0, 'rgba(103, 232, 249, 0.18)');
    lamp.addColorStop(1, 'rgba(103, 232, 249, 0)');
    ctx.fillStyle = lamp;
    ctx.fillRect(0, 0, w, h * 0.5);
  }

  function drawFlask(ctx, cx, cy, scale, fillPct, hue) {
    const bw = 34 * scale;
    const bh = 52 * scale;
    ctx.save();
    ctx.translate(cx, cy);

    ctx.fillStyle = 'rgba(0,0,0,0.25)';
    ctx.beginPath();
    ctx.ellipse(0, bh * 0.55, bw * 0.9, bh * 0.12, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = COLORS.glass;
    ctx.lineWidth = 2 * scale;
    ctx.beginPath();
    ctx.moveTo(-bw * 0.35, -bh * 0.45);
    ctx.lineTo(-bw * 0.42, bh * 0.35);
    ctx.quadraticCurveTo(0, bh * 0.48, bw * 0.42, bh * 0.35);
    ctx.lineTo(bw * 0.35, -bh * 0.45);
    ctx.closePath();
    ctx.stroke();

    const fillH = bh * 0.7 * clamp(fillPct, 0, 1);
    const lg = ctx.createLinearGradient(0, bh * 0.35, 0, bh * 0.35 - fillH);
    lg.addColorStop(0, `hsla(${hue}, 85%, 55%, 0.85)`);
    lg.addColorStop(1, `hsla(${hue + 40}, 90%, 70%, 0.55)`);
    ctx.fillStyle = lg;
    ctx.beginPath();
    ctx.moveTo(-bw * 0.38, bh * 0.32);
    ctx.lineTo(-bw * 0.38, bh * 0.32 - fillH);
    ctx.lineTo(bw * 0.38, bh * 0.32 - fillH);
    ctx.lineTo(bw * 0.38, bh * 0.32);
    ctx.closePath();
    ctx.fill();

    ctx.restore();
  }

  function drawBeaker(ctx, cx, cy, scale, fillPct, mixHue) {
    const w = 56 * scale;
    const h = 64 * scale;
    ctx.save();
    ctx.translate(cx, cy);
    ctx.strokeStyle = 'rgba(224, 242, 254, 0.5)';
    ctx.lineWidth = 2.2 * scale;
    ctx.beginPath();
    ctx.rect(-w / 2, -h * 0.35, w, h);
    ctx.stroke();

    const fh = h * 0.85 * clamp(fillPct, 0, 1);
    const g = ctx.createLinearGradient(0, h * 0.5, 0, h * 0.5 - fh);
    g.addColorStop(0, `hsla(${mixHue}, 90%, 58%, 0.9)`);
    g.addColorStop(0.5, `hsla(${mixHue + 25}, 95%, 65%, 0.75)`);
    g.addColorStop(1, `hsla(${mixHue + 50}, 80%, 72%, 0.4)`);
    ctx.fillStyle = g;
    ctx.fillRect(-w / 2 + 3, h * 0.5 - fh, w - 6, fh);

    if (fillPct > 0.15) {
      const localMist = createMist(6);
      ctx.save();
      ctx.translate(-w / 2, -h * 0.35);
      drawMist(ctx, w, h, localMist, 0.5 + fillPct * 0.4);
      ctx.restore();
    }
    ctx.restore();
  }

  function drawRingGauge(ctx, cx, cy, r, needle, zoneStart, zoneSweep, holdPct) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.strokeStyle = 'rgba(8, 47, 73, 0.9)';
    ctx.lineWidth = 14;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.stroke();

    ctx.strokeStyle = 'rgba(34, 211, 238, 0.85)';
    ctx.lineWidth = 14;
    ctx.beginPath();
    ctx.arc(0, 0, r, zoneStart, zoneStart + zoneSweep);
    ctx.stroke();

    const arc = -Math.PI * 0.75 + (needle / 100) * Math.PI * 1.5;
    ctx.strokeStyle = '#f0f9ff';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(Math.cos(arc) * (r - 8), Math.sin(arc) * (r - 8));
    ctx.stroke();

    ctx.fillStyle = 'rgba(103, 232, 249, 0.25)';
    ctx.beginPath();
    ctx.arc(0, 0, r * 0.55, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#e0f2fe';
    ctx.font = 'bold 14px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(`${Math.round(holdPct)}%`, 0, 5);
    ctx.restore();
  }

  /**
   * vape_process — mišinio kalibracija + viskozės stabilizacija
   */
  function runBlend(data, hooks) {
    cleanup();
    const root = mountBoard();
    if (!root) return hooks.onFail();

    const target = 35 + Math.floor(Math.random() * 30);
    let pg = 12;
    let vg = 78;
    let phase = 1;
    let mist = createMist(24);

    const { canvas } = makeStage(root);
    const hud = document.createElement('div');
    hud.className = 'mg-vape-hud';
    hud.innerHTML = `
      <div class="mg-vape-hud-col"><label>PG bazė</label><input type="range" class="mg-vape-slider" id="mgVapePg" min="0" max="100" value="12"></div>
      <div class="mg-vape-meter"><strong id="mgVapeMix">45%</strong><small>Tikslas ~${target}%</small></div>
      <div class="mg-vape-hud-col"><label>VG carrier</label><input type="range" class="mg-vape-slider" id="mgVapeVg" min="0" max="100" value="78"></div>
    `;
    root.appendChild(hud);

    const status = document.createElement('p');
    status.className = 'mg-vape-status';
    status.textContent = 'Sulygink PG/VG mišinį laboratorijoje';
    root.appendChild(status);

    const actions = document.createElement('div');
    actions.className = 'mg-vape-actions';
    const btnConfirm = document.createElement('button');
    btnConfirm.type = 'button';
    btnConfirm.className = 'mg-vape-btn mg-vape-btn--primary';
    btnConfirm.textContent = 'Patvirtinti mišinį';
    actions.appendChild(btnConfirm);
    root.appendChild(actions);

    const pgEl = hud.querySelector('#mgVapePg');
    const vgEl = hud.querySelector('#mgVapeVg');
    const mixEl = hud.querySelector('#mgVapeMix');

    const syncMix = () => {
      pg = Number(pgEl.value);
      vg = Number(vgEl.value);
      const mid = (pg + vg) / 2;
      mixEl.textContent = `${Math.round(mid)}%`;
      const diff = Math.abs(mid - target);
      status.className = 'mg-vape-status' + (diff <= 8 ? ' ok' : diff <= 18 ? ' warn' : '');
      status.textContent = diff <= 8 ? 'Mišinys optimalus — galima stabilizuoti' : 'Koreguok sliderius iki žalios zonos';
    };
    pgEl.oninput = syncMix;
    vgEl.oninput = () => { sfx('gauge_tick'); syncMix(); };
    syncMix();

    hooks.setStep(1, 2, 'Sulygink skysčio mišinį');

    function drawScene(ctx, w, h) {
      drawWorkbench(ctx, w, h);
      const mid = (pg + vg) / 2;
      const hue = 180 + (mid - 50) * 1.2;
      drawFlask(ctx, w * 0.22, h * 0.58, 1.1, pg / 100, 190);
      drawFlask(ctx, w * 0.78, h * 0.58, 1.1, vg / 100, 280);
      drawBeaker(ctx, w * 0.5, h * 0.56, 1.15, mid / 100, hue);
      drawMist(ctx, w, h, mist, 0.8 + mid / 200);
    }

    bindResize(canvas, drawScene);

    function startStabilize() {
      phase = 2;
      hooks.setStep(2, 2, 'Stabilizuok mišinio viskozę');
      hud.classList.add('hidden');
      btnConfirm.classList.add('hidden');
      status.textContent = 'Laikyk SPACE adatą cyan zonoje';

      let needle = 8;
      let dir = 1.35;
      let hold = 0;
      const need = 48;
      const zoneStart = -Math.PI * 0.75 + (0.38 * Math.PI * 1.5);
      const zoneSweep = 0.22 * Math.PI * 1.5;
      let spaceDown = false;

      const onKeyDown = (ev) => {
        if (ev.code === 'Space') {
          ev.preventDefault();
          spaceDown = true;
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

      const zoneNeedleL = 38;
      const zoneNeedleW = 22;

      runLoop(() => {
        needle += dir;
        if (needle >= 96) dir = -1.35;
        if (needle <= 4) dir = 1.35;

        const inZone = needle >= zoneNeedleL && needle <= zoneNeedleL + zoneNeedleW;
        if (spaceDown && inZone) {
          hold += 1;
          if (hold % 8 === 0) sfx('bubble');
        }

        const pct = Math.min(100, (hold / need) * 100);
        if (hooks.hint) hooks.hint.textContent = `Visko stabilizacija — ${Math.round(pct)}%`;

        const ctx = canvas.getContext('2d');
        const r = canvas.parentElement.getBoundingClientRect();
        drawScene(ctx, r.width, r.height);
        drawRingGauge(ctx, r.width * 0.5, r.height * 0.52, Math.min(r.width, r.height) * 0.18, needle, zoneStart, zoneSweep, pct);

        if (hold >= need) {
          cleanup();
          sfx('success');
          if (window.MgFx) MgFx.flash('rgba(103, 232, 249, 0.35)');
          hooks.onWin({ score: 88 });
        } else if (spaceDown && !inZone) {
          cleanup();
          sfx('fail');
          if (window.MgFx) MgFx.shake(1.1);
          hooks.onFail();
        }
      });

      const timeout = setTimeout(() => {
        cleanup();
        hooks.onFail();
      }, 16000);
      cleanups.push(() => clearTimeout(timeout));
    }

    btnConfirm.onclick = () => {
      const mid = (pg + vg) / 2;
      if (Math.abs(mid - target) > 18) {
        sfx('fail');
        status.className = 'mg-vape-status bad';
        status.textContent = 'Mišinys netinkamas — bandyk dar kartą';
        if (window.MgFx) MgFx.shake(0.9);
        return;
      }
      sfx('synth');
      startStabilize();
    };
  }

  function drawBottle(ctx, cx, cy, scale, fillPct, capAngle) {
    const w = 38 * scale;
    const h = 72 * scale;
    ctx.save();
    ctx.translate(cx, cy);

    ctx.fillStyle = 'rgba(0,0,0,0.2)';
    ctx.beginPath();
    ctx.ellipse(0, h * 0.42, w * 0.85, h * 0.1, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = 'rgba(186, 230, 253, 0.55)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-w * 0.32, -h * 0.38);
    ctx.lineTo(-w * 0.38, h * 0.32);
    ctx.quadraticCurveTo(0, h * 0.42, w * 0.38, h * 0.32);
    ctx.lineTo(w * 0.32, -h * 0.38);
    ctx.closePath();
    ctx.stroke();

    const fh = h * 0.62 * clamp(fillPct, 0, 1);
    const lg = ctx.createLinearGradient(0, h * 0.3, 0, h * 0.3 - fh);
    lg.addColorStop(0, 'rgba(34, 211, 238, 0.85)');
    lg.addColorStop(1, 'rgba(165, 243, 252, 0.35)');
    ctx.fillStyle = lg;
    ctx.beginPath();
    ctx.moveTo(-w * 0.34, h * 0.28);
    ctx.lineTo(-w * 0.34, h * 0.28 - fh);
    ctx.lineTo(w * 0.34, h * 0.28 - fh);
    ctx.lineTo(w * 0.34, h * 0.28);
    ctx.closePath();
    ctx.fill();

    ctx.save();
    ctx.translate(0, -h * 0.42);
    ctx.rotate(capAngle);
    ctx.fillStyle = '#0e7490';
    ctx.fillRect(-w * 0.28, -h * 0.08, w * 0.56, h * 0.1);
    ctx.strokeStyle = '#67e8f9';
    ctx.strokeRect(-w * 0.28, -h * 0.08, w * 0.56, h * 0.1);
    ctx.restore();

    ctx.restore();
  }

  function drawDropper(ctx, x, y, scale, squeeze) {
    ctx.save();
    ctx.translate(x, y);
    ctx.strokeStyle = 'rgba(240, 249, 255, 0.7)';
    ctx.lineWidth = 2 * scale;
    ctx.beginPath();
    ctx.moveTo(0, -30 * scale);
    ctx.lineTo(0, 10 * scale);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(-8 * scale, -30 * scale);
    ctx.lineTo(8 * scale, -30 * scale);
    ctx.lineTo(4 * scale, -40 * scale);
    ctx.lineTo(-4 * scale, -40 * scale);
    ctx.closePath();
    ctx.fillStyle = `rgba(103, 232, 249, ${0.4 + squeeze * 0.4})`;
    ctx.fill();
    if (squeeze > 0.3) {
      ctx.fillStyle = 'rgba(34, 211, 238, 0.9)';
      ctx.beginPath();
      ctx.arc(0, 12 * scale, 3 * scale, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  /**
   * vape_pack — lašintuvas + sandarinimas
   */
  function runDropper(data, hooks) {
    cleanup();
    const root = mountBoard();
    if (!root) return hooks.onFail();

    const need = data.steps || 3;
    let drops = 0;
    let fill = 0;
    let phase = 'drops';
    let marker = 10;
    let dir = 2.8;
    let capStep = 0;
    let capAngle = 0;
    const mist = createMist(18);

    const { canvas } = makeStage(root);
    const status = document.createElement('p');
    status.className = 'mg-vape-status';
    status.textContent = 'Lašink tiksliai į buteliuką';
    root.appendChild(status);

    const actions = document.createElement('div');
    actions.className = 'mg-vape-actions';
    const btnDrop = document.createElement('button');
    btnDrop.type = 'button';
    btnDrop.className = 'mg-vape-btn mg-vape-btn--primary';
    btnDrop.textContent = 'Lašinti';
    actions.appendChild(btnDrop);
    root.appendChild(actions);

    hooks.setStep(1, need + 1, 'Lašink tiksliai į buteliuką');

    const zoneL = 44;
    const zoneW = 16;
    let squeezeAnim = 0;

    function drawDropPhase(ctx, w, h) {
      drawWorkbench(ctx, w, h);
      drawBottle(ctx, w * 0.52, h * 0.58, 1.2, fill / 100, capAngle);
      drawDropper(ctx, w * 0.52, h * 0.28, 1.1, squeezeAnim);

      const trackY = h * 0.82;
      const trackW = w * 0.7;
      const trackX = w * 0.15;
      ctx.fillStyle = 'rgba(8, 47, 73, 0.85)';
      ctx.fillRect(trackX, trackY, trackW, 8);
      ctx.fillStyle = 'rgba(34, 211, 238, 0.75)';
      ctx.fillRect(trackX + trackW * (zoneL / 100), trackY, trackW * (zoneW / 100), 8);
      ctx.fillStyle = '#f0f9ff';
      const mx = trackX + trackW * (marker / 100);
      ctx.beginPath();
      ctx.moveTo(mx, trackY - 6);
      ctx.lineTo(mx + 6, trackY + 14);
      ctx.lineTo(mx - 6, trackY + 14);
      ctx.closePath();
      ctx.fill();

      drawMist(ctx, w, h, mist, 0.5);
    }

    bindResize(canvas, (ctx, w, h) => {
      if (phase === 'drops') drawDropPhase(ctx, w, h);
      else drawSealPhase(ctx, w, h);
    });

    runLoop(() => {
      if (phase !== 'drops') return;
      marker += dir;
      if (marker >= 93) dir = -2.8;
      if (marker <= 7) dir = 2.8;
      squeezeAnim = Math.max(0, squeezeAnim - 0.04);
      const ctx = canvas.getContext('2d');
      const r = canvas.parentElement.getBoundingClientRect();
      drawDropPhase(ctx, r.width, r.height);
    });

    btnDrop.onclick = () => {
      if (phase !== 'drops') return;
      const ok = marker >= zoneL && marker <= zoneL + zoneW;
      if (!ok) {
        cleanup();
        sfx('fail');
        if (window.MgFx) MgFx.shake(1.2);
        hooks.onFail();
        return;
      }
      drops += 1;
      fill = Math.min(92, fill + 28);
      squeezeAnim = 1;
      sfx('drop');
      status.textContent = `Lašai ${drops} / ${need}`;
      if (drops >= need) {
        phase = 'seal';
        btnDrop.textContent = 'Užsukti dangtelį';
        hooks.setStep(2, need + 1, 'Užsandarink buteliuką');
        status.textContent = 'Paspausk dangtelio žymes iš eilės (1 → 2)';
        capStep = 0;
      }
    };

    const sealTargets = [0, Math.PI * 0.35, Math.PI * 0.7];

    function drawSealPhase(ctx, w, h) {
      drawWorkbench(ctx, w, h);
      drawBottle(ctx, w * 0.5, h * 0.55, 1.35, 0.95, capAngle);
      const cx = w * 0.5;
      const cy = h * 0.55 - 72 * 1.35 * 0.42;
      sealTargets.forEach((ang, i) => {
        const rx = cx + Math.cos(ang - Math.PI / 2) * 48;
        const ry = cy + Math.sin(ang - Math.PI / 2) * 48;
        ctx.beginPath();
        ctx.arc(rx, ry, i < capStep ? 10 : 12, 0, Math.PI * 2);
        ctx.fillStyle = i < capStep ? 'rgba(34, 211, 238, 0.9)' : 'rgba(103, 232, 249, 0.25)';
        ctx.fill();
        ctx.strokeStyle = 'rgba(240, 249, 255, 0.8)';
        ctx.stroke();
        ctx.fillStyle = '#042f3a';
        ctx.font = 'bold 11px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(String(i + 1), rx, ry + 4);
      });
    }

    canvas.onclick = (ev) => {
      if (phase !== 'seal') return;
      const rect = canvas.getBoundingClientRect();
      const x = ev.clientX - rect.left;
      const y = ev.clientY - rect.top;
      const w = rect.width;
      const h = rect.height;
      const cx = w * 0.5;
      const cy = h * 0.55 - 72 * 1.35 * 0.42;
      const ang = sealTargets[capStep];
      const tx = cx + Math.cos(ang - Math.PI / 2) * 48;
      const ty = cy + Math.sin(ang - Math.PI / 2) * 48;
      const dist = Math.hypot(x - tx, y - ty);
      if (dist > 22) return;
      capStep += 1;
      capAngle += Math.PI * 0.22;
      sfx('seal');
      if (window.MgFx) MgFx.flash('rgba(103, 232, 249, 0.3)');
      const ctx = canvas.getContext('2d');
      drawSealPhase(ctx, w, h);
      if (capStep >= sealTargets.length) {
        cleanup();
        sfx('success');
        hooks.onWin({ score: 90 });
      } else {
        status.textContent = `Užsukta ${capStep} / ${sealTargets.length}`;
      }
    };

    const timeout = setTimeout(() => {
      cleanup();
      hooks.onFail();
    }, 22000 + need * 2000);
    cleanups.push(() => clearTimeout(timeout));
  }

  return { runBlend, runDropper, cleanup };
})();
