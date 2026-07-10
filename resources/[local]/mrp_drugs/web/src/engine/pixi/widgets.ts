import { Container, Graphics, Text } from 'pixi.js';
import { DESIGN_H, DESIGN_W } from './stage';
import { PALETTE, textStyle } from './theme';

// Reusable Pixi building blocks. Objects are drawn with Graphics as clearly
// marked PLACEHOLDER visuals; swap for sprite textures (see ASSET_REQUIREMENTS)
// without changing the interaction logic that lives in the stations.

/** Dark room + directional light + table surface. Fills the design area. */
export function buildWorkbench(world: Container, accent = PALETTE.neon): Container {
  const bg = new Graphics();
  // vertical gradient-ish backdrop using stacked rects
  const steps = 24;
  for (let i = 0; i < steps; i++) {
    const t = i / (steps - 1);
    const r = lerpChannel(PALETTE.bgTop, PALETTE.bgBottom, t, 16);
    const g = lerpChannel(PALETTE.bgTop, PALETTE.bgBottom, t, 8);
    const b = lerpChannel(PALETTE.bgTop, PALETTE.bgBottom, t, 0);
    bg.rect(0, (DESIGN_H / steps) * i, DESIGN_W, DESIGN_H / steps + 1);
    bg.fill({ r, g, b, a: 1 });
  }
  world.addChild(bg);

  // directional light cone from top
  const light = new Graphics();
  light.moveTo(DESIGN_W * 0.5, -80);
  light.lineTo(DESIGN_W * 0.16, DESIGN_H * 0.95);
  light.lineTo(DESIGN_W * 0.84, DESIGN_H * 0.95);
  light.closePath();
  light.fill({ color: accent, alpha: 0.05 });
  world.addChild(light);

  // table surface
  const table = new Graphics();
  const topY = DESIGN_H * 0.62;
  table.rect(0, topY, DESIGN_W, DESIGN_H - topY);
  table.fill({ color: PALETTE.tableTop });
  table.rect(0, topY, DESIGN_W, 6);
  table.fill({ color: PALETTE.metalLight, alpha: 0.25 });
  table.rect(0, topY + 6, DESIGN_W, 3);
  table.fill({ color: PALETTE.tableEdge });
  world.addChild(table);

  // vignette
  const vig = new Graphics();
  vig.rect(0, 0, DESIGN_W, DESIGN_H).fill({ color: 0x000000, alpha: 0 });
  vig.rect(0, 0, DESIGN_W, 60).fill({ color: 0x000000, alpha: 0.35 });
  vig.rect(0, DESIGN_H - 60, DESIGN_W, 60).fill({ color: 0x000000, alpha: 0.35 });
  world.addChild(vig);

  const layer = new Container();
  world.addChild(layer);
  return layer;
}

function lerpChannel(a: number, b: number, t: number, shift: number): number {
  const ca = ((a >> shift) & 0xff) / 255;
  const cb = ((b >> shift) & 0xff) / 255;
  return ca + (cb - ca) * t;
}

/** Rounded panel used for HUD chips / small info cards. */
export function panel(w: number, h: number, radius = 12, fill = 0x0f141c, alpha = 0.85): Graphics {
  const g = new Graphics();
  g.roundRect(0, 0, w, h, radius).fill({ color: fill, alpha });
  g.roundRect(0, 0, w, h, radius).stroke({ color: PALETTE.metalLight, width: 1, alpha: 0.4 });
  return g;
}

export function label(str: string, size = 20, color = PALETTE.text, weight = '600'): Text {
  const t = new Text({ text: str, style: textStyle(size, color, weight) });
  return t;
}

export interface GaugeHandle {
  view: Container;
  /** Call each frame; returns true while inside zone. */
  update: (dtMs: number) => boolean;
  /** Fraction of time spent inside the safe zone, 0..1. */
  accuracy: () => number;
  setActive: (a: boolean) => void;
  destroy: () => void;
}

/**
 * Horizontal "hold the needle in the moving safe zone" gauge.
 * Player holds a key/pointer (active=true) to push the needle right; releasing
 * lets it fall. The safe zone drifts. Accuracy = time inside zone / total time.
 */
export function buildHoldGauge(opts: {
  x: number;
  y: number;
  w: number;
  h: number;
  rise: number; // per second when active
  fall: number; // per second when idle
  zoneW: number; // width fraction 0..1
  drift: number; // zone drift speed
  accent?: number;
}): GaugeHandle {
  const accent = opts.accent ?? PALETTE.neon;
  const view = new Container();
  view.position.set(opts.x, opts.y);

  const track = new Graphics();
  track.roundRect(0, 0, opts.w, opts.h, opts.h / 2).fill({ color: 0x0a0e14 });
  track.roundRect(0, 0, opts.w, opts.h, opts.h / 2).stroke({ color: PALETTE.metal, width: 2 });
  view.addChild(track);

  const zone = new Graphics();
  view.addChild(zone);
  const needle = new Graphics();
  view.addChild(needle);

  let value = 0; // 0..1 position of needle
  let zonePos = 0.5;
  let zoneDir = 1;
  let active = false;
  let inTime = 0;
  let totalTime = 0;

  const drawZone = () => {
    const zx = (zonePos - opts.zoneW / 2) * opts.w;
    const zw = opts.zoneW * opts.w;
    zone.clear();
    zone.roundRect(Math.max(0, zx), 3, Math.min(zw, opts.w), opts.h - 6, (opts.h - 6) / 2);
    zone.fill({ color: accent, alpha: 0.28 });
    zone.roundRect(Math.max(0, zx), 3, Math.min(zw, opts.w), opts.h - 6, (opts.h - 6) / 2);
    zone.stroke({ color: accent, width: 2, alpha: 0.9 });
  };

  const drawNeedle = (inside: boolean) => {
    const nx = value * opts.w;
    needle.clear();
    needle.roundRect(nx - 4, -6, 8, opts.h + 12, 4);
    needle.fill({ color: inside ? accent : PALETTE.red });
  };

  drawZone();
  drawNeedle(false);

  return {
    view,
    setActive: (a) => (active = a),
    accuracy: () => (totalTime > 0 ? inTime / totalTime : 0),
    update: (dtMs) => {
      const dt = dtMs / 1000;
      totalTime += dt;
      value += (active ? opts.rise : -opts.fall) * dt;
      value = Math.max(0, Math.min(1, value));
      zonePos += zoneDir * opts.drift * dt;
      if (zonePos > 1 - opts.zoneW / 2) {
        zonePos = 1 - opts.zoneW / 2;
        zoneDir = -1;
      }
      if (zonePos < opts.zoneW / 2) {
        zonePos = opts.zoneW / 2;
        zoneDir = 1;
      }
      const inside = Math.abs(value - zonePos) <= opts.zoneW / 2;
      if (inside) inTime += dt;
      drawZone();
      drawNeedle(inside);
      return inside;
    },
    destroy: () => view.destroy({ children: true }),
  };
}
