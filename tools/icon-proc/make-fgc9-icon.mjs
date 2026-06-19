/**
 * FGC-9 inventoriaus ikona (QB illustrated + MRP violet rim).
 * Naudoja švarią FGC-9 nuotrauką, apdoroja kaip kitas ginklų ikonas.
 * Usage: node make-fgc9-icon.mjs [source.jpg|png]
 */
import fs from 'fs';
import path from 'path';
import jpeg from 'jpeg-js';
import { PNG } from 'pngjs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..', '..');
const SIZE = 256;
const CX = SIZE / 2;
const CY = SIZE / 2;

const DEFAULT_SRC = path.join(__dirname, 'sources', 'weapon_fgc9_clean.jpg');
const OUT = path.join(ROOT, 'resources', '[qb]', 'qb-inventory', 'html', 'images', 'weapon_fgc9.png');

const STYLE = {
  rim: [168, 85, 247],
  rimAlpha: 0.11,
  shadow: [8, 4, 18],
};

function loadImage(filePath) {
  const buf = fs.readFileSync(filePath);
  const ext = path.extname(filePath).toLowerCase();
  if (ext === '.jpg' || ext === '.jpeg') {
    const decoded = jpeg.decode(buf, { useTArray: true });
    return { data: Uint8Array.from(decoded.data), w: decoded.width, h: decoded.height };
  }
  const png = PNG.sync.read(buf);
  return { data: Uint8Array.from(png.data), w: png.width, h: png.height };
}

function dist(a, b) {
  return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
}

function removeLightBackground(data, w, h) {
  const visited = new Uint8Array(w * h);
  const q = [];
  const push = (x, y) => {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    const idx = y * w + x;
    if (visited[idx]) return;
    visited[idx] = 1;
    q.push([x, y]);
  };
  for (let x = 0; x < w; x++) {
    push(x, 0);
    push(x, h - 1);
  }
  for (let y = 0; y < h; y++) {
    push(0, y);
    push(w - 1, y);
  }
  while (q.length) {
    const [x, y] = q.pop();
    const i = (w * y + x) << 2;
    const r = data[i], g = data[i + 1], b = data[i + 2];
    const lum = 0.299 * r + 0.587 * g + 0.114 * b;
    if (lum < 238 && dist([r, g, b], [255, 255, 255]) > 24) continue;
    data[i + 3] = 0;
    push(x + 1, y); push(x - 1, y); push(x, y + 1); push(x, y - 1);
  }
}

function boostVisibleGun(data) {
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) continue;
    let r = data[i], g = data[i + 1], b = data[i + 2];
    const lum = 0.299 * r + 0.587 * g + 0.114 * b;
    const lifted = Math.min(195, lum * 1.55 + 48);
    const f = lifted / Math.max(lum, 1);
    r = Math.min(255, r * f + 6);
    g = Math.min(255, g * f + 4);
    b = Math.min(255, b * f * 1.06 + 10);
    data[i] = r;
    data[i + 1] = g;
    data[i + 2] = b;
    data[i + 3] = 255;
  }
}

function flipHorizontal(src) {
  const { w, h, data } = src;
  const out = new Uint8Array(data.length);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const si = (w * y + x) << 2;
      const di = (w * y + (w - 1 - x)) << 2;
      out[di] = data[si];
      out[di + 1] = data[si + 1];
      out[di + 2] = data[si + 2];
      out[di + 3] = data[si + 3];
    }
  }
  return { data: out, w, h };
}

function mildBrightness(data) {
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) continue;
    const r = data[i], g = data[i + 1], b = data[i + 2];
    const lum = 0.299 * r + 0.587 * g + 0.114 * b;
    const nl = Math.min(255, lum * 1.06 + 4);
    if (lum < 2) continue;
    const f = nl / lum;
    data[i] = Math.min(255, r * f);
    data[i + 1] = Math.min(255, g * f);
    data[i + 2] = Math.min(255, b * f);
  }
}

function trimBounds(data, w, h) {
  let minX = w, minY = h, maxX = 0, maxY = 0;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (data[((w * y + x) << 2) + 3] > 12) {
        minX = Math.min(minX, x);
        minY = Math.min(minY, y);
        maxX = Math.max(maxX, x);
        maxY = Math.max(maxY, y);
      }
    }
  }
  if (maxX <= minX) return { data, w, h };
  const pad = 4;
  minX = Math.max(0, minX - pad);
  minY = Math.max(0, minY - pad);
  maxX = Math.min(w - 1, maxX + pad);
  maxY = Math.min(h - 1, maxY + pad);
  const nw = maxX - minX + 1;
  const nh = maxY - minY + 1;
  const out = new Uint8Array(nw * nh * 4);
  for (let y = 0; y < nh; y++) {
    for (let x = 0; x < nw; x++) {
      const si = (w * (minY + y) + (minX + x)) << 2;
      const di = (nw * y + x) << 2;
      out[di] = data[si];
      out[di + 1] = data[si + 1];
      out[di + 2] = data[si + 2];
      out[di + 3] = data[si + 3];
    }
  }
  return { data: out, w: nw, h: nh };
}

function sampleBilinear(src, sx, sy) {
  const { w, h, data } = src;
  const x = Math.max(0, Math.min(w - 1.001, sx));
  const y = Math.max(0, Math.min(h - 1.001, sy));
  const x0 = Math.floor(x);
  const y0 = Math.floor(y);
  const x1 = Math.min(w - 1, x0 + 1);
  const y1 = Math.min(h - 1, y0 + 1);
  const tx = x - x0;
  const ty = y - y0;
  const out = [0, 0, 0, 0];
  for (const [px, py, wgt] of [[x0, y0, (1 - tx) * (1 - ty)], [x1, y0, tx * (1 - ty)], [x0, y1, (1 - tx) * ty], [x1, y1, tx * ty]]) {
    const i = (h * py + px) << 2;
    out[0] += data[i] * wgt;
    out[1] += data[i + 1] * wgt;
    out[2] += data[i + 2] * wgt;
    out[3] += data[i + 3] * wgt;
  }
  return out;
}

function rotateSubject(src, degrees) {
  const rad = (degrees * Math.PI) / 180;
  const cos = Math.cos(rad);
  const sin = Math.sin(rad);
  const { w, h, data } = src;
  const cx = w / 2;
  const cy = h / 2;
  const corners = [
    [-cx, -cy], [w - cx, -cy], [-cx, h - cy], [w - cx, h - cy],
  ];
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  for (const [x, y] of corners) {
    const rx = x * cos - y * sin;
    const ry = x * sin + y * cos;
    minX = Math.min(minX, rx);
    minY = Math.min(minY, ry);
    maxX = Math.max(maxX, rx);
    maxY = Math.max(maxY, ry);
  }
  const nw = Math.ceil(maxX - minX);
  const nh = Math.ceil(maxY - minY);
  const out = new Uint8Array(nw * nh * 4);
  const ocx = nw / 2;
  const ocy = nh / 2;
  for (let y = 0; y < nh; y++) {
    for (let x = 0; x < nw; x++) {
      const lx = (x - ocx) * cos + (y - ocy) * sin + cx;
      const ly = -(x - ocx) * sin + (y - ocy) * cos + cy;
      const [r, g, b, a] = sampleBilinear({ w, h, data }, lx, ly);
      if (a < 8) continue;
      const di = (nw * y + x) << 2;
      out[di] = Math.round(r);
      out[di + 1] = Math.round(g);
      out[di + 2] = Math.round(b);
      out[di + 3] = Math.round(a);
    }
  }
  return { data: out, w: nw, h: nh };
}

class Canvas {
  constructor(size = SIZE) {
    this.size = size;
    this.px = new Float32Array(size * size * 4);
  }

  blend(x, y, r, g, b, a) {
    if (x < 0 || y < 0 || x >= this.size || y >= this.size) return;
    const i = (Math.floor(y) * this.size + Math.floor(x)) * 4;
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

  addGroundShadow() {
    this.fillCircle(CX, CY + 74, 56, 15, ...STYLE.shadow, 58);
  }

  addRimGlow() {
    this.fillCircle(CX, CY, 84, 84, ...STYLE.rim, Math.round(255 * 0.08));
  }

  blitScaled(src, fitScale = 0.9) {
    const sw = src.w;
    const sh = src.h;
    const maxW = SIZE * fitScale;
    const maxH = SIZE * fitScale;
    const scale = Math.min(maxW / sw, maxH / sh);
    const dw = Math.round(sw * scale);
    const dh = Math.round(sh * scale);
    const ox = Math.round((SIZE - dw) / 2);
    const oy = Math.round((SIZE - dh) / 2) - 6;
    for (let y = 0; y < dh; y++) {
      for (let x = 0; x < dw; x++) {
        const sx = Math.min(sw - 1, Math.floor((x / dw) * sw));
        const sy = Math.min(sh - 1, Math.floor((y / dh) * sh));
        const si = (sy * sw + sx) << 2;
        const a = src.data[si + 3];
        if (a < 10) continue;
        this.blend(ox + x, oy + y, src.data[si], src.data[si + 1], src.data[si + 2], a);
      }
    }
  }

  toPng() {
    const png = new PNG({ width: this.size, height: this.size });
    for (let i = 0; i < this.px.length; i++) {
      png.data[i] = Math.round(Math.min(255, Math.max(0, this.px[i])));
    }
    return PNG.sync.write(png);
  }
}

const srcArg = process.argv[2];
const srcPath = srcArg
  ? (path.isAbsolute(srcArg) ? srcArg : path.join(__dirname, 'sources', srcArg))
  : DEFAULT_SRC;

if (!fs.existsSync(srcPath)) {
  console.error('Source not found:', srcPath);
  process.exit(1);
}

const loaded = loadImage(srcPath);
const data = Uint8Array.from(loaded.data);
removeLightBackground(data, loaded.w, loaded.h);
boostVisibleGun(data);
mildBrightness(data);
let subject = trimBounds(data, loaded.w, loaded.h);
subject = flipHorizontal(subject);
subject = rotateSubject(subject, 42);
subject = trimBounds(subject.data, subject.w, subject.h);

const canvas = new Canvas();
canvas.addGroundShadow();
canvas.addRimGlow();
canvas.blitScaled(subject, 0.94);
fs.writeFileSync(OUT, canvas.toPng());
console.log('OK', OUT, `(${subject.w}x${subject.h})`);
