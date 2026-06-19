/**
 * Normalizuoja ikonas į serverio standartą: 256px, permatomas fonas, be violetinio rimo.
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

const STYLE = { shadow: [8, 4, 18] };

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
    if (data[i + 3] === 0) continue;
    r += data[i]; g += data[i + 1]; b += data[i + 2];
    n++;
  }
  if (!n) return [0, 0, 0];
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
    const i = idx << 2;
    if (data[i + 3] === 0) return;
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
    const maxC = Math.max(r, g, b);
    const minC = Math.min(r, g, b);
    if (dist([r, g, b], bg) > 78 || (r < 55 && g < 55 && b < 55) || (maxC < 75 && maxC - minC < 20)) {
      data[i + 3] = 0;
      push(x + 1, y); push(x - 1, y); push(x, y + 1); push(x, y - 1);
    }
  }
}

function enhancePixels(data) {
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) continue;
    let r = data[i], g = data[i + 1], b = data[i + 2];
    if (r < 32 && g < 32 && b < 32) {
      data[i + 3] = 0;
      continue;
    }
    r = Math.min(255, ((r - 128) * 1.1 + 128) * 1.08 + 8);
    g = Math.min(255, ((g - 128) * 1.1 + 128) * 1.08 + 8);
    b = Math.min(255, ((b - 128) * 1.1 + 128) * 1.08 + 10);
    data[i] = r;
    data[i + 1] = g;
    data[i + 2] = b;
  }
}

function trimBounds(data, w, h) {
  let minX = w, minY = h, maxX = 0, maxY = 0;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (data[(w * y + x) << 2 + 3] > 8) {
        minX = Math.min(minX, x);
        minY = Math.min(minY, y);
        maxX = Math.max(maxX, x);
        maxY = Math.max(maxY, y);
      }
    }
  }
  if (maxX <= minX) return { data, w, h };
  const pad = 3;
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
    this.fillCircle(CX, CY + 78, 62, 18, ...STYLE.shadow, 45);
  }

  blitScaled(src, fitScale = 0.86) {
    const { w: sw, h: sh, data } = src;
    const maxW = SIZE * fitScale;
    const maxH = SIZE * fitScale;
    const scale = Math.min(maxW / sw, maxH / sh);
    const dw = Math.round(sw * scale);
    const dh = Math.round(sh * scale);
    const ox = Math.round((SIZE - dw) / 2);
    const oy = Math.round((SIZE - dh) / 2) - 2;
    for (let y = 0; y < dh; y++) {
      for (let x = 0; x < dw; x++) {
        const sx = Math.min(sw - 1, Math.floor((x / dw) * sw));
        const sy = Math.min(sh - 1, Math.floor((y / dh) * sh));
        const si = (sy * sw + sx) << 2;
        const a = data[si + 3];
        if (a < 10) continue;
        this.blend(ox + x, oy + y, data[si], data[si + 1], data[si + 2], a);
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

export function normalizeIconBuffer(buf) {
  const png = PNG.sync.read(buf);
  const data = Uint8Array.from(png.data);
  removeBackground(data, png.width, png.height);
  enhancePixels(data);
  const trimmed = trimBounds(data, png.width, png.height);
  const canvas = new Canvas();
  canvas.addGroundShadow();
  canvas.blitScaled(trimmed, 0.86);
  return canvas.toPng();
}

const names = process.argv.slice(2);
const targets = names.length
  ? names.map((n) => n.replace(/\.png$/i, ''))
  : fs.readdirSync(imagesDir).filter((f) => f.endsWith('.png')).map((f) => f.replace(/\.png$/i, ''));

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (!isMain) {
  // imported as module
} else {
let count = 0;
for (const name of targets) {
  const p = path.join(imagesDir, `${name}.png`);
  if (!fs.existsSync(p)) continue;
  const before = fs.statSync(p).size;
  try {
    const out = normalizeIconBuffer(fs.readFileSync(p));
    fs.writeFileSync(p, out);
    const after = fs.statSync(p).size;
    console.log('normalized', name, `${before} -> ${after}`);
    count++;
  } catch (e) {
    console.log('skip', name, e.message);
  }
}
console.log(`Done. ${count} icon(s).`);
}
