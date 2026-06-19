/**
 * Kokainmedžio lapų inventoriaus ikona iš cocaineleaf.png (QB illustrated stilius).
 * Usage: node make-coca-leaf-icon.mjs
 */
import fs from 'fs';
import path from 'path';
import { PNG } from 'pngjs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..', '..');
const SIZE = 256;
const SRC = path.join(ROOT, 'resources', '[qb]', 'qb-inventory', 'html', 'images', 'cocaineleaf.png');
const OUT = path.join(ROOT, 'resources', '[qb]', 'qb-inventory', 'html', 'images', 'coca_leaf.png');

function mildBrightness(data) {
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) continue;
    const r = data[i];
    const g = data[i + 1];
    const b = data[i + 2];
    const lum = 0.299 * r + 0.587 * g + 0.114 * b;
    if (lum < 2) continue;
    const nl = Math.min(255, lum * 1.06 + 4);
    const f = nl / lum;
    data[i] = Math.min(255, r * f);
    data[i + 1] = Math.min(255, g * f);
    data[i + 2] = Math.min(255, b * f);
  }
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
  for (const [px, py, wt] of [[x0, y0, (1 - tx) * (1 - ty)], [x1, y0, tx * (1 - ty)], [x0, y1, (1 - tx) * ty], [x1, y1, tx * ty]]) {
    const i = (py * w + px) << 2;
    out[0] += data[i] * wt;
    out[1] += data[i + 1] * wt;
    out[2] += data[i + 2] * wt;
    out[3] += data[i + 3] * wt;
  }
  return out;
}

function trimAndPad(src, fit = 0.9) {
  const { w, h, data } = src;
  let minX = w;
  let minY = h;
  let maxX = 0;
  let maxY = 0;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = (w * y + x) << 2;
      if (data[i] + data[i + 1] + data[i + 2] > 24 && data[i + 3] > 20) {
        minX = Math.min(minX, x);
        minY = Math.min(minY, y);
        maxX = Math.max(maxX, x);
        maxY = Math.max(maxY, y);
      }
    }
  }
  if (maxX <= minX) return src;
  const pad = Math.round(Math.max(maxX - minX, maxY - minY) * 0.05);
  minX = Math.max(0, minX - pad);
  minY = Math.max(0, minY - pad);
  maxX = Math.min(w - 1, maxX + pad);
  maxY = Math.min(h - 1, maxY + pad);
  const tw = maxX - minX + 1;
  const th = maxY - minY + 1;
  const canvas = new Uint8Array(SIZE * SIZE * 4);
  const scale = Math.min((SIZE * fit) / tw, (SIZE * fit) / th);
  const dw = Math.round(tw * scale);
  const dh = Math.round(th * scale);
  const ox = Math.round((SIZE - dw) / 2);
  const oy = Math.round((SIZE - dh) / 2);
  for (let y = 0; y < dh; y++) {
    for (let x = 0; x < dw; x++) {
      const sx = minX + ((x + 0.5) / dw) * tw - 0.5;
      const sy = minY + ((y + 0.5) / dh) * th - 0.5;
      const [r, g, b, a] = sampleBilinear({ w, h, data }, sx, sy);
      if (a < 8) continue;
      const di = (SIZE * (oy + y) + (ox + x)) << 2;
      canvas[di] = Math.round(r);
      canvas[di + 1] = Math.round(g);
      canvas[di + 2] = Math.round(b);
      canvas[di + 3] = Math.round(a);
    }
  }
  return { data: canvas, w: SIZE, h: SIZE };
}

if (!fs.existsSync(SRC)) {
  console.error('Missing source:', SRC);
  process.exit(1);
}

const png = PNG.sync.read(fs.readFileSync(SRC));
const data = Uint8Array.from(png.data);
mildBrightness(data);
const finalIcon = trimAndPad({ data, w: png.width, h: png.height }, 0.9);

const outPng = new PNG({ width: SIZE, height: SIZE });
outPng.data = Buffer.from(finalIcon.data);
fs.writeFileSync(OUT, PNG.sync.write(outPng));
console.log('OK', OUT, `(${png.width}x${png.height} -> ${SIZE}x${SIZE}, ${fs.statSync(OUT).size} bytes)`);
