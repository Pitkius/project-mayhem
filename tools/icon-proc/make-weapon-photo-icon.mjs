/**
 * Inventory weapon icon from in-game screenshot reference.
 * Usage: node make-weapon-photo-icon.mjs [source.png] [output.png]
 */
import fs from 'fs';
import path from 'path';
import { PNG } from 'pngjs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SIZE = 256;
const CX = SIZE / 2;
const CY = SIZE / 2;

const STYLE = {
  rim: [168, 85, 247],
  rimAlpha: 0.1,
  shadow: [8, 4, 18],
};

const args = process.argv.slice(2);
const srcFile = args[0] || 'weapon_fgc9_ingame.png';
const outName = args[1] || 'weapon_fgc9.png';
const rotateDeg = Number(args[2] || '-28');
const srcPath = path.isAbsolute(srcFile)
  ? srcFile
  : path.join(__dirname, 'sources', srcFile);
const outPath = path.isAbsolute(outName)
  ? outName
  : path.join(__dirname, '..', '..', 'resources', '[qb]', 'qb-inventory', 'html', 'images', outName);

function dist(a, b) {
  return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
}

function cornerBg(data, w, h) {
  const pts = [
    [0, 0], [w - 1, 0], [0, h - 1], [w - 1, h - 1],
    [1, 1], [w - 2, 1], [1, h - 2], [w - 2, h - 2],
  ];
  let r = 0, g = 0, b = 0, n = 0;
  for (const [x, y] of pts) {
    const i = (w * y + x) << 2;
    r += data[i]; g += data[i + 1]; b += data[i + 2];
    n++;
  }
  return [r / n, g / n, b / n];
}

function removeBackground(data, w, h) {
  const bg = cornerBg(data, w, h);
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
    if (dist([r, g, b], bg) > 78) continue;
    data[i + 3] = 0;
    push(x + 1, y); push(x - 1, y); push(x, y + 1); push(x, y - 1);
  }
}

function removeBlueGlove(data) {
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) continue;
    const r = data[i], g = data[i + 1], b = data[i + 2];
    if (b > 120 && b > r * 1.15 && b > g * 1.05 && g > 70) {
      data[i + 3] = 0;
    }
  }
}

function enhancePixels(data) {
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) continue;
    let r = data[i], g = data[i + 1], b = data[i + 2];
    r = Math.min(255, ((r - 128) * 1.14 + 128) * 1.12 + 12);
    g = Math.min(255, ((g - 128) * 1.14 + 128) * 1.12 + 12);
    b = Math.min(255, ((b - 128) * 1.14 + 128) * 1.12 + 14);
    data[i] = r;
    data[i + 1] = g;
    data[i + 2] = b;
  }
}

function trimBounds(data, w, h) {
  let minX = w, minY = h, maxX = 0, maxY = 0;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (data[((w * y + x) << 2) + 3] > 8) {
        minX = Math.min(minX, x);
        minY = Math.min(minY, y);
        maxX = Math.max(maxX, x);
        maxY = Math.max(maxY, y);
      }
    }
  }
  if (maxX <= minX) return { data, w, h };
  const pad = 2;
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
      const sx = Math.floor(lx);
      const sy = Math.floor(ly);
      if (sx < 0 || sy < 0 || sx >= w || sy >= h) continue;
      const si = (sy * w + sx) << 2;
      const di = (nw * y + x) << 2;
      out[di] = data[si];
      out[di + 1] = data[si + 1];
      out[di + 2] = data[si + 2];
      out[di + 3] = data[si + 3];
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
    this.fillCircle(CX, CY + 78, 62, 18, ...STYLE.shadow, 55);
  }

  addRimGlow() {
    this.fillCircle(CX, CY, 88, 88, ...STYLE.rim, Math.round(255 * STYLE.rimAlpha));
  }

  blitScaled(src, fitScale = 0.9) {
    const sw = src.w;
    const sh = src.h;
    const maxW = SIZE * fitScale;
    const maxH = SIZE * fitScale;
    let scale = Math.min(maxW / sw, maxH / sh);
    let dw = Math.round(sw * scale);
    let dh = Math.round(sh * scale);
    if (sw > sh * 4 && dh < SIZE * 0.28) {
      dh = Math.round(Math.min(maxH, dh * 2.1));
      dw = Math.round(Math.min(maxW, dw * 1.05));
    }
    const ox = Math.round((SIZE - dw) / 2);
    const oy = Math.round((SIZE - dh) / 2) - 2;
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

if (!fs.existsSync(srcPath)) {
  console.error('Source not found:', srcPath);
  process.exit(1);
}

const png = PNG.sync.read(fs.readFileSync(srcPath));
const data = Uint8Array.from(png.data);
removeBackground(data, png.width, png.height);
removeBlueGlove(data);
enhancePixels(data);
let trimmed = trimBounds(data, png.width, png.height);
if (rotateDeg) trimmed = rotateSubject(trimmed, rotateDeg);
const finalSubject = trimBounds(trimmed.data, trimmed.w, trimmed.h);

const canvas = new Canvas();
canvas.addGroundShadow();
canvas.addRimGlow();
canvas.blitScaled(finalSubject, 0.88);
fs.writeFileSync(outPath, canvas.toPng());
console.log('OK', outPath, `(${finalSubject.w}x${finalSubject.h} subject)`);
