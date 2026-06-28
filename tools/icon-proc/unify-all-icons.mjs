/**
 * fivemprojektas — unified inventory icon style
 * Procedural neon-noir game icons (256px, transparent, consistent lighting)
 */
import fs from 'fs';
import path from 'path';
import { PNG } from 'pngjs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const imagesDir = path.join(__dirname, '..', '..', 'resources', '[qb]', 'qb-inventory', 'html', 'images');
const SIZE = 256;
const CX = SIZE / 2;
const CY = SIZE / 2;

const STYLE = {
  rim: [168, 85, 247],
  rimAlpha: 0,
  shadow: [8, 4, 18],
  highlight: [255, 255, 255],
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
    this.fillCircle(CX, CY + 78, 62, 18, ...STYLE.shadow, 55);
  }

  addRimGlow() {
    this.fillCircle(CX, CY, 88, 88, ...STYLE.rim, Math.round(255 * STYLE.rimAlpha));
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
  c.addRimGlow();
  c.strokeRoundRect(96, 68, 64, 108, 10, 180, 190, 205, 230, 3);
  c.fillRoundRect(102, 88, 52, 76, 8, ...liquid, 230);
  c.fillRect(108, 58, 40, 18, 160, 165, 175, 255);
  if (label === 'chem') {
    c.fillCircle(128, 118, 10, 10, 120, 220, 180, 200);
    c.fillCircle(142, 132, 8, 8, 220, 120, 160, 180);
  }
}

function drawBottle(c, liquid, capColor) {
  c.addGroundShadow();
  c.addRimGlow();
  c.fillRoundRect(108, 92, 40, 88, 12, ...liquid, 235);
  c.fillRect(114, 58, 28, 36, ...capColor, 255);
  c.fillCircle(120, 118, 6, 14, ...STYLE.highlight, 70);
}

function drawBrick(c, color) {
  c.addGroundShadow();
  c.addRimGlow();
  c.fillRoundRect(72, 88, 112, 72, 8, ...shade(color, 0.75), 255);
  c.fillRoundRect(78, 82, 100, 20, 4, ...shade(color, 0.9), 255);
  c.fillRect(88, 100, 80, 3, ...STYLE.highlight, 40);
}

function drawLeaves(c, colors) {
  drawCannabisLeaf(c, 1);
}

function drawCannabisLeaf(c, scale = 1) {
  c.addGroundShadow();
  c.addRimGlow();
  const leaf = hex('#22c55e');
  const dark = hex('#15803d');
  const light = hex('#86efac');
  const fingers = [
    [0, -52], [-28, -38], [-42, -12], [-38, 14], [-18, 32],
    [0, 38], [18, 32], [38, 14], [42, -12], [28, -38],
  ];
  fingers.forEach(([ox, oy], i) => {
    const x = CX + ox * scale;
    const y = CY + oy * scale;
    const col = i % 2 === 0 ? leaf : dark;
    c.fillCircle(x, y, 16 * scale, 28 * scale, ...col, 235);
    c.fillCircle(x - 3 * scale, y - 4 * scale, 5 * scale, 8 * scale, ...light, 90);
  });
  c.fillCircle(CX, CY + 8 * scale, 10 * scale, 18 * scale, ...dark, 255);
}

function drawWeedBudsIcon(c) {
  c.addGroundShadow();
  c.addRimGlow();
  const clusters = [
    [108, 128, 34, 28], [128, 112, 40, 32], [148, 126, 36, 30],
    [118, 142, 28, 24], [138, 148, 30, 26], [128, 132, 22, 20],
  ];
  clusters.forEach(([x, y, rx, ry], i) => {
    const g = i % 3 === 0 ? hex('#166534') : i % 3 === 1 ? hex('#22c55e') : hex('#4ade80');
    c.fillCircle(x, y, rx, ry, ...g, 245);
    for (let h = 0; h < 6; h++) {
      const a = (h / 6) * Math.PI * 2 + i * 0.3;
      c.fillCircle(x + Math.cos(a) * (rx - 6), y + Math.sin(a) * (ry - 5), 5, 8, ...hex('#f97316'), 200);
    }
    c.fillCircle(x - 6, y - 8, 7, 5, ...STYLE.highlight, 70);
  });
}

function drawZipBag(c, contentColor, accentColor, label = '') {
  c.addGroundShadow();
  c.addRimGlow();
  const bag = [200, 210, 225];
  c.fillRoundRect(74, 78, 108, 112, 10, ...bag, 245);
  c.fillRoundRect(82, 94, 92, 78, 8, ...contentColor, 255);
  c.fillRect(78, 82, 100, 16, ...shade(bag, 0.88), 255);
  c.fillRect(88, 84, 80, 6, ...accentColor, 180);
  c.fillCircle(100, 108, 6, 6, ...STYLE.highlight, 60);
  if (label === 'coke') {
    for (let i = 0; i < 5; i++) c.fillCircle(108 + i * 10, 128 + (i % 2) * 6, 4, 4, ...STYLE.highlight, 120);
  }
  if (label === 'meth') {
    drawCrystalsOnCanvas(c, 128, 128, hex('#38bdf8'), 0.55);
  }
}

function drawCrystalsOnCanvas(c, cx, cy, color, scale = 1) {
  const pts = [[0, 18], [14, -8], [0, -22], [-14, -8], [20, 12], [-18, 14]];
  pts.forEach(([ox, oy], i) => {
    const x = cx + ox * scale;
    const y = cy + oy * scale;
    c.fillCircle(x, y, 10 * scale, 16 * scale, ...shade(color, 0.85 + (i % 3) * 0.08), 240);
    c.fillCircle(x - 3 * scale, y - 5 * scale, 4 * scale, 4 * scale, ...STYLE.highlight, 100);
  });
}

function drawMushroomDetailed(c, capColor, spotColor, stemColor, dried = false) {
  c.addGroundShadow();
  const mushrooms = dried
    ? [[128, 132, 1], [102, 142, 0.82], [154, 138, 0.88]]
    : [[128, 128, 1], [100, 138, 0.85], [156, 134, 0.9]];
  mushrooms.forEach(([mx, my, sc], idx) => {
    const stemW = Math.round(20 * sc);
    const stemH = Math.round(46 * sc);
    c.fillRoundRect(mx - stemW / 2, my, stemW, stemH, Math.round(8 * sc), ...stemColor, 255);
    c.fillCircle(mx, my - 6 * sc, 44 * sc, 30 * sc, ...capColor, 255);
    if (!dried) {
      [[mx - 14 * sc, my - 12 * sc], [mx + 10 * sc, my - 14 * sc], [mx, my - 4 * sc], [mx + 16 * sc, my - 2 * sc]].forEach(([x, y]) => {
        c.fillCircle(x, y, 7 * sc, 6 * sc, ...spotColor, 245);
      });
    } else {
      for (let i = 0; i < 6; i++) {
        const a = (i / 6) * Math.PI * 2;
        c.fillCircle(mx + Math.cos(a) * 22 * sc, my - 6 * sc + Math.sin(a) * 14 * sc, 3 * sc, 3 * sc, ...shade(capColor, 0.72), 210);
      }
    }
    if (idx === 0) c.fillCircle(mx - 14 * sc, my - 18 * sc, 12 * sc, 8 * sc, ...STYLE.highlight, 65);
  });
}

function drawCokeBrickIcon(c) {
  c.addGroundShadow();
  c.addRimGlow();
  c.fillRoundRect(68, 96, 120, 72, 6, ...hex('#d4d4d8'), 255);
  c.fillRoundRect(74, 90, 108, 18, 4, ...hex('#f4f4f5'), 255);
  c.fillRect(82, 108, 92, 3, ...STYLE.highlight, 80);
  c.fillRect(82, 124, 88, 2, ...shade(hex('#a1a1aa'), 0.9), 100);
  c.fillRect(82, 140, 90, 2, ...shade(hex('#a1a1aa'), 0.9), 100);
}

function drawJointIcon(c) {
  c.addGroundShadow();
  c.addRimGlow();
  c.fillRoundRect(88, 118, 80, 18, 8, ...hex('#fef3c7'), 255);
  c.fillRoundRect(92, 120, 52, 14, 6, ...hex('#4ade80'), 255);
  c.fillRoundRect(148, 119, 18, 16, 6, ...hex('#ea580c'), 255);
  c.fillCircle(96, 124, 4, 4, ...hex('#166534'), 200);
}

function drawAmmoPistol(c) {
  c.addGroundShadow();
  c.addRimGlow();
  c.fillRoundRect(76, 108, 104, 68, 10, ...hex('#3f3f46'), 240);
  c.fillRect(84, 116, 88, 4, ...hex('#52525b'), 255);
  const brass = hex('#d4a017');
  const tip = hex('#b45309');
  [[100, 132], [118, 128], [136, 132], [154, 128]].forEach(([x, y]) => {
    c.fillRoundRect(x - 7, y, 14, 22, 4, ...brass, 255);
    c.fillCircle(x, y - 2, 7, 7, ...tip, 255);
    c.fillCircle(x - 2, y + 4, 3, 3, ...STYLE.highlight, 80);
  });
}

function drawAmmoSmg(c) {
  c.addGroundShadow();
  c.addRimGlow();
  c.fillRoundRect(82, 100, 92, 88, 12, ...hex('#374151'), 245);
  c.fillRoundRect(88, 108, 80, 72, 8, ...hex('#1f2937'), 255);
  const brass = hex('#ca8a04');
  const tip = hex('#78716c');
  for (let i = 0; i < 5; i++) {
    const x = 96 + i * 14;
    c.fillRoundRect(x, 118 - i * 2, 10, 32, 3, ...brass, 255);
    c.fillRoundRect(x + 1, 108 - i * 2, 8, 12, 2, ...tip, 255);
  }
  c.fillRect(118, 92, 20, 18, ...hex('#4b5563'), 255);
}

function drawAmmoRifle(c) {
  c.addGroundShadow();
  c.addRimGlow();
  const brass = hex('#b8860b');
  const body = hex('#57534e');
  const tip = hex('#365314');
  [[94, 130], [118, 124], [142, 130]].forEach(([x, y], i) => {
    const h = 48 - i * 4;
    c.fillRoundRect(x - 6, y - h + 20, 12, h, 3, ...brass, 255 - i * 15);
    c.fillRoundRect(x - 4, y - h + 4, 8, 18, 2, ...body, 255);
    c.fillRoundRect(x - 3, y - h, 6, 10, 2, ...tip, 255);
  });
  c.fillRoundRect(156, 118, 28, 36, 6, ...hex('#292524'), 230);
}

function drawAmmoShotgun(c) {
  c.addGroundShadow();
  c.addRimGlow();
  [[88, 132], [118, 126], [148, 132]].forEach(([x, y]) => {
    c.fillRoundRect(x, y, 52, 18, 8, ...hex('#dc2626'), 255);
    c.fillRoundRect(x, y + 10, 52, 8, 4, ...hex('#b91c1c'), 255);
    c.fillRoundRect(x - 4, y + 2, 10, 14, 3, ...hex('#d4a017'), 255);
    c.fillRect(x + 8, y + 4, 36, 3, ...STYLE.highlight, 50);
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
  drawMushroomDetailed(c, cap, [255, 255, 255], stem, cap[0] < 200);
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
  c.fillCircle(CX, CY + 82, 70, 16, ...hex('#000000'), 40);
  // platform glass
  c.fillRoundRect(52, 148, 152, 22, 8, ...hex('#d4d4d8'), 255);
  c.fillRoundRect(58, 152, 140, 10, 5, ...hex('#f4f4f5'), 220);
  c.fillRect(72, 154, 48, 3, ...STYLE.highlight, 70);
  // feet
  [[68, 172], [104, 172], [152, 172], [188, 172]].forEach(([x, y]) => {
    c.fillRoundRect(x, y, 16, 10, 4, ...hex('#3f3f46'), 255);
  });
  // body
  c.fillRoundRect(64, 108, 128, 44, 10, ...hex('#18181b'), 255);
  c.fillRoundRect(70, 112, 116, 36, 8, ...hex('#27272a'), 255);
  c.strokeRoundRect(78, 118, 100, 24, 6, ...hex('#52525b'), 255, 200, 2);
  // LCD
  c.fillRoundRect(82, 122, 92, 16, 4, ...hex('#022c22'), 255);
  c.fillRect(88, 126, 44, 3, ...hex('#4ade80'), 255);
  c.fillRect(136, 126, 10, 3, ...hex('#4ade80'), 200);
  c.fillRect(150, 126, 16, 3, ...hex('#22c55e'), 160);
  // display label
  c.fillRoundRect(108, 98, 40, 14, 4, ...hex('#a1a1aa'), 255);
  c.fillRect(112, 102, 32, 4, ...hex('#71717a'), 180);
  // side buttons
  c.fillCircle(58, 130, 4, 4, ...hex('#52525b'), 255);
  c.fillCircle(198, 130, 4, 4, ...hex('#52525b'), 255);
  // highlight
  c.fillRect(72, 114, 36, 2, ...STYLE.highlight, 45);
}

function drawGloves(c) {
  c.addGroundShadow();
  const glove = hex('#3f3f46');
  const dark = hex('#18181b');
  c.fillRoundRect(62, 104, 56, 92, 20, ...glove, 255);
  c.fillRoundRect(138, 104, 56, 92, 20, ...glove, 255);
  c.fillRoundRect(70, 112, 22, 64, 10, ...dark, 90);
  c.fillRoundRect(164, 112, 22, 64, 10, ...dark, 90);
  [76, 86, 96].forEach((x) => c.fillRect(x, 122, 4, 32, ...dark, 110));
  [152, 162, 172].forEach((x) => c.fillRect(x, 122, 4, 32, ...dark, 110));
}

function drawGrowPot(c) {
  c.addGroundShadow();
  c.fillCircle(CX, CY + 86, 74, 18, ...hex('#000000'), 42);
  const rim = hex('#a1a1aa');
  const rimDark = hex('#52525b');
  const pot = hex('#27272a');
  const potDark = hex('#09090b');
  const soil = hex('#92400e');
  const soilLight = hex('#b45309');
  const soilDark = hex('#451a03');
  // rim
  c.fillRoundRect(58, 62, 140, 28, 10, ...rimDark, 255);
  c.fillRoundRect(62, 64, 132, 20, 8, ...rim, 255);
  c.fillRect(66, 66, 124, 6, ...STYLE.highlight, 55);
  c.fillRect(62, 78, 132, 4, ...potDark, 200);
  // body
  c.fillRoundRect(68, 82, 120, 108, 10, ...potDark, 255);
  c.fillRoundRect(74, 86, 108, 100, 8, ...pot, 255);
  c.fillRect(78, 90, 16, 88, ...STYLE.highlight, 22);
  c.fillRect(162, 94, 10, 80, ...potDark, 90);
  // soil
  c.fillRoundRect(80, 96, 96, 72, 8, ...soilDark, 255);
  c.fillRoundRect(84, 100, 88, 58, 6, ...soil, 255);
  c.fillRoundRect(88, 104, 80, 20, 5, ...soilLight, 140);
  [[100, 118], [128, 126], [148, 112], [112, 140], [136, 148]].forEach(([x, y]) => {
    c.fillCircle(x, y, 3, 2, ...soilDark, 120);
  });
  // inner shadow
  c.fillRect(74, 170, 108, 8, ...potDark, 160);
}

function drawTrimScissors(c) {
  c.addGroundShadow();
  const blade = hex('#f4f4f5');
  const bladeEdge = hex('#a1a1aa');
  const handle = hex('#ea580c');
  const pivot = hex('#52525b');
  c.fillCircle(86, 172, 30, 30, ...handle, 255);
  c.fillCircle(170, 172, 30, 30, ...handle, 255);
  c.fillCircle(86, 172, 15, 15, ...hex('#18181b'), 255);
  c.fillCircle(170, 172, 15, 15, ...hex('#18181b'), 255);
  c.fillCircle(128, 138, 11, 11, ...pivot, 255);
  for (let i = 0; i < 48; i++) {
    const t = i / 48;
    const w = 10 - t * 5;
    c.fillCircle(98 + t * 22, 138 - t * 76, w, w * 0.45, ...blade, 245);
    c.fillCircle(158 - t * 22, 138 - t * 76, w, w * 0.45, ...blade, 245);
  }
  c.fillCircle(108, 56, 5, 14, ...bladeEdge, 255);
  c.fillCircle(148, 56, 5, 14, ...bladeEdge, 255);
  c.fillRect(118, 150, 20, 4, ...bladeEdge, 200);
}

function drawWateringCan(c) {
  c.addGroundShadow();
  c.fillCircle(CX, CY + 84, 76, 18, ...hex('#000000'), 42);
  const body = hex('#65a30d');
  const bodyMid = hex('#4d7c0f');
  const bodyDark = hex('#365314');
  const accent = hex('#bef264');
  const water = hex('#38bdf8');
  const waterLight = hex('#7dd3fc');
  const brass = hex('#ca8a04');
  // main body
  c.fillRoundRect(62, 108, 108, 96, 22, ...bodyDark, 255);
  c.fillRoundRect(68, 112, 96, 88, 18, ...body, 255);
  c.fillRoundRect(74, 118, 84, 72, 14, ...bodyMid, 200);
  c.fillRect(76, 116, 28, 70, ...STYLE.highlight, 28);
  // water window
  c.fillRoundRect(82, 136, 68, 48, 10, ...water, 190);
  c.fillRoundRect(86, 140, 60, 14, 6, ...waterLight, 120);
  c.fillRect(88, 158, 56, 20, ...water, 160);
  // handle arch
  for (let a = 0; a <= Math.PI; a += 0.08) {
    const x = 118 + Math.cos(a) * 46;
    const y = 108 - Math.sin(a) * 34;
    c.fillCircle(x, y, 7, 7, ...accent, 255);
    c.fillCircle(x, y, 4, 4, ...bodyDark, 80);
  }
  c.fillRoundRect(104, 88, 24, 16, 8, ...bodyDark, 220);
  // spout
  c.fillRoundRect(158, 124, 44, 22, 8, ...bodyDark, 255);
  c.fillRoundRect(164, 128, 36, 14, 6, ...bodyMid, 255);
  c.fillRoundRect(196, 126, 28, 18, 6, ...brass, 255);
  c.fillCircle(224, 135, 7, 7, ...hex('#fde047'), 255);
  c.fillCircle(224, 135, 4, 4, ...hex('#facc15'), 200);
  // rose holes
  [[218, 132], [226, 130], [222, 138]].forEach(([x, y]) => {
    c.fillCircle(x, y, 2, 2, ...bodyDark, 200);
  });
  // cap
  c.fillRoundRect(92, 104, 20, 10, 4, ...bodyDark, 230);
  c.fillRect(96, 106, 12, 3, ...accent, 180);
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
  if (tip === 'pistol') drawAmmoPistol(c);
  else if (tip === 'smg') drawAmmoSmg(c);
  else if (tip === 'rifle') drawAmmoRifle(c);
  else if (tip === 'shotgun') drawAmmoShotgun(c);
  else drawAmmoPistol(c);
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
  c.addRimGlow();
  c.fillRoundRect(88, 108, 80, 56, 12, 120, 200, 230, 230);
  for (let i = 0; i < 4; i++) c.fillCircle(104 + i * 16, 132, 6, 6, ...STYLE.highlight, 100);
}

function drawPoppy(c) {
  c.addGroundShadow();
  c.addRimGlow();
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2 - Math.PI / 2;
    c.fillCircle(CX + Math.cos(a) * 38, CY + Math.sin(a) * 30, 24, 16, ...hex('#ef4444'), 235);
  }
  c.fillCircle(CX, CY, 20, 20, ...hex('#3f3f46'), 255);
  c.fillRect(124, 148, 8, 28, ...hex('#166534'), 255);
}

function fillEllipseRotated(c, cx, cy, rx, ry, angle, r, g, b, a = 255) {
  const cos = Math.cos(angle);
  const sin = Math.sin(angle);
  const rMax = Math.ceil(Math.max(rx, ry) * 1.6);
  for (let y = Math.floor(cy - rMax); y <= cy + rMax; y += 1) {
    for (let x = Math.floor(cx - rMax); x <= cx + rMax; x += 1) {
      const lx = (x - cx) * cos + (y - cy) * sin;
      const ly = -(x - cx) * sin + (y - cy) * cos;
      if ((lx * lx) / (rx * rx) + (ly * ly) / (ry * ry) <= 1) c.blend(x, y, r, g, b, a);
    }
  }
}

function drawCocaLeafSingle(c, cx, cy, angle, scale, tone) {
  const leaf = hex(tone);
  const dark = shade(leaf, 0.72);
  const light = shade(leaf, 1.18);
  const rx = 34 * scale;
  const ry = 16 * scale;
  fillEllipseRotated(c, cx, cy, rx, ry, angle, ...leaf, 245);
  fillEllipseRotated(c, cx - Math.cos(angle) * 4, cy - Math.sin(angle) * 4, rx * 0.92, ry * 0.88, angle, ...dark, 70);
  fillEllipseRotated(c, cx - Math.cos(angle + 0.35) * 8, cy - Math.sin(angle + 0.35) * 8, rx * 0.22, ry * 0.72, angle, ...dark, 120);
  fillEllipseRotated(c, cx + Math.cos(angle + 0.2) * 10, cy + Math.sin(angle + 0.2) * 10, rx * 0.18, ry * 0.55, angle, ...light, 85);
}

function drawCocaLeaf(c) {
  c.addGroundShadow();
  c.addRimGlow();
  const stem = hex('#4d7c0f');
  c.fillRoundRect(124, 148, 8, 42, 4, ...stem, 255);
  c.fillRoundRect(120, 144, 16, 10, 4, ...shade(stem, 0.85), 255);
  const leaves = [
    [128, 118, -0.15, 1.05, '#22c55e'],
    [104, 128, -0.72, 0.95, '#16a34a'],
    [152, 128, 0.72, 0.95, '#16a34a'],
    [116, 104, -0.42, 0.82, '#15803d'],
    [140, 104, 0.42, 0.82, '#15803d'],
  ];
  leaves.forEach(([x, y, ang, sc, tone]) => drawCocaLeafSingle(c, x, y, ang, sc, tone));
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
  weed_leaf: () => { const c = new Canvas(); drawCannabisLeaf(c, 1); return c; },
  weed_buds: () => { const c = new Canvas(); drawWeedBudsIcon(c); return c; },
  weed_resin: () => {
    const c = new Canvas();
    c.addGroundShadow();
    c.addRimGlow();
    c.strokeRoundRect(88, 72, 80, 108, 12, 200, 210, 225, 240, 3);
    c.fillRoundRect(94, 92, 68, 76, 10, ...hex('#84cc16'), 230);
    c.fillRoundRect(102, 100, 52, 48, 8, ...hex('#a3e635'), 220);
    c.fillCircle(128, 118, 18, 14, ...hex('#ecfccb'), 180);
    c.fillRect(104, 58, 48, 22, 160, 165, 175, 255);
    c.fillRect(110, 64, 36, 8, ...hex('#fde047'), 200);
    return c;
  },
  weed_seed: () => { const c = new Canvas(); drawPills(c, [hex('#8B7355'), hex('#6d5a44'), hex('#a89070')]); return c; },
  weed_baggy: () => { const c = new Canvas(); drawZipBag(c, hex('#22c55e'), hex('#16a34a')); return c; },
  weed_baggy_empty: () => { const c = new Canvas(); drawBag(c, hex('#d8dee9'), hex('#c5ccd8'), false); return c; },
  weed_brick: () => { const c = new Canvas(); drawBrick(c, hex('#166534')); return c; },
  coca_leaf: () => { const c = new Canvas(); drawCocaLeaf(c); return c; },
  cocaine_paste: () => { const c = new Canvas(); drawJar(c, hex('#fef9c3'), 'chem'); return c; },
  cocaine_powder_loose: () => { const c = new Canvas(); drawZipBag(c, hex('#fafafa'), hex('#e5e5e5'), 'coke'); return c; },
  cocaine_baggy: () => { const c = new Canvas(); drawZipBag(c, hex('#ffffff'), hex('#d4d4d4'), 'coke'); return c; },
  coke_small_brick: () => { const c = new Canvas(); drawCokeBrickIcon(c); return c; },
  coke_brick: () => { const c = new Canvas(); drawCokeBrickIcon(c); return c; },
  poppy_flower: () => { const c = new Canvas(); drawPoppy(c); return c; },
  heroin_powder_loose: () => { const c = new Canvas(); drawZipBag(c, hex('#92400e'), hex('#78350f')); return c; },
  heroin_bag: () => { const c = new Canvas(); drawZipBag(c, hex('#b45309'), hex('#92400e')); return c; },
  meth_crystal: () => { const c = new Canvas(); drawCrystals(c, hex('#38bdf8')); return c; },
  meth_baggy: () => { const c = new Canvas(); drawZipBag(c, hex('#0ea5e9'), hex('#0284c7'), 'meth'); return c; },
  mushroom_raw: () => { const c = new Canvas(); drawMushroomDetailed(c, hex('#ef4444'), [255, 255, 255], hex('#fef3c7'), false); return c; },
  mushroom_dried: () => { const c = new Canvas(); drawMushroomDetailed(c, hex('#a78bfa'), [200, 200, 200], hex('#e7e5e4'), true); return c; },
  mushroom_pack: () => { const c = new Canvas(); drawZipBag(c, hex('#c4b5fd'), hex('#a78bfa')); return c; },
  joint: () => { const c = new Canvas(); drawJointIcon(c); return c; },
  crack_baggy: () => { const c = new Canvas(); drawZipBag(c, hex('#f5f5f4'), hex('#d6d3d1')); return c; },
  xtc_baggy: () => { const c = new Canvas(); drawZipBag(c, hex('#f472b6'), hex('#ec4899')); return c; },
  oxy: () => { const c = new Canvas(); drawPills(c, [hex('#f8fafc'), hex('#e2e8f0')]); return c; },
  amp_precursor: () => { const c = new Canvas(); drawJar(c, hex('#fdba74'), 'chem'); return c; },
  amp_paste: () => { const c = new Canvas(); drawJar(c, hex('#fb923c'), 'chem'); return c; },
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
  grow_pot: () => { const c = new Canvas(); drawGrowPot(c); return c; },
  trimming_scissors: () => { const c = new Canvas(); drawTrimScissors(c); return c; },
  watering_can: () => { const c = new Canvas(); drawWateringCan(c); return c; },
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
  cartel_blend: 'cocaine_powder_loose',
  heroin_paste: 'heroin_powder_loose',
  meth: 'meth_baggy',
  meth_ingredient: 'amp_precursor',
  rolling_paper: 'ocb_papers',
  cokebaggy: 'cocaine_baggy',
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
const onlyArg = process.argv.find((a) => a.startsWith('--only='));
const onlySet = onlyArg ? new Set(onlyArg.slice(7).split(',').map((s) => s.trim()).filter(Boolean)) : null;

for (const name of Object.keys(GENERATORS)) {
  if (onlySet && !onlySet.has(name)) continue;
  if (writeIcon(name)) {
    console.log('generated', `${name}.png`);
    count++;
  }
}

for (const [dest, src] of Object.entries(EXTRA_COPIES)) {
  if (onlySet && !onlySet.has(dest)) continue;
  const srcPath = path.join(imagesDir, `${src}.png`);
  const destPath = path.join(imagesDir, `${dest}.png`);
  if (fs.existsSync(srcPath)) {
    fs.copyFileSync(srcPath, destPath);
    console.log('copied', `${dest}.png`, '<-', `${src}.png`);
    count++;
  }
}

console.log(`Done. ${count} icon file(s).`);
