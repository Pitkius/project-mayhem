/**
 * fivemprojektas — unified inventory icon style
 * Procedural neon-noir game icons (256px, transparent, consistent lighting)
 */
import fs from 'fs';
import path from 'path';
import { PNG } from 'pngjs';
import jpeg from 'jpeg-js';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const imagesDir = path.join(__dirname, '..', '..', 'resources', '[qb]', 'qb-inventory', 'html', 'images');
const SIZE = 256;
const CX = SIZE / 2;
const CY = SIZE / 2;

const STYLE = {
  plate: [22, 26, 38],
  plateEdge: [58, 68, 92],
  shadow: [6, 8, 14],
  highlight: [240, 244, 252],
};

class Canvas {
  constructor(size = SIZE) {
    this.size = size;
    this.px = new Float32Array(size * size * 4);
  }

  idx(x, y) {
    return (Math.floor(y) * this.size + Math.floor(x)) * 4;
  }

  blend(x, y, r, g, b, a) {
    if (x < 0 || y < 0 || x >= this.size || y >= this.size) return;
    const i = this.idx(x, y);
    const na = a / 255;
    const oa = this.px[i + 3] / 255;
    const outA = na + oa * (1 - na);
    if (outA <= 0) return;
    this.px[i] = (r * na + this.px[i] * oa * (1 - na)) / outA;
    this.px[i + 1] = (g * na + this.px[i + 1] * oa * (1 - na)) / outA;
    this.px[i + 2] = (b * na + this.px[i + 2] * oa * (1 - na)) / outA;
    this.px[i + 3] = outA * 255;
  }

  fillCircle(cx, cy, rx, ry, r, g, b, a = 255) {
    const rxi = Math.ceil(Math.max(rx, ry));
    for (let y = Math.floor(cy - rxi); y <= cy + rxi; y++) {
      for (let x = Math.floor(cx - rxi); x <= cx + rxi; x++) {
        const dx = (x - cx) / rx;
        const dy = (y - cy) / ry;
        if (dx * dx + dy * dy <= 1) this.blend(x, y, r, g, b, a);
      }
    }
  }

  fillRect(x, y, w, h, r, g, b, a = 255) {
    for (let py = y; py < y + h; py++) {
      for (let px = x; px < x + w; px++) this.blend(px, py, r, g, b, a);
    }
  }

  fillRoundRect(x, y, w, h, rad, r, g, b, a = 255) {
    for (let py = y; py < y + h; py++) {
      for (let px = x; px < x + w; px++) {
        let inside = true;
        const corners = [
          [x + rad, y + rad],
          [x + w - rad, y + rad],
          [x + rad, y + h - rad],
          [x + w - rad, y + h - rad],
        ];
        if (px < x + rad && py < y + rad) inside = (px - corners[0][0]) ** 2 + (py - corners[0][1]) ** 2 <= rad * rad;
        else if (px > x + w - rad && py < y + rad) inside = (px - corners[1][0]) ** 2 + (py - corners[1][1]) ** 2 <= rad * rad;
        else if (px < x + rad && py > y + h - rad) inside = (px - corners[2][0]) ** 2 + (py - corners[2][1]) ** 2 <= rad * rad;
        else if (px > x + w - rad && py > y + h - rad) inside = (px - corners[3][0]) ** 2 + (py - corners[3][1]) ** 2 <= rad * rad;
        if (inside) this.blend(px, py, r, g, b, a);
      }
    }
  }

  strokeRoundRect(x, y, w, h, rad, r, g, b, a = 255, thick = 2) {
    for (let t = 0; t < thick; t++) {
      this.fillRoundRect(x - t, y - t, w + t * 2, h + t * 2, rad + t, r, g, b, Math.round(a * 0.35));
    }
    this.fillRoundRect(x, y, w, h, rad, r, g, b, a);
  }

  addGroundShadow() {
    this.fillCircle(CX, CY + 78, 58, 16, ...STYLE.shadow, 48);
  }

  addIconPlate() {
    this.fillRoundRect(28, 28, 200, 200, 28, ...STYLE.plate, 235);
    this.strokeRoundRect(30, 30, 196, 196, 26, ...STYLE.plateEdge, 70, 2);
  }

  /** @deprecated use addIconPlate */
  addRimGlow() {
    this.addIconPlate();
  }

  toPng() {
    const png = new PNG({ width: this.size, height: this.size });
    for (let i = 0; i < this.px.length; i++) png.data[i] = Math.round(Math.min(255, Math.max(0, this.px[i])));
    return PNG.sync.write(png);
  }
}

function hex(h) {
  const n = h.replace('#', '');
  return [parseInt(n.slice(0, 2), 16), parseInt(n.slice(2, 4), 16), parseInt(n.slice(4, 6), 16)];
}

function shade([r, g, b], f) {
  return [Math.min(255, r * f), Math.min(255, g * f), Math.min(255, b * f)];
}

function drawBag(c, fill, accent, sealed = true) {
  c.addGroundShadow();
  c.addRimGlow();
  const bag = [210, 215, 225];
  c.fillRoundRect(78, 72, 100, 118, 14, ...bag, 240);
  c.fillRoundRect(86, 80, 84, 88, 10, ...fill, 255);
  if (sealed) c.fillRect(82, 68, 92, 14, ...shade(bag, 0.85), 255);
  c.fillCircle(128, 118, 28, 20, ...accent, 200);
  c.fillCircle(108, 108, 8, 8, ...STYLE.highlight, 80);
}

function drawJar(c, liquid, label = 'liq') {
  c.addGroundShadow();
  c.addIconPlate();
  c.strokeRoundRect(96, 68, 64, 108, 10, 120, 130, 148, 220, 3);
  c.fillRoundRect(102, 88, 52, 76, 8, ...liquid, 235);
  c.fillRect(108, 58, 40, 18, 100, 108, 122, 255);
  if (label === 'chem') {
    c.fillCircle(128, 118, 8, 8, 90, 170, 150, 120);
    c.fillCircle(142, 132, 6, 6, 170, 100, 140, 100);
  }
}

function drawBottle(c, liquid, capColor) {
  c.addGroundShadow();
  c.addIconPlate();
  c.fillRoundRect(108, 92, 40, 88, 12, ...liquid, 235);
  c.fillRect(114, 58, 28, 36, ...capColor, 255);
}

function drawBrick(c, color) {
  c.addGroundShadow();
  c.addRimGlow();
  c.fillRoundRect(72, 88, 112, 72, 8, ...shade(color, 0.75), 255);
  c.fillRoundRect(78, 82, 100, 20, 4, ...shade(color, 0.9), 255);
  c.fillRect(88, 100, 80, 3, ...STYLE.highlight, 40);
}

function drawLeaves(c, colors) {
  c.addGroundShadow();
  c.addRimGlow();
  const poses = [[108, 118, -0.4], [128, 108, 0.2], [148, 122, 0.55], [118, 138, -0.1], [138, 140, 0.35]];
  poses.forEach(([x, y, rot], i) => {
    const col = colors[i % colors.length];
    for (let s = 0; s < 3; s++) {
      c.fillCircle(x + s * 4, y + s * 2, 22 - s * 3, 12 - s, ...col, 220 - s * 20);
    }
  });
}

function drawFlower(c, petal, center) {
  c.addGroundShadow();
  c.addRimGlow();
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    c.fillCircle(CX + Math.cos(a) * 34, CY + Math.sin(a) * 34, 20, 14, ...petal, 230);
  }
  c.fillCircle(CX, CY, 22, 22, ...center, 255);
}

function drawCrystals(c, color) {
  c.addGroundShadow();
  c.addRimGlow();
  const pts = [[118, 150], [138, 132], [128, 108], [108, 126], [148, 148], [98, 138]];
  pts.forEach(([x, y], i) => {
    c.fillCircle(x, y, 16 + (i % 3) * 4, 22 + (i % 2) * 6, ...shade(color, 0.85 + (i % 3) * 0.08), 240);
    c.fillCircle(x - 4, y - 6, 5, 5, ...STYLE.highlight, 90);
  });
}

function drawMushroom(c, cap, stem) {
  c.addGroundShadow();
  c.addRimGlow();
  c.fillRoundRect(118, 118, 20, 48, 8, ...stem, 255);
  c.fillCircle(128, 108, 46, 30, ...cap, 255);
  c.fillCircle(112, 100, 10, 8, ...STYLE.highlight, 60);
}

function drawPills(c, colors) {
  c.addGroundShadow();
  c.addRimGlow();
  const spots = [[108, 118], [128, 132], [148, 118], [118, 148], [138, 150]];
  spots.forEach(([x, y], i) => {
    const col = colors[i % colors.length];
    c.fillCircle(x, y, 14, 10, ...col, 255);
    c.fillRect(x - 8, y - 2, 16, 4, ...STYLE.highlight, 35);
  });
}

function drawToolBox(c) {
  c.addGroundShadow();
  c.addRimGlow();
  c.fillRoundRect(76, 96, 104, 72, 10, 90, 98, 115, 255);
  c.fillRect(76, 118, 104, 10, 70, 78, 95, 255);
  c.fillRect(118, 88, 20, 16, 120, 128, 145, 255);
}

function drawScale(c) {
  c.addGroundShadow();
  c.addRimGlow();
  c.fillRoundRect(98, 130, 60, 14, 4, 80, 88, 105, 255);
  c.fillRect(124, 98, 8, 34, 100, 108, 125, 255);
  c.fillCircle(104, 148, 18, 8, 130, 135, 150, 255);
  c.fillCircle(152, 148, 18, 8, 130, 135, 150, 255);
}

function drawGloves(c) {
  c.addGroundShadow();
  c.addRimGlow();
  c.fillRoundRect(88, 96, 44, 72, 16, 50, 130, 210, 240);
  c.fillRoundRect(124, 96, 44, 72, 16, 45, 120, 200, 240);
}

function drawMetal(c) {
  c.addGroundShadow();
  c.addRimGlow();
  for (let i = 0; i < 5; i++) {
    c.fillRoundRect(82 + i * 18, 108 + (i % 2) * 8, 28, 20, 5, 130 + i * 8, 138 + i * 6, 150, 230);
  }
}

function drawGunPart(c, kind) {
  c.addGroundShadow();
  c.addRimGlow();
  const steel = [145, 155, 170];
  const dark = [75, 82, 95];
  if (kind === 'frame') {
    c.fillRoundRect(78, 108, 100, 44, 8, ...steel, 255);
    c.fillRoundRect(118, 96, 36, 24, 6, ...dark, 255);
  } else if (kind === 'barrel') {
    c.fillRoundRect(68, 122, 120, 20, 8, ...steel, 255);
    c.fillCircle(188, 132, 14, 14, ...dark, 255);
  } else if (kind === 'spring') {
    for (let i = 0; i < 6; i++) c.fillCircle(92 + i * 16, 128 + (i % 2) * 10, 10, 10, ...steel, 255);
  } else if (kind === 'trigger') {
    c.fillRoundRect(108, 104, 40, 56, 8, ...dark, 255);
    c.fillRoundRect(118, 118, 16, 28, 4, ...steel, 255);
  } else {
    c.fillRoundRect(88, 100, 80, 64, 10, ...steel, 255);
    c.fillCircle(108, 118, 8, 8, ...dark, 220);
    c.fillCircle(138, 126, 10, 10, ...dark, 220);
  }
}

function drawPrinter(c) {
  c.addGroundShadow();
  c.addRimGlow();
  c.fillRoundRect(72, 88, 112, 88, 10, 235, 238, 245, 255);
  c.fillRect(82, 78, 92, 18, 60, 65, 75, 255);
  c.fillRect(88, 108, 72, 6, 40, 180, 120, 255);
  c.fillRoundRect(96, 118, 56, 32, 6, 200, 205, 215, 255);
}

function drawAmmo(c, tip) {
  c.addGroundShadow();
  c.addRimGlow();
  const brass = [210, 175, 80];
  const tipColors = { pistol: [180, 180, 185], smg: [170, 175, 160], rifle: [160, 175, 140], shotgun: [150, 155, 150] };
  const tc = tipColors[tip] || tipColors.pistol;
  for (let i = 0; i < 4; i++) {
    const x = 92 + i * 18;
    c.fillRoundRect(x, 118, 14, 36, 4, ...brass, 255);
    c.fillRoundRect(x + 1, 104, 12, 16, 3, ...tc, 255);
  }
}

function drawPapers(c) {
  c.addGroundShadow();
  c.addRimGlow();
  for (let i = 0; i < 3; i++) {
    c.fillRoundRect(90 + i * 6, 88 + i * 4, 76, 96, 6, 235 - i * 8, 238 - i * 6, 245 - i * 4, 240 - i * 20);
  }
}

function drawFilter(c) {
  c.addGroundShadow();
  c.addRimGlow();
  c.fillRoundRect(108, 92, 40, 88, 14, 245, 235, 210, 255);
  c.fillRect(114, 100, 28, 56, 230, 220, 195, 200);
}

function drawLighter(c) {
  c.addGroundShadow();
  c.addRimGlow();
  c.fillRoundRect(108, 108, 40, 64, 8, 220, 50, 50, 255);
  c.fillRect(116, 88, 24, 24, 170, 170, 180, 255);
}

function drawPlastic(c) {
  c.addGroundShadow();
  c.addIconPlate();
  c.fillRoundRect(88, 108, 80, 56, 12, 100, 170, 210, 240);
  for (let i = 0; i < 4; i++) c.fillCircle(104 + i * 16, 132, 5, 5, ...STYLE.highlight, 45);
}

function drawBlueprint(c) {
  c.addGroundShadow();
  c.addRimGlow();
  c.fillRoundRect(80, 84, 96, 104, 8, 55, 110, 200, 240);
  c.fillRect(92, 98, 72, 4, ...STYLE.highlight, 50);
  c.fillRect(92, 112, 56, 4, ...STYLE.highlight, 40);
  c.fillRect(92, 126, 64, 4, ...STYLE.highlight, 40);
  c.fillRoundRect(108, 142, 40, 28, 4, 40, 90, 170, 200);
}

const GENERATORS = {
  weed_leaf: () => { const c = new Canvas(); drawLeaves(c, [hex('#3d9a4a'), hex('#2f7d3b'), hex('#52b86a')]); return c; },
  weed_buds: () => { const c = new Canvas(); drawLeaves(c, [hex('#4ade80'), hex('#22c55e'), hex('#86efac')]); return c; },
  weed_resin: () => { const c = new Canvas(); drawJar(c, hex('#a3e635'), 'liq'); return c; },
  weed_seed: () => { const c = new Canvas(); drawPills(c, [hex('#8B7355'), hex('#6d5a44')]); return c; },
  weed_baggy: () => { const c = new Canvas(); drawBag(c, hex('#4ade80'), hex('#22c55e')); return c; },
  weed_baggy_empty: () => { const c = new Canvas(); drawBag(c, hex('#d8dee9'), hex('#c5ccd8'), false); return c; },
  coca_leaf: () => { const c = new Canvas(); drawLeaves(c, [hex('#2f9e44'), hex('#51cf66'), hex('#1f7a35')]); return c; },
  cocaine_paste: () => { const c = new Canvas(); drawJar(c, hex('#f1f5f9'), 'chem'); return c; },
  cocaine_powder_loose: () => { const c = new Canvas(); drawBag(c, hex('#f8fafc'), hex('#e2e8f0')); return c; },
  cocaine_baggy: () => { const c = new Canvas(); drawBag(c, hex('#f8fafc'), hex('#cbd5e1')); return c; },
  coke_small_brick: () => { const c = new Canvas(); drawBrick(c, hex('#f1f5f9')); return c; },
  poppy_flower: () => { const c = new Canvas(); drawFlower(c, hex('#f87171'), hex('#3f3f46')); return c; },
  heroin_powder_loose: () => { const c = new Canvas(); drawBag(c, hex('#b45309'), hex('#92400e')); return c; },
  heroin_bag: () => { const c = new Canvas(); drawBag(c, hex('#d97706'), hex('#b45309')); return c; },
  meth_crystal: () => { const c = new Canvas(); drawCrystals(c, hex('#38bdf8')); return c; },
  meth_baggy: () => { const c = new Canvas(); drawBag(c, hex('#7dd3fc'), hex('#38bdf8')); return c; },
  mushroom_raw: () => { const c = new Canvas(); drawMushroom(c, hex('#c084fc'), hex('#f5f5f4')); return c; },
  mushroom_dried: () => { const c = new Canvas(); drawMushroom(c, hex('#a78bfa'), hex('#e7e5e4')); return c; },
  mushroom_pack: () => { const c = new Canvas(); drawBag(c, hex('#c4b5fd'), hex('#a78bfa')); return c; },
  amp_precursor: () => { const c = new Canvas(); drawJar(c, hex('#fdba74'), 'chem'); return c; },
  amp_paste: () => { const c = new Canvas(); drawJar(c, hex('#fb923c'), 'chem'); return c; },
  xtc_baggy: () => { const c = new Canvas(); drawBag(c, hex('#f472b6'), hex('#ec4899')); return c; },
  pill_tablets: () => { const c = new Canvas(); drawPills(c, [hex('#f472b6'), hex('#60a5fa'), hex('#fbbf24')]); return c; },
  moonshine_spirit: () => { const c = new Canvas(); drawBottle(c, hex('#fef08a'), hex('#57534e')); return c; },
  alcohol_base: () => { const c = new Canvas(); drawJar(c, hex('#fde68a'), 'liq'); return c; },
  vodka: () => { const c = new Canvas(); drawBottle(c, hex('#e2e8f0'), hex('#1e293b')); return c; },
  vape_liquid_base: () => { const c = new Canvas(); drawJar(c, hex('#c4b5fd'), 'liq'); return c; },
  vape_mix: () => { const c = new Canvas(); drawJar(c, hex('#a78bfa'), 'liq'); return c; },
  vape_liquid: () => { const c = new Canvas(); drawBottle(c, hex('#a78bfa'), hex('#6d28d9')); return c; },
  thc_vape_bottle: () => { const c = new Canvas(); drawBottle(c, hex('#86efac'), hex('#4ade80')); return c; },
  chemical_mix: () => { const c = new Canvas(); drawJar(c, hex('#67e8f9'), 'chem'); return c; },
  empty_bottle: () => { const c = new Canvas(); drawBottle(c, hex('#94a3b8'), hex('#64748b')); return c; },
  ocb_papers: () => { const c = new Canvas(); drawPapers(c); return c; },
  filter_tip: () => { const c = new Canvas(); drawFilter(c); return c; },
  lab_kit: () => { const c = new Canvas(); drawToolBox(c); return c; },
  drug_scale: () => { const c = new Canvas(); drawScale(c); return c; },
  gloves_item: () => { const c = new Canvas(); drawGloves(c); return c; },
  lighter: () => { const c = new Canvas(); drawLighter(c); return c; },
  plastic: () => { const c = new Canvas(); drawPlastic(c); return c; },
  metal_scrap: () => { const c = new Canvas(); drawMetal(c); return c; },
  gun_frame: () => { const c = new Canvas(); drawGunPart(c, 'frame'); return c; },
  gun_barrel: () => { const c = new Canvas(); drawGunPart(c, 'barrel'); return c; },
  gun_spring: () => { const c = new Canvas(); drawGunPart(c, 'spring'); return c; },
  gun_trigger: () => { const c = new Canvas(); drawGunPart(c, 'trigger'); return c; },
  weapon_parts: () => { const c = new Canvas(); drawGunPart(c, 'parts'); return c; },
  weapon_prototype: () => { const c = new Canvas(); drawBlueprint(c); return c; },
  '3d_printer': () => { const c = new Canvas(); drawPrinter(c); return c; },
  pistol_ammo: () => { const c = new Canvas(); drawAmmo(c, 'pistol'); return c; },
  smg_ammo: () => { const c = new Canvas(); drawAmmo(c, 'smg'); return c; },
  rifle_ammo: () => { const c = new Canvas(); drawAmmo(c, 'rifle'); return c; },
  shotgun_ammo: () => { const c = new Canvas(); drawAmmo(c, 'shotgun'); return c; },
};

const EXTRA_COPIES = {
  cartel_pack: 'coke_small_brick',
  heroin_paste: 'heroin_powder_loose',
};

function writeIcon(name) {
  const base = name.replace(/\.png$/i, '');
  const gen = GENERATORS[base];
  if (!gen) return false;
  const out = gen().toPng();
  fs.writeFileSync(path.join(imagesDir, `${base}.png`), out);
  return true;
}

let count = 0;
for (const name of Object.keys(GENERATORS)) {
  if (writeIcon(name)) {
    console.log('generated', `${name}.png`);
    count++;
  }
}

for (const [dest, src] of Object.entries(EXTRA_COPIES)) {
  const srcPath = path.join(imagesDir, `${src}.png`);
  const destPath = path.join(imagesDir, `${dest}.png`);
  if (fs.existsSync(srcPath)) {
    fs.copyFileSync(srcPath, destPath);
    console.log('copied', `${dest}.png`, '<-', `${src}.png`);
    count++;
  }
}

function blitScaled(canvas, srcPng, fitScale = 0.82) {
  const sw = srcPng.width;
  const sh = srcPng.height;
  const maxW = SIZE * fitScale;
  const maxH = SIZE * fitScale;
  const scale = Math.min(maxW / sw, maxH / sh);
  const dw = Math.round(sw * scale);
  const dh = Math.round(sh * scale);
  const ox = Math.round((SIZE - dw) / 2);
  const oy = Math.round((SIZE - dh) / 2) - 4;
  for (let y = 0; y < dh; y += 1) {
    for (let x = 0; x < dw; x += 1) {
      const sx = Math.min(sw - 1, Math.floor((x / dw) * sw));
      const sy = Math.min(sh - 1, Math.floor((y / dh) * sh));
      const si = (sy * sw + sx) << 2;
      const a = srcPng.data[si + 3];
      if (a < 10) continue;
      canvas.blend(ox + x, oy + y, srcPng.data[si], srcPng.data[si + 1], srcPng.data[si + 2], a);
    }
  }
}

function readRasterImage(srcPath) {
  const buf = fs.readFileSync(srcPath);
  if (buf[0] === 0xff && buf[1] === 0xd8) {
    const decoded = jpeg.decode(buf, { useTArray: true });
    return { width: decoded.width, height: decoded.height, data: decoded.data };
  }
  const png = PNG.sync.read(buf);
  return { width: png.width, height: png.height, data: png.data };
}

function buildWeaponPhotoIcon(srcFile, outName) {
  const srcPath = path.join(__dirname, 'sources', srcFile);
  if (!fs.existsSync(srcPath)) return false;
  const src = readRasterImage(srcPath);
  const c = new Canvas();
  c.addGroundShadow();
  c.addIconPlate();
  blitScaled(c, src, 0.9);
  fs.writeFileSync(path.join(imagesDir, outName), c.toPng());
  return true;
}

const photoIcons = [
  ['weapon_fgc9_ref.png', 'weapon_fgc9.png'],
];
for (const [src, out] of photoIcons) {
  if (buildWeaponPhotoIcon(src, out)) {
    console.log('photo icon', out);
    count += 1;
  }
}

console.log(`Done. ${count} icon file(s).`);
