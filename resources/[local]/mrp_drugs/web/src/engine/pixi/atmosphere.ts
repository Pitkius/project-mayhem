import { Container, Graphics } from 'pixi.js';
import { DESIGN_H, DESIGN_W } from './stage';
import type { DrugTheme } from '@/config/drugThemes';

export interface AtmosphereHandle {
  layer: Container;
  /** Call each frame for ambient particles / flicker */
  tick: (dtMs: number) => void;
  destroy: () => void;
}

interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  max: number;
  size: number;
  g: Graphics;
}

/** Unique room + table + lighting per drug theme (Mayhem underground style). */
export function buildDrugAtmosphere(world: Container, theme: DrugTheme): AtmosphereHandle {
  const layer = new Container();
  world.addChild(layer);

  // ── Backdrop gradient ──
  const bg = new Graphics();
  const steps = 28;
  for (let i = 0; i < steps; i++) {
    const t = i / (steps - 1);
    const r = lerp(theme.bgTop, theme.bgBottom, t, 16);
    const g = lerp(theme.bgTop, theme.bgBottom, t, 8);
    const b = lerp(theme.bgTop, theme.bgBottom, t, 0);
    bg.rect(0, (DESIGN_H / steps) * i, DESIGN_W, DESIGN_H / steps + 1);
    bg.fill({ r, g, b, a: 1 });
  }
  layer.addChild(bg);

  // ── Mood-specific wall details ──
  const decor = new Graphics();
  drawMoodDecor(decor, theme);
  layer.addChild(decor);

  // ── Directional key light ──
  const light = new Graphics();
  light.moveTo(DESIGN_W * 0.5, -60);
  light.lineTo(DESIGN_W * 0.12, DESIGN_H * 0.92);
  light.lineTo(DESIGN_W * 0.88, DESIGN_H * 0.92);
  light.closePath();
  light.fill({ color: theme.light, alpha: moodLightAlpha(theme.mood) });
  layer.addChild(light);

  // ── Table surface (material varies) ──
  const tableY = tableTopY(theme.mood);
  const table = new Graphics();
  table.rect(0, tableY, DESIGN_W, DESIGN_H - tableY);
  table.fill({ color: theme.table });
  if (theme.mood === 'copper_still' || theme.mood === 'dirty_warm') {
    // wood grain lines
    for (let i = 0; i < 12; i++) {
      table.moveTo(0, tableY + 20 + i * 18);
      table.lineTo(DESIGN_W, tableY + 24 + i * 18);
      table.stroke({ color: theme.tableEdge, width: 1, alpha: 0.15 });
    }
  }
  if (theme.mood === 'pharma') {
    table.rect(0, tableY, DESIGN_W, 4).fill({ color: theme.accent2, alpha: 0.3 });
  }
  table.rect(0, tableY, DESIGN_W, 5).fill({ color: theme.tableEdge, alpha: 0.5 });
  layer.addChild(table);

  // ── Edge vignette ──
  const vig = new Graphics();
  vig.rect(0, 0, DESIGN_W, 70).fill({ color: 0x000000, alpha: 0.4 });
  vig.rect(0, DESIGN_H - 80, DESIGN_W, 80).fill({ color: 0x000000, alpha: 0.45 });
  layer.addChild(vig);

  // ── Ambient particles ──
  const particleLayer = new Container();
  layer.addChild(particleLayer);
  const particles: Particle[] = [];
  const maxP = particleCount(theme.mood);

  function spawnParticle() {
    if (particles.length >= maxP) return;
    const g = new Graphics();
    const size = 1.5 + Math.random() * 3;
    g.circle(0, 0, size).fill({ color: theme.particle, alpha: 0.35 + Math.random() * 0.35 });
    const p: Particle = {
      x: Math.random() * DESIGN_W,
      y: tableY - 20 - Math.random() * (DESIGN_H * 0.45),
      vx: (Math.random() - 0.5) * 0.04,
      vy: particleVy(theme.mood),
      life: 0,
      max: 2000 + Math.random() * 4000,
      size,
      g,
    };
    g.position.set(p.x, p.y);
    particleLayer.addChild(g);
    particles.push(p);
  }

  for (let i = 0; i < maxP; i++) spawnParticle();

  let flicker = 0;
  const tick = (dtMs: number) => {
    flicker += dtMs;
    if (theme.mood === 'electric' && flicker % 800 < 40) {
      light.alpha = 0.12 + Math.random() * 0.08;
    }
    if (theme.mood === 'dirty_warm') {
      light.alpha = moodLightAlpha(theme.mood) + Math.sin(flicker * 0.002) * 0.02;
    }
    for (let i = particles.length - 1; i >= 0; i--) {
      const p = particles[i];
      p.life += dtMs;
      p.x += p.vx * dtMs;
      p.y += p.vy * dtMs;
      p.g.position.set(p.x, p.y);
      p.g.alpha = Math.max(0, 1 - p.life / p.max);
      if (p.life >= p.max) {
        particleLayer.removeChild(p.g);
        p.g.destroy();
        particles.splice(i, 1);
        spawnParticle();
      }
    }
    if (Math.random() < 0.02) spawnParticle();
  };

  const interactLayer = new Container();
  layer.addChild(interactLayer);

  return {
    layer: interactLayer,
    tick,
    destroy: () => {
      particles.forEach((p) => p.g.destroy());
      layer.destroy({ children: true });
    },
  };
}

function lerp(a: number, b: number, t: number, shift: number): number {
  const ca = ((a >> shift) & 0xff) / 255;
  const cb = ((b >> shift) & 0xff) / 255;
  return ca + (cb - ca) * t;
}

function tableTopY(mood: DrugTheme['mood']): number {
  if (mood === 'organic') return DESIGN_H * 0.58;
  if (mood === 'copper_still') return DESIGN_H * 0.6;
  return DESIGN_H * 0.62;
}

function moodLightAlpha(mood: DrugTheme['mood']): number {
  switch (mood) {
    case 'dirty_warm': return 0.04;
    case 'cold_lux': return 0.07;
    case 'pharma': return 0.06;
    case 'electric': return 0.08;
    default: return 0.05;
  }
}

function particleCount(mood: DrugTheme['mood']): number {
  switch (mood) {
    case 'copper_still': return 18;
    case 'clean_cyan': return 14;
    case 'organic':
    case 'forest': return 16;
    case 'crystal': return 12;
    default: return 10;
  }
}

function particleVy(mood: DrugTheme['mood']): number {
  switch (mood) {
    case 'copper_still': return -0.06 - Math.random() * 0.04; // steam up
    case 'clean_cyan': return -0.03;
    case 'dirty_warm': return 0.02; // drip down
    case 'electric': return (Math.random() - 0.5) * 0.06;
    default: return -0.02 - Math.random() * 0.03;
  }
}

function drawMoodDecor(g: Graphics, theme: DrugTheme) {
  const accent = theme.accent;
  switch (theme.mood) {
    case 'neon_lab':
      g.rect(DESIGN_W * 0.04, DESIGN_H * 0.08, 3, DESIGN_H * 0.35).fill({ color: accent, alpha: 0.25 });
      g.rect(DESIGN_W * 0.96, DESIGN_H * 0.12, 3, DESIGN_H * 0.28).fill({ color: theme.accent2, alpha: 0.2 });
      break;
    case 'copper_still':
      g.circle(DESIGN_W * 0.12, DESIGN_H * 0.2, 40).stroke({ color: 0xb45309, width: 2, alpha: 0.2 });
      g.circle(DESIGN_W * 0.88, DESIGN_H * 0.18, 30).stroke({ color: 0x92400e, width: 1, alpha: 0.15 });
      break;
    case 'clean_cyan':
      for (let i = 0; i < 5; i++) {
        g.roundRect(DESIGN_W * 0.06 + i * 28, DESIGN_H * 0.1, 20, 14, 3)
          .fill({ color: accent, alpha: 0.08 + i * 0.02 });
      }
      break;
    case 'organic':
      g.ellipse(DESIGN_W * 0.1, DESIGN_H * 0.25, 50, 30).fill({ color: 0x166534, alpha: 0.15 });
      g.ellipse(DESIGN_W * 0.9, DESIGN_H * 0.22, 40, 25).fill({ color: 0x15803d, alpha: 0.12 });
      break;
    case 'dirty_warm':
      for (let i = 0; i < 8; i++) {
        g.circle(DESIGN_W * (0.1 + i * 0.1), DESIGN_H * (0.15 + (i % 3) * 0.05), 3 + (i % 4))
          .fill({ color: 0x451a03, alpha: 0.25 });
      }
      break;
    case 'cold_lux':
      g.rect(DESIGN_W * 0.05, DESIGN_H * 0.1, DESIGN_W * 0.9, 2).fill({ color: accent, alpha: 0.15 });
      g.rect(DESIGN_W * 0.05, DESIGN_H * 0.5, DESIGN_W * 0.9, 1).fill({ color: accent, alpha: 0.08 });
      break;
    case 'electric':
      g.roundRect(DESIGN_W * 0.72, DESIGN_H * 0.08, 160, 90, 6).fill({ color: 0x1a1808, alpha: 0.6 });
      g.roundRect(DESIGN_W * 0.72, DESIGN_H * 0.08, 160, 90, 6).stroke({ color: accent, width: 1, alpha: 0.5 });
      for (let r = 0; r < 4; r++) {
        g.rect(DESIGN_W * 0.74 + r * 38, DESIGN_H * 0.11, 30, 8).fill({ color: accent, alpha: 0.2 + Math.random() * 0.3 });
      }
      break;
    case 'crystal':
      for (let i = 0; i < 6; i++) {
        const x = DESIGN_W * (0.08 + i * 0.15);
        g.moveTo(x, DESIGN_H * 0.14).lineTo(x + 8, DESIGN_H * 0.28).lineTo(x - 8, DESIGN_H * 0.28).closePath();
        g.fill({ color: accent, alpha: 0.12 });
      }
      break;
    case 'pharma':
      g.roundRect(DESIGN_W * 0.06, DESIGN_H * 0.1, 120, 60, 4).fill({ color: 0xf5f5f4, alpha: 0.06 });
      g.roundRect(DESIGN_W * 0.06, DESIGN_H * 0.1, 120, 60, 4).stroke({ color: accent, width: 1, alpha: 0.3 });
      break;
    case 'forest':
      g.ellipse(DESIGN_W * 0.15, DESIGN_H * 0.18, 35, 50).fill({ color: 0x581c87, alpha: 0.12 });
      g.ellipse(DESIGN_W * 0.85, DESIGN_H * 0.2, 30, 45).fill({ color: 0x6b21a8, alpha: 0.1 });
      break;
  }
}
