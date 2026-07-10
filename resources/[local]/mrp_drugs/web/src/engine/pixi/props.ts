import { Container, Graphics } from 'pixi.js';
import gsap from 'gsap';

// PLACEHOLDER props — unique silhouettes per equipment type.
// Replace with WebP sprites (see ASSET_REQUIREMENTS.md) without changing hit zones.

export function drawCopperStill(parent: Container, x: number, y: number, scale = 1): Container {
  const c = new Container();
  c.position.set(x, y);
  c.scale.set(scale);
  const g = new Graphics();
  // boiler
  g.roundRect(-55, 20, 110, 90, 20).fill({ color: 0xb45309 });
  g.roundRect(-55, 20, 110, 90, 20).stroke({ color: 0x92400e, width: 3 });
  // neck
  g.rect(-12, -50, 24, 72).fill({ color: 0xd97706 });
  // condenser coil
  for (let i = 0; i < 5; i++) {
    g.arc(30, -10 + i * 12, 18, Math.PI * 0.5, Math.PI * 1.5);
    g.stroke({ color: 0xca8a04, width: 4 });
  }
  // outlet
  g.rect(48, 30, 40, 10).fill({ color: 0x78716c });
  c.addChild(g);
  parent.addChild(c);
  return c;
}

export function drawValve(parent: Container, x: number, y: number, accent: number, label?: string): Graphics {
  const g = new Graphics();
  g.position.set(x, y);
  g.circle(0, 0, 28).fill({ color: 0x292524 });
  g.circle(0, 0, 28).stroke({ color: accent, width: 2, alpha: 0.7 });
  g.rect(-4, -22, 8, 44).fill({ color: accent });
  g.rect(-22, -4, 44, 8).fill({ color: accent, alpha: 0.8 });
  parent.addChild(g);
  return g;
}

export function drawGlassJar(parent: Container, x: number, y: number, h = 130, liquidColor = 0xc4a035): Container {
  const c = new Container();
  c.position.set(x, y);
  const body = new Graphics();
  body.roundRect(-35, 0, 70, h, 10).fill({ color: 0x0d1117, alpha: 0.35 });
  body.roundRect(-35, 0, 70, h, 10).stroke({ color: 0x9fd8e6, width: 2, alpha: 0.55 });
  const liquid = new Graphics();
  liquid.label = 'liquid';
  liquid.roundRect(-31, h * 0.35, 62, h * 0.6, 8).fill({ color: liquidColor, alpha: 0.7 });
  c.addChild(body);
  c.addChild(liquid);
  parent.addChild(c);
  return c;
}

export function drawVapeMixer(parent: Container, x: number, y: number, accent: number): Container {
  const c = new Container();
  c.position.set(x, y);
  const base = new Graphics();
  base.roundRect(-80, 40, 160, 50, 8).fill({ color: 0x1e293b });
  base.roundRect(-80, 40, 160, 50, 8).stroke({ color: accent, width: 2, alpha: 0.5 });
  const beaker = new Graphics();
  beaker.roundRect(-40, -30, 80, 75, 12).fill({ color: 0x0f172a, alpha: 0.5 });
  beaker.roundRect(-40, -30, 80, 75, 12).stroke({ color: 0x67e8f9, width: 2 });
  const spin = new Graphics();
  spin.label = 'spinner';
  spin.circle(0, 10, 6).fill({ color: accent });
  spin.rect(-2, -20, 4, 40).fill({ color: accent, alpha: 0.6 });
  c.addChild(base);
  c.addChild(beaker);
  c.addChild(spin);
  parent.addChild(c);
  return c;
}

export function drawGrowPot(parent: Container, x: number, y: number): Container {
  const c = new Container();
  c.position.set(x, y);
  const pot = new Graphics();
  pot.moveTo(-50, 30).lineTo(-42, 80).lineTo(42, 80).lineTo(50, 30).closePath();
  pot.fill({ color: 0x78350f });
  pot.ellipse(0, 28, 52, 14).fill({ color: 0x92400e });
  const soil = new Graphics();
  soil.label = 'soil';
  soil.ellipse(0, 22, 44, 12).fill({ color: 0x5c4033 });
  const plant = new Graphics();
  plant.label = 'plant';
  plant.moveTo(0, 20).lineTo(-8, -20).lineTo(0, -35).lineTo(8, -20).closePath();
  plant.fill({ color: 0x22c55e, alpha: 0.85 });
  c.addChild(pot);
  c.addChild(soil);
  c.addChild(plant);
  parent.addChild(c);
  return c;
}

export function drawDryingRack(parent: Container, x: number, y: number, accent: number): Container {
  const c = new Container();
  c.position.set(x, y);
  const frame = new Graphics();
  frame.rect(-120, 0, 240, 8).fill({ color: 0x57534e });
  frame.rect(-120, 50, 240, 8).fill({ color: 0x57534e });
  for (let i = 0; i < 5; i++) {
    const bud = new Graphics();
    bud.ellipse(-90 + i * 45, 25, 14, 8).fill({ color: accent, alpha: 0.75 });
    c.addChild(bud);
  }
  c.addChild(frame);
  parent.addChild(c);
  return c;
}

export function drawHeroinTray(parent: Container, x: number, y: number): Container {
  const c = new Container();
  c.position.set(x, y);
  const tray = new Graphics();
  tray.roundRect(-100, 0, 200, 70, 6).fill({ color: 0x44403c, alpha: 0.8 });
  tray.roundRect(-100, 0, 200, 70, 6).stroke({ color: 0x78716c, width: 1 });
  const filter = new Graphics();
  filter.roundRect(-30, 10, 60, 50, 4).fill({ color: 0xf5f5f4, alpha: 0.15 });
  filter.rect(-25, 15, 50, 4).fill({ color: 0xdc2626, alpha: 0.3 });
  c.addChild(tray);
  c.addChild(filter);
  parent.addChild(c);
  return c;
}

export function drawFoilPouch(parent: Container, x: number, y: number): Graphics {
  const g = new Graphics();
  g.position.set(x, y);
  g.roundRect(-70, -40, 140, 80, 6).fill({ color: 0xc0c0c0, alpha: 0.35 });
  g.roundRect(-70, -40, 140, 80, 6).stroke({ color: 0x9ca3af, width: 1 });
  parent.addChild(g);
  return g;
}

export function drawCocainePress(parent: Container, x: number, y: number, accent: number): Container {
  const c = new Container();
  c.position.set(x, y);
  const base = new Graphics();
  base.roundRect(-70, 30, 140, 40, 6).fill({ color: 0x334155 });
  const ram = new Graphics();
  ram.label = 'ram';
  ram.roundRect(-35, -60, 70, 90, 4).fill({ color: 0x64748b });
  ram.roundRect(-40, -65, 80, 12, 3).fill({ color: accent, alpha: 0.8 });
  const mold = new Graphics();
  mold.roundRect(-50, 10, 100, 25, 4).fill({ color: 0x1e293b });
  c.addChild(base);
  c.addChild(mold);
  c.addChild(ram);
  parent.addChild(c);
  return c;
}

export function drawAmpReactor(parent: Container, x: number, y: number, accent: number): Container {
  const c = new Container();
  c.position.set(x, y);
  const body = new Graphics();
  body.roundRect(-90, -20, 180, 100, 10).fill({ color: 0x1c1917 });
  body.roundRect(-90, -20, 180, 100, 10).stroke({ color: accent, width: 2, alpha: 0.6 });
  const screen = new Graphics();
  screen.label = 'screen';
  screen.roundRect(-70, -5, 140, 50, 6).fill({ color: 0x0c0a09 });
  screen.roundRect(-70, -5, 140, 50, 6).stroke({ color: accent, width: 1 });
  for (let i = 0; i < 4; i++) {
    body.circle(-60 + i * 40, 65, 8).fill({ color: accent, alpha: 0.4 + i * 0.1 });
  }
  c.addChild(body);
  c.addChild(screen);
  parent.addChild(c);
  return c;
}

export function drawMethFlask(parent: Container, x: number, y: number, accent: number): Container {
  const c = new Container();
  c.position.set(x, y);
  const flask = new Graphics();
  flask.roundRect(-30, 10, 60, 80, 8).fill({ color: 0x0f172a, alpha: 0.4 });
  flask.roundRect(-30, 10, 60, 80, 8).stroke({ color: accent, width: 2 });
  flask.rect(-8, -40, 16, 52).fill({ color: 0x1e3a5f, alpha: 0.5 });
  const crystals = new Graphics();
  crystals.label = 'crystals';
  for (let i = 0; i < 8; i++) {
    const cx = -20 + (i % 4) * 14;
    const cy = 40 + Math.floor(i / 4) * 16;
    crystals.poly([cx, cy - 6, cx + 5, cy, cx, cy + 6, cx - 5, cy]).fill({ color: accent, alpha: 0.85 });
  }
  c.addChild(flask);
  c.addChild(crystals);
  parent.addChild(c);
  return c;
}

export function drawPillPress(parent: Container, x: number, y: number, accent: number): Container {
  const c = new Container();
  c.position.set(x, y);
  const base = new Graphics();
  base.roundRect(-75, 20, 150, 55, 8).fill({ color: 0xe7e5e4 });
  base.roundRect(-75, 20, 150, 55, 8).stroke({ color: 0xa8a29e, width: 2 });
  const head = new Graphics();
  head.label = 'head';
  head.roundRect(-40, -50, 80, 70, 6).fill({ color: 0x78716c });
  head.roundRect(-30, -30, 60, 20, 4).fill({ color: accent, alpha: 0.7 });
  c.addChild(base);
  c.addChild(head);
  parent.addChild(c);
  return c;
}

export function drawMushroomJar(parent: Container, x: number, y: number, accent: number): Container {
  const c = new Container();
  c.position.set(x, y);
  const jar = new Graphics();
  jar.roundRect(-40, 0, 80, 100, 12).fill({ color: 0x1e1b2e, alpha: 0.45 });
  jar.roundRect(-40, 0, 80, 100, 12).stroke({ color: accent, width: 2, alpha: 0.5 });
  for (let i = 0; i < 4; i++) {
    const m = new Graphics();
    m.ellipse(-15 + i * 12, 50 - (i % 2) * 10, 8, 12).fill({ color: 0xc084fc, alpha: 0.8 });
    m.ellipse(-15 + i * 12, 42 - (i % 2) * 10, 10, 5).fill({ color: 0xf5d0fe, alpha: 0.7 });
    c.addChild(m);
  }
  parent.addChild(c);
  c.addChild(jar);
  return c;
}

export function drawThcCartridge(parent: Container, x: number, y: number, accent: number): Container {
  const c = new Container();
  c.position.set(x, y);
  const body = new Graphics();
  body.roundRect(-14, 0, 28, 70, 8).fill({ color: 0x1e1033, alpha: 0.6 });
  body.roundRect(-14, 0, 28, 70, 8).stroke({ color: accent, width: 2 });
  const mouth = new Graphics();
  mouth.roundRect(-8, -18, 16, 20, 4).fill({ color: accent, alpha: 0.5 });
  c.addChild(body);
  c.addChild(mouth);
  parent.addChild(c);
  return c;
}

export function animateSteam(container: Container, x: number, y: number, color: number, count = 6) {
  for (let i = 0; i < count; i++) {
    const s = new Graphics();
    s.circle(0, 0, 4 + Math.random() * 6).fill({ color, alpha: 0.25 });
    s.position.set(x + (Math.random() - 0.5) * 40, y);
    container.addChild(s);
    gsap.to(s, {
      y: y - 60 - Math.random() * 40,
      alpha: 0,
      duration: 1.2 + Math.random() * 0.8,
      repeat: -1,
      delay: i * 0.3,
      ease: 'sine.out',
    });
  }
}

export function animateSpin(target: Container, duration = 2) {
  gsap.to(target, { rotation: Math.PI * 2, duration, repeat: -1, ease: 'none' });
}

export function animatePressRam(ram: Graphics, onComplete?: () => void) {
  gsap.to(ram, {
    y: 25,
    duration: 0.35,
    yoyo: true,
    repeat: 1,
    ease: 'power2.inOut',
    onComplete,
  });
}

export function animatePulse(g: Graphics, accent: number) {
  gsap.to(g, {
    alpha: 0.4,
    duration: 0.6,
    yoyo: true,
    repeat: -1,
    ease: 'sine.inOut',
  });
  g.tint = accent;
}

export function setLiquidLevel(jar: Container, fraction: number, color: number) {
  const liq = jar.children.find((ch) => (ch as Graphics).label === 'liquid') as Graphics | undefined;
  if (!liq) return;
  const h = 130;
  liq.clear();
  const lh = h * 0.6 * Math.min(1, fraction);
  liq.roundRect(-31, h * 0.35 + (h * 0.6 - lh), 62, lh, 8).fill({ color, alpha: 0.75 });
}
