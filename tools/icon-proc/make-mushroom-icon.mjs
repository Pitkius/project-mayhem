/**
 * Nuskintų grybų inventoriaus ikona iš HD nuotraukos (QB illustrated stilius, juodas fonas).
 * Usage: node make-mushroom-icon.mjs [source.png] [output.png]
 */
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { PNG } from 'pngjs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..', '..');
const SIZE = 256;
const DEFAULT_SRC = path.join(__dirname, 'sources', 'mushroom_raw_ref.png');
const DEFAULT_OUT = path.join(ROOT, 'resources', '[qb]', 'qb-inventory', 'html', 'images', 'mushroom_raw.png');

const args = process.argv.slice(2);
const srcPath = args[0]
  ? (path.isAbsolute(args[0]) ? args[0] : path.join(__dirname, args[0]))
  : DEFAULT_SRC;
const outPath = args[1]
  ? (path.isAbsolute(args[1]) ? args[1] : path.join(ROOT, 'resources', '[qb]', 'qb-inventory', 'html', 'images', args[1]))
  : DEFAULT_OUT;

function ensureSource() {
  if (fs.existsSync(srcPath) && fs.statSync(srcPath).size > 100_000) return;
  fs.mkdirSync(path.dirname(srcPath), { recursive: true });
  const buf = execSync('git show 2d937c37:resources/[qb]/qb-inventory/html/images/mushroom_raw.png', {
    cwd: ROOT,
    stdio: ['pipe', 'pipe', 'ignore'],
    maxBuffer: 50 * 1024 * 1024,
  });
  fs.writeFileSync(srcPath, buf);
}

function mildBrightness(data) {
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) continue;
    const r = data[i];
    const g = data[i + 1];
    const b = data[i + 2];
    const lum = 0.299 * r + 0.587 * g + 0.114 * b;
    const nl = Math.min(255, lum * 1.05 + 3);
    if (lum < 2) continue;
    const f = nl / lum;
    data[i] = Math.min(255, r * f);
    data[i + 1] = Math.min(255, g * f);
    data[i + 2] = Math.min(255, b * f);
  }
}

function centerSquareCrop(data, w, h) {
  const side = Math.min(w, h);
  const ox = Math.floor((w - side) / 2);
  const oy = Math.floor((h - side) / 2);
  const out = new Uint8Array(side * side * 4);
  for (let y = 0; y < side; y++) {
    for (let x = 0; x < side; x++) {
      const si = ((oy + y) * w + (ox + x)) << 2;
      const di = (side * y + x) << 2;
      out[di] = data[si];
      out[di + 1] = data[si + 1];
      out[di + 2] = data[si + 2];
      out[di + 3] = data[si + 3];
    }
  }
  return { data: out, w: side, h: side };
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

function scaleToSquare(src, size) {
  const out = new Uint8Array(size * size * 4);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const sx = ((x + 0.5) / size) * src.w - 0.5;
      const sy = ((y + 0.5) / size) * src.h - 0.5;
      const [r, g, b, a] = sampleBilinear(src, sx, sy);
      const di = (size * y + x) << 2;
      out[di] = Math.round(r);
      out[di + 1] = Math.round(g);
      out[di + 2] = Math.round(b);
      out[di + 3] = Math.round(a);
    }
  }
  return { data: out, w: size, h: size };
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
  const pad = Math.round(Math.max(maxX - minX, maxY - minY) * 0.04);
  minX = Math.max(0, minX - pad);
  minY = Math.max(0, minY - pad);
  maxX = Math.min(w - 1, maxX + pad);
  maxY = Math.min(h - 1, maxY + pad);
  const tw = maxX - minX + 1;
  const th = maxY - minY + 1;
  const side = Math.max(tw, th);
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

ensureSource();

const png = PNG.sync.read(fs.readFileSync(srcPath));
const data = Uint8Array.from(png.data);
mildBrightness(data);
const cropped = centerSquareCrop(data, png.width, png.height);
const scaled = scaleToSquare(cropped, SIZE);
const finalIcon = trimAndPad(scaled, 0.92);

fs.mkdirSync(path.dirname(outPath), { recursive: true });
const outPng = new PNG({ width: SIZE, height: SIZE });
outPng.data = Buffer.from(finalIcon.data);
fs.writeFileSync(outPath, PNG.sync.write(outPng));
console.log('OK', outPath, `(${png.width}x${png.height} -> ${SIZE}x${SIZE}, ${fs.statSync(outPath).size} bytes)`);
