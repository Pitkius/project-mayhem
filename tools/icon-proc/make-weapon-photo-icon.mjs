/**
 * Inventory weapon icon from photo reference.
 * Usage: node make-weapon-photo-icon.mjs [source] [output.png] [rotateDeg] [clean]
 */
import fs from 'fs';
import path from 'path';
import jpeg from 'jpeg-js';
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
const srcFile = args[0] || 'weapon_fgc9_clean.jpg';
const outName = args[1] || 'weapon_fgc9.png';
const rotateDeg = Number(args[2] || '-32');
const cleanMode = args[3] === 'clean' || /\.jpe?g$/i.test(args[0] || '');
const cropTopRatio = Math.max(0, Math.min(0.45, Number(args[4] || 0)));
const scopeOnly = args[5] === 'scope';
const srcPath = path.isAbsolute(srcFile)
  ? srcFile
  : path.join(__dirname, 'sources', srcFile);
const outPath = path.isAbsolute(outName)
  ? outName
  : path.join(__dirname, '..', '..', 'resources', '[qb]', 'qb-inventory', 'html', 'images', outName);

function dist(a, b) {
  return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
}

function loadRaster(filePath) {
  const buf = fs.readFileSync(filePath);
  if (/\.jpe?g$/i.test(filePath)) {
    const decoded = jpeg.decode(buf, { useTArray: true });
    const data = Uint8Array.from(decoded.data);
    for (let i = 0; i < data.length; i += 4) {
      data[i + 3] = 255;
    }
    return { data, w: decoded.width, h: decoded.height };
  }
  const png = PNG.sync.read(buf);
  return { data: Uint8Array.from(png.data), w: png.width, h: png.height };
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

function floodRemove(data, w, h, bg, tolerance) {
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
    if (dist([r, g, b], bg) > tolerance) continue;
    data[i + 3] = 0;
    push(x + 1, y); push(x - 1, y); push(x, y + 1); push(x, y - 1);
  }
}

function removeBackground(data, w, h) {
  floodRemove(data, w, h, cornerBg(data, w, h), 78);
}

function removeLightBackground(data, w, h) {
  floodRemove(data, w, h, [255, 255, 255], 92);
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) continue;
    const r = data[i], g = data[i + 1], b = data[i + 2];
    const lum = (r + g + b) / 3;
    const chroma = Math.max(r, g, b) - Math.min(r, g, b);
    if (lum > 188 && chroma < 32) {
      data[i + 3] = 0;
    }
  }
}

function cleanJpegFringe(data) {
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) continue;
    let r = data[i], g = data[i + 1], b = data[i + 2];
    const lum = (r + g + b) / 3;
    if (r > g + 22 && r > b + 22) {
      r = (g + b) * 0.5;
    }
    if (b > r + 18 && b > g + 12) {
      b = (r + g) * 0.5;
    }
    if (lum < 210) {
      const avg = (r + g + b) / 3;
      const mix = lum < 90 ? 0.72 : 0.38;
      r = r * (1 - mix) + avg * mix;
      g = g * (1 - mix) + avg * mix;
      b = b * (1 - mix) + avg * mix;
    }
    data[i] = Math.round(r);
    data[i + 1] = Math.round(g);
    data[i + 2] = Math.round(b);
  }
}

function removeWhiteMatte(data) {
  for (let i = 0; i < data.length; i += 4) {
    const a = data[i + 3];
    if (a === 0) continue;
    const r = data[i], g = data[i + 1], b = data[i + 2];
    const lum = (r + g + b) / 3;
    const chroma = Math.max(r, g, b) - Math.min(r, g, b);
    if (chroma < 30 && lum > 150) {
      const fade = Math.max(0, 255 - (lum - 145) * 3.2);
      data[i + 3] = Math.min(a, Math.round(fade));
    }
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

function enhancePixels(data, mild = false) {
  const gain = mild ? 1.06 : 1.14;
  const lift = mild ? 6 : 12;
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) continue;
    let r = data[i], g = data[i + 1], b = data[i + 2];
    r = Math.min(255, ((r - 128) * gain + 128) * gain + lift);
    g = Math.min(255, ((g - 128) * gain + 128) * gain + lift);
    b = Math.min(255, ((b - 128) * gain + 128) * gain + lift);
    data[i] = r;
    data[i + 1] = g;
    data[i + 2] = b;
  }
}

function cropTopOfSubject(data, w, h, ratio) {
  if (!ratio || ratio <= 0) return;
  let minY = h;
  let maxY = 0;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (data[((w * y + x) << 2) + 3] > 8) {
        minY = Math.min(minY, y);
        maxY = Math.max(maxY, y);
      }
    }
  }
  if (maxY <= minY) return;
  const cutY = minY + (maxY - minY) * ratio;
  for (let y = 0; y < h; y++) {
    if (y >= cutY) break;
    for (let x = 0; x < w; x++) {
      const i = (w * y + x) << 2;
      if (data[i + 3] > 8) data[i + 3] = 0;
    }
  }
}

/** Pašalina tik viršutinį taikiklį ir užpildo plyšį rail spalva. */
function removeScopeMount(data, w, h) {
  let minX = w;
  let minY = h;
  let maxX = 0;
  let maxY = 0;
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
  if (maxX <= minX || maxY <= minY) return;
  const sw = maxX - minX + 1;
  const sh = maxY - minY + 1;
  const y0 = Math.floor(minY + sh * 0.04);
  const y1 = Math.floor(minY + sh * 0.3);
  const x0 = Math.floor(minX + sw * 0.28);
  const x1 = Math.floor(minX + sw * 0.78);
  const sampleY = Math.min(maxY, y1 + 16);
  for (let y = y0; y <= y1; y++) {
    for (let x = x0; x <= x1; x++) {
      const srcX = Math.min(x1, Math.max(x0, x + ((y - y0) % 3) - 1));
      const si = (w * sampleY + srcX) << 2;
      const di = (w * y + x) << 2;
      if (data[si + 3] < 20) continue;
      data[di] = data[si];
      data[di + 1] = data[si + 1];
      data[di + 2] = data[si + 2];
      data[di + 3] = 255;
    }
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

function sampleBilinear(data, w, h, fx, fy) {
  const x = Math.max(0, Math.min(w - 1.001, fx));
  const y = Math.max(0, Math.min(h - 1.001, fy));
  const x0 = Math.floor(x);
  const y0 = Math.floor(y);
  const x1 = x0 + 1;
  const y1 = y0 + 1;
  const tx = x - x0;
  const ty = y - y0;
  const out = [0, 0, 0, 0];
  for (let c = 0; c < 4; c++) {
    const v00 = data[((y0 * w + x0) << 2) + c];
    const v10 = data[((y0 * w + x1) << 2) + c];
    const v01 = data[((y1 * w + x0) << 2) + c];
    const v11 = data[((y1 * w + x1) << 2) + c];
    out[c] = Math.round(
      v00 * (1 - tx) * (1 - ty) +
      v10 * tx * (1 - ty) +
      v01 * (1 - tx) * ty +
      v11 * tx * ty,
    );
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
      if (lx < 0 || ly < 0 || lx >= w - 1 || ly >= h - 1) continue;
      const [r, g, b, a] = sampleBilinear(data, w, h, lx, ly);
      const di = (nw * y + x) << 2;
      out[di] = r;
      out[di + 1] = g;
      out[di + 2] = b;
      out[di + 3] = a;
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
    const scale = Math.min(maxW / sw, maxH / sh);
    const dw = Math.round(sw * scale);
    const dh = Math.round(sh * scale);
    const ox = Math.round((SIZE - dw) / 2);
    const oy = Math.round((SIZE - dh) / 2) - 2;
    for (let y = 0; y < dh; y++) {
      for (let x = 0; x < dw; x++) {
        const fx = ((x + 0.5) / dw) * sw - 0.5;
        const fy = ((y + 0.5) / dh) * sh - 0.5;
        const [r, g, b, a] = sampleBilinear(src.data, sw, sh, fx, fy);
        if (a < 10) continue;
        this.blend(ox + x, oy + y, r, g, b, a);
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

const { data, w, h } = loadRaster(srcPath);
if (cleanMode || /\.jpe?g$/i.test(srcPath)) {
  removeLightBackground(data, w, h);
  cleanJpegFringe(data);
  removeWhiteMatte(data);
} else {
  removeBackground(data, w, h);
  removeBlueGlove(data);
  enhancePixels(data, false);
}
let trimmed = trimBounds(data, w, h);
if (scopeOnly) {
  removeScopeMount(trimmed.data, trimmed.w, trimmed.h);
  trimmed = trimBounds(trimmed.data, trimmed.w, trimmed.h);
}
if (rotateDeg) trimmed = rotateSubject(trimmed, rotateDeg);
let finalSubject = trimBounds(trimmed.data, trimmed.w, trimmed.h);
if (!scopeOnly && cropTopRatio > 0) {
  cropTopOfSubject(finalSubject.data, finalSubject.w, finalSubject.h, cropTopRatio);
  finalSubject = trimBounds(finalSubject.data, finalSubject.w, finalSubject.h);
}

const canvas = new Canvas();
if (!cleanMode) {
  canvas.addGroundShadow();
  canvas.addRimGlow();
}
canvas.blitScaled(finalSubject, cleanMode ? 0.9 : 0.88);
fs.writeFileSync(outPath, canvas.toPng());
console.log('OK', outPath, `(${finalSubject.w}x${finalSubject.h} subject, clean=${cleanMode}, cropTop=${cropTopRatio})`);
