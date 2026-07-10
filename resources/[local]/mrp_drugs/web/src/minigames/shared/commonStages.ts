import { Container, Graphics, Point } from 'pixi.js';
import gsap from 'gsap';
import { DESIGN_H, DESIGN_W } from '@/engine/pixi/stage';
import { PALETTE } from '@/engine/pixi/theme';
import { buildHoldGauge, label } from '@/engine/pixi/widgets';
import { createHold } from '@/engine/input/input';
import { Audio } from '@/engine/audio/audio';
import { StationAbort } from '../types';
import type { StationRuntime } from './createRuntime';
import { watchAbort } from './createRuntime';

export interface StageMeta {
  index: number;
  total: number;
  title: string;
  hint: string;
}

function announce(rt: StationRuntime, meta: StageMeta) {
  rt.cb.onStage(meta);
}

/** Hold needle in drifting zone for durationMs. */
export function holdGauge(
  rt: StationRuntime,
  meta: StageMeta,
  durationMs: number,
  accent = PALETTE.neon,
  opts?: { rise?: number; fall?: number; zoneW?: number; drift?: number },
): Promise<number> {
  announce(rt, meta);
  return new Promise<number>((resolve, reject) => {
    const gauge = buildHoldGauge({
      x: DESIGN_W * 0.5 - 280,
      y: DESIGN_H * 0.48,
      w: 560,
      h: 34,
      rise: opts?.rise ?? 0.58,
      fall: opts?.fall ?? 0.52,
      zoneW: opts?.zoneW ?? 0.2,
      drift: opts?.drift ?? 0.32,
      accent,
    });
    rt.layer.addChild(gauge.view);
    const hold = createHold((held) => {
      gauge.setActive(held);
      if (held) Audio.play('valve');
    });
    rt.addDisposer(hold.dispose);
    let elapsed = 0;
    const off = rt.stage.onTick((dt) => {
      if (rt.aborted) return;
      gauge.update(dt);
      elapsed += dt;
      if (elapsed >= durationMs) {
        off();
        const acc = gauge.accuracy();
        gauge.destroy();
        Audio.play('success');
        resolve(acc);
      }
    });
    rt.addDisposer(off);
    rt.addDisposer(() => gauge.destroy());
    watchAbort(rt, reject);
  });
}

/** Vertical fill — hold to fill, release in green band. */
export function fillBand(
  rt: StationRuntime,
  meta: StageMeta,
  opts: { bandLo?: number; bandHi?: number; color?: number; label?: string },
): Promise<number> {
  announce(rt, meta);
  const bandLo = opts.bandLo ?? 0.72;
  const bandHi = opts.bandHi ?? 0.9;
  const liquidColor = opts.color ?? PALETTE.amber;
  return new Promise<number>((resolve, reject) => {
    const cx = DESIGN_W * 0.5;
    const vesselY = DESIGN_H * 0.22;
    const vesselH = DESIGN_H * 0.42;
    const vesselW = 100;
    const body = new Graphics();
    body.roundRect(cx - vesselW / 2, vesselY, vesselW, vesselH, 14).fill({ color: 0x0d1117, alpha: 0.55 });
    body.roundRect(cx - vesselW / 2, vesselY, vesselW, vesselH, 14).stroke({ color: PALETTE.glass, width: 2, alpha: 0.55 });
    rt.layer.addChild(body);
    const yFor = (f: number) => vesselY + vesselH * (1 - f);
    const band = new Graphics();
    band.rect(cx - vesselW / 2 - 20, yFor(bandHi), vesselW + 40, vesselH * (bandHi - bandLo));
    band.fill({ color: PALETTE.green, alpha: 0.2 });
    rt.layer.addChild(band);
    const oil = new Graphics();
    rt.layer.addChild(oil);
    let fill = 0;
    let released = false;
    const hold = createHold((held) => {
      if (held) Audio.play('pour');
      if (!held && fill > 0.05 && !released) {
        released = true;
        done();
      }
    });
    rt.addDisposer(hold.dispose);
    const off = rt.stage.onTick((dt) => {
      if (rt.aborted || released) return;
      if (hold.isHeld()) fill = Math.min(1.08, fill + (dt / 1000) * 0.32);
      oil.clear();
      const fh = (vesselH - 8) * Math.min(1, fill);
      oil.roundRect(cx - vesselW / 2 + 4, vesselY + vesselH - 4 - fh, vesselW - 8, fh, 8);
      oil.fill({ color: fill > 1 ? PALETTE.red : liquidColor, alpha: 0.75 });
      if (fill >= 1.08) {
        released = true;
        done();
      }
    });
    rt.addDisposer(off);
    function done() {
      off();
      let acc: number;
      if (fill >= bandLo && fill <= bandHi) {
        acc = 1 - Math.abs(fill - (bandLo + bandHi) / 2) / ((bandHi - bandLo) / 2) * 0.12;
        Audio.play('success');
      } else {
        rt.tracker.addMistake();
        const dist = fill < bandLo ? bandLo - fill : fill - bandHi;
        acc = Math.max(0.12, 0.55 - dist);
        Audio.play('warn');
      }
      resolve(acc);
    }
    watchAbort(rt, reject);
  });
}

/** Tap N targets in sequence (valves, buttons). */
export function tapSequence(
  rt: StationRuntime,
  meta: StageMeta,
  count: number,
  accent = PALETTE.neon,
): Promise<number> {
  announce(rt, meta);
  return new Promise<number>((resolve, reject) => {
    const spots: { x: number; y: number }[] = [];
    const cols = Math.min(count, 4);
    for (let i = 0; i < count; i++) {
      spots.push({
        x: DESIGN_W * 0.22 + (i % cols) * 140,
        y: DESIGN_H * 0.32 + Math.floor(i / cols) * 100,
      });
    }
    let idx = 0;
    let mistakes = 0;
    const hint = label(`1 / ${count}`, 18, accent);
    hint.anchor.set(0.5);
    hint.position.set(DESIGN_W / 2, DESIGN_H * 0.2);
    rt.layer.addChild(hint);
    const buttons: Graphics[] = [];
    spots.forEach((s, i) => {
      const g = new Graphics();
      g.roundRect(-36, -36, 72, 72, 12).fill({ color: i === 0 ? accent : PALETTE.metal, alpha: i === 0 ? 0.9 : 0.5 });
      g.position.set(s.x, s.y);
      g.eventMode = 'static';
      g.cursor = 'pointer';
      g.on('pointertap', () => {
        if (i !== idx) {
          mistakes++;
          rt.tracker.addMistake();
          Audio.play('warn');
          gsap.to(g, { x: s.x + 6, duration: 0.05, yoyo: true, repeat: 3 });
          return;
        }
        Audio.play('click');
        g.eventMode = 'none';
        g.cursor = 'default';
        g.clear();
        g.roundRect(-36, -36, 72, 72, 12).fill({ color: PALETTE.green, alpha: 0.7 });
        idx++;
        if (idx < count) {
          buttons[idx].clear();
          buttons[idx].roundRect(-36, -36, 72, 72, 12).fill({ color: accent, alpha: 0.9 });
          hint.text = `${idx + 1} / ${count}`;
        } else {
          const acc = Math.max(0.5, 1 - mistakes * 0.12);
          Audio.play('success');
          resolve(acc);
        }
      });
      rt.layer.addChild(g);
      buttons.push(g);
    });
    watchAbort(rt, reject);
  });
}

/** Drag tool over grid cells. */
export function scrapeGrid(
  rt: StationRuntime,
  meta: StageMeta,
  opts: { cols?: number; rows?: number; cellColor?: number },
): Promise<number> {
  announce(rt, meta);
  const cols = opts.cols ?? 12;
  const rows = opts.rows ?? 7;
  const cellColor = opts.cellColor ?? 0x3b6b2f;
  return new Promise<number>((resolve, reject) => {
    const trayX = DESIGN_W * 0.26;
    const trayY = DESIGN_H * 0.28;
    const trayW = DESIGN_W * 0.48;
    const trayH = DESIGN_H * 0.32;
    const tray = new Graphics();
    tray.roundRect(trayX, trayY, trayW, trayH, 14).fill({ color: 0x1c2129 });
    tray.roundRect(trayX, trayY, trayW, trayH, 14).stroke({ color: PALETTE.metalLight, width: 2 });
    rt.layer.addChild(tray);
    const cellW = trayW / cols;
    const cellH = trayH / rows;
    const cells: Graphics[] = [];
    const covered: boolean[] = [];
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        const g = new Graphics();
        g.roundRect(trayX + c * cellW + 2, trayY + r * cellH + 2, cellW - 4, cellH - 4, 4);
        g.fill({ color: cellColor, alpha: 0.75 });
        rt.layer.addChild(g);
        cells.push(g);
        covered.push(false);
      }
    }
    let done = 0;
    const tool = new Graphics();
    tool.roundRect(-30, -10, 60, 20, 5).fill({ color: PALETTE.metalLight });
    tool.position.set(trayX + trayW / 2, trayY + trayH + 36);
    rt.layer.addChild(tool);
    let dragging = false;
    const st = rt.stage.app!.stage;
    st.eventMode = 'static';
    st.hitArea = { contains: () => true } as never;
    const worldPoint = (g: Point) => rt.stage.world.toLocal(g);
    const onDown = () => { dragging = true; };
    const onUp = () => { dragging = false; };
    const onMove = (e: { global: Point }) => {
      const p = worldPoint(e.global);
      tool.position.set(p.x, Math.max(trayY + 8, Math.min(trayY + trayH - 8, p.y)));
      if (!dragging) return;
      for (let i = 0; i < cells.length; i++) {
        if (covered[i]) continue;
        const c = i % cols;
        const r = Math.floor(i / cols);
        const cx = trayX + c * cellW + cellW / 2;
        const cy = trayY + r * cellH + cellH / 2;
        if (Math.abs(p.x - cx) < cellW && Math.abs(p.y - cy) < cellH) {
          covered[i] = true;
          done++;
          gsap.to(cells[i], { alpha: 0, duration: 0.2 });
          if (done >= cells.length * 0.9) {
            cleanup();
            Audio.play('success');
            resolve(done / cells.length);
          }
        }
      }
    };
    st.on('pointerdown', onDown);
    st.on('pointerup', onUp);
    st.on('pointerupoutside', onUp);
    st.on('globalpointermove', onMove);
    const cleanup = () => {
      st.off('pointerdown', onDown);
      st.off('pointerup', onUp);
      st.off('pointerupoutside', onUp);
      st.off('globalpointermove', onMove);
    };
    rt.addDisposer(cleanup);
    watchAbort(rt, reject);
  });
}

/** Tap items into box (dynamic quantity). */
export function packIntoBox(
  rt: StationRuntime,
  meta: StageMeta,
  qty: number,
  itemColor: number,
): Promise<number> {
  const n = Math.max(1, Math.min(qty || 1, 12));
  announce(rt, { ...meta, hint: meta.hint || `Sudėk ${n} vienetų į dėžutę` });
  return new Promise<number>((resolve, reject) => {
    const boxX = DESIGN_W * 0.6;
    const boxY = DESIGN_H * 0.3;
    const boxW = 300;
    const boxH = 220;
    const box = new Graphics();
    box.roundRect(boxX, boxY, boxW, boxH, 12).fill({ color: 0x2a2117 });
    box.roundRect(boxX, boxY, boxW, boxH, 12).stroke({ color: itemColor, width: 2, alpha: 0.5 });
    rt.layer.addChild(box);
    let placed = 0;
    const cols = 4;
    for (let i = 0; i < n; i++) {
      const cont = new Container();
      const g = new Graphics();
      g.roundRect(-16, -28, 32, 56, 8).fill({ color: itemColor, alpha: 0.85 });
      cont.addChild(g);
      cont.position.set(DESIGN_W * 0.12 + (i % 5) * 58, DESIGN_H * 0.34 + Math.floor(i / 5) * 82);
      cont.eventMode = 'static';
      cont.cursor = 'pointer';
      const tx = boxX + 36 + (i % cols) * 64;
      const ty = boxY + 44 + Math.floor(i / cols) * 76;
      cont.on('pointertap', () => {
        if (cont.eventMode === 'none') return;
        cont.eventMode = 'none';
        Audio.play('place');
        gsap.to(cont.position, {
          x: tx,
          y: ty,
          duration: 0.38,
          ease: 'back.out(1.5)',
          onComplete: () => {
            placed++;
            if (placed >= n) {
              Audio.play('success');
              resolve(1);
            }
          },
        });
      });
      rt.layer.addChild(cont);
    }
    watchAbort(rt, reject);
  });
}

/** Click good spots, avoid bad (sorting). */
export function pickGoodSpots(
  rt: StationRuntime,
  meta: StageMeta,
  goodCount: number,
  badCount: number,
  goodColor: number,
): Promise<number> {
  announce(rt, meta);
  return new Promise<number>((resolve, reject) => {
    let picked = 0;
    let mistakes = 0;
    const spots: { x: number; y: number; good: boolean }[] = [];
    for (let i = 0; i < goodCount + badCount; i++) {
      spots.push({
        x: DESIGN_W * 0.2 + Math.random() * DESIGN_W * 0.6,
        y: DESIGN_H * 0.28 + Math.random() * DESIGN_H * 0.28,
        good: i < goodCount,
      });
    }
    spots.forEach((s) => {
      const g = new Graphics();
      g.circle(0, 0, 22).fill({ color: s.good ? goodColor : 0x5c4033, alpha: 0.85 });
      g.position.set(s.x, s.y);
      g.eventMode = 'static';
      g.cursor = 'pointer';
      g.on('pointertap', () => {
        if (g.eventMode === 'none') return;
        g.eventMode = 'none';
        if (s.good) {
          picked++;
          Audio.play('click');
          gsap.to(g, { alpha: 0, scale: 0.5, duration: 0.25 });
          if (picked >= goodCount) {
            const acc = Math.max(0.4, 1 - mistakes * 0.15);
            Audio.play('success');
            resolve(acc);
          }
        } else {
          mistakes++;
          rt.tracker.addMistake();
          Audio.play('fail');
          gsap.to(g, { alpha: 0.3, duration: 0.2 });
        }
      });
      rt.layer.addChild(g);
    });
    watchAbort(rt, reject);
  });
}

/** Rhythm taps — hit when indicator in zone. */
export function rhythmTaps(
  rt: StationRuntime,
  meta: StageMeta,
  need: number,
  accent: number,
): Promise<number> {
  announce(rt, meta);
  return new Promise<number>((resolve, reject) => {
    let hits = 0;
    let misses = 0;
    let pos = 0;
    let dir = 1;
    const zoneL = 0.42;
    const zoneR = 0.58;
    const track = new Graphics();
    track.roundRect(DESIGN_W * 0.5 - 250, DESIGN_H * 0.5, 500, 28, 14).fill({ color: 0x0a0e14 });
    rt.layer.addChild(track);
    const zone = new Graphics();
    zone.roundRect(DESIGN_W * 0.5 - 250 + 500 * zoneL, DESIGN_H * 0.5 + 4, 500 * (zoneR - zoneL), 20, 10);
    zone.fill({ color: accent, alpha: 0.35 });
    rt.layer.addChild(zone);
    const needle = new Graphics();
    rt.layer.addChild(needle);
    const drawNeedle = () => {
      needle.clear();
      const nx = DESIGN_W * 0.5 - 250 + 500 * pos;
      needle.roundRect(nx - 4, DESIGN_H * 0.5 - 8, 8, 44, 4).fill({ color: PALETTE.text });
    };
    drawNeedle();
    const onKey = (e: KeyboardEvent) => {
      if (e.code !== 'Space') return;
      e.preventDefault();
      if (pos >= zoneL && pos <= zoneR) {
        hits++;
        Audio.play('tick');
      } else {
        misses++;
        rt.tracker.addMistake();
        Audio.play('warn');
      }
      if (hits >= need) {
        window.removeEventListener('keydown', onKey);
        off();
        resolve(Math.max(0.45, 1 - misses * 0.1));
      }
    };
    window.addEventListener('keydown', onKey);
    rt.addDisposer(() => window.removeEventListener('keydown', onKey));
    const off = rt.stage.onTick((dt) => {
      if (rt.aborted) return;
      pos += dir * (dt / 1000) * 0.85;
      if (pos >= 1) { pos = 1; dir = -1; }
      if (pos <= 0) { pos = 0; dir = 1; }
      drawNeedle();
    });
    rt.addDisposer(off);
    watchAbort(rt, reject);
  });
}

/** Catch falling items by clicking them. */
export function catchFalling(
  rt: StationRuntime,
  meta: StageMeta,
  need: number,
  itemColor: number,
): Promise<number> {
  announce(rt, meta);
  return new Promise<number>((resolve, reject) => {
    let caught = 0;
    let missed = 0;
    const spawn = () => {
      if (rt.aborted || caught >= need) return;
      const g = new Graphics();
      g.circle(0, 0, 18).fill({ color: itemColor, alpha: 0.9 });
      g.position.set(DESIGN_W * 0.15 + Math.random() * DESIGN_W * 0.7, DESIGN_H * 0.18);
      g.eventMode = 'static';
      g.cursor = 'pointer';
      let vy = 0.12 + Math.random() * 0.08;
      const off = rt.stage.onTick((dt) => {
        g.y += vy * dt;
        if (g.y > DESIGN_H * 0.7) {
          off();
          missed++;
          rt.tracker.addMistake();
          g.destroy();
          if (caught + missed >= need + 3) {
            resolve(Math.max(0.35, caught / need - missed * 0.1));
          } else spawn();
        }
      });
      g.on('pointertap', () => {
        off();
        caught++;
        Audio.play('click');
        gsap.to(g, { alpha: 0, scale: 0.3, duration: 0.2, onComplete: () => g.destroy() });
        if (caught >= need) {
          Audio.play('success');
          resolve(Math.max(0.5, 1 - missed * 0.12));
        } else spawn();
      });
      rt.layer.addChild(g);
    };
    spawn();
    watchAbort(rt, reject);
  });
}

/** Multi-component blend — stop each slider in zone. */
export function blendComponents(
  rt: StationRuntime,
  meta: StageMeta,
  components: number,
  colors: number[],
): Promise<number> {
  announce(rt, meta);
  return new Promise<number>((resolve, reject) => {
    let comp = 0;
    let totalAcc = 0;
    const runOne = () => {
      if (comp >= components) {
        resolve(totalAcc / components);
        return;
      }
      const color = colors[comp % colors.length];
      let pos = Math.random() * 0.5 + 0.25;
      const target = 0.35 + Math.random() * 0.3;
      const tol = 0.08;
      const track = new Graphics();
      track.roundRect(DESIGN_W * 0.5 - 220, DESIGN_H * 0.42, 440, 24, 12).fill({ color: 0x0a0e14 });
      rt.layer.addChild(track);
      const marker = new Graphics();
      marker.roundRect(DESIGN_W * 0.5 - 220 + 440 * (target - tol), DESIGN_H * 0.42 + 2, 440 * tol * 2, 20, 8);
      marker.fill({ color: PALETTE.green, alpha: 0.35 });
      rt.layer.addChild(marker);
      const knob = new Graphics();
      knob.circle(0, 0, 14).fill({ color });
      knob.position.set(DESIGN_W * 0.5 - 220 + 440 * pos, DESIGN_H * 0.54);
      knob.eventMode = 'static';
      knob.cursor = 'pointer';
      rt.layer.addChild(knob);
      const onMove = (e: { global: Point }) => {
        const p = rt.stage.world.toLocal(e.global);
        pos = Math.max(0, Math.min(1, (p.x - (DESIGN_W * 0.5 - 220)) / 440));
        knob.x = DESIGN_W * 0.5 - 220 + 440 * pos;
      };
      const st = rt.stage.app!.stage;
      st.on('pointermove', onMove);
      const onUp = () => {
        st.off('pointermove', onMove);
        st.off('pointerup', onUp);
        const dist = Math.abs(pos - target);
        const acc = dist <= tol ? 1 - dist / tol * 0.2 : Math.max(0.2, 0.5 - dist);
        if (dist > tol) rt.tracker.addMistake();
        totalAcc += acc;
        track.destroy();
        marker.destroy();
        knob.destroy();
        comp++;
        Audio.play(dist <= tol ? 'success' : 'warn');
        runOne();
      };
      st.on('pointerup', onUp);
      rt.addDisposer(() => {
        st.off('pointermove', onMove);
        st.off('pointerup', onUp);
      });
    };
    runOne();
    watchAbort(rt, reject);
  });
}

/** Fold foil — repeated taps. */
export function multiTapSeal(
  rt: StationRuntime,
  meta: StageMeta,
  taps: number,
  accent: number,
): Promise<number> {
  announce(rt, meta);
  return new Promise<number>((resolve, reject) => {
    let done = 0;
    const bag = new Graphics();
    bag.roundRect(DESIGN_W * 0.5 - 80, DESIGN_H * 0.35, 160, 120, 10).fill({ color: 0x1a1f28, alpha: 0.8 });
    bag.roundRect(DESIGN_W * 0.5 - 80, DESIGN_H * 0.35, 160, 120, 10).stroke({ color: accent, width: 2, alpha: 0.6 });
    bag.eventMode = 'static';
    bag.cursor = 'pointer';
    const prog = label(`0 / ${taps}`, 20, accent);
    prog.anchor.set(0.5);
    prog.position.set(DESIGN_W / 2, DESIGN_H * 0.58);
    rt.layer.addChild(bag);
    rt.layer.addChild(prog);
    bag.on('pointertap', () => {
      done++;
      Audio.play('seal');
      prog.text = `${done} / ${taps}`;
      gsap.to(bag.scale, { x: 1.04, y: 0.96, duration: 0.08, yoyo: true, repeat: 1 });
      if (done >= taps) {
        bag.eventMode = 'none';
        Audio.play('success');
        resolve(Math.max(0.7, 1 - rt.tracker.mistakes * 0.05));
      }
    });
    watchAbort(rt, reject);
  });
}
