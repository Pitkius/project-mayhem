const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const imagesDir = path.join(__dirname, '../../resources/[qb]/qb-inventory/html/images');
const TARGET = 256;
const TOL = 78;

function dist(a, b) {
  return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
}

function cornerBg(data, w, h) {
  const pts = [
    [0, 0], [w - 1, 0], [0, h - 1], [w - 1, h - 1],
    [1, 1], [w - 2, 1], [1, h - 2], [w - 2, h - 2],
    [Math.floor(w / 2), 1], [Math.floor(w / 2), h - 2],
  ];
  let r = 0, g = 0, b = 0, n = 0;
  for (const [x, y] of pts) {
    if (x < 0 || y < 0 || x >= w || y >= h) continue;
    const i = (w * y + x) << 2;
    if (data[i + 3] === 0) continue;
    r += data[i]; g += data[i + 1]; b += data[i + 2];
    n++;
  }
  if (!n) return [255, 255, 255];
  return [Math.round(r / n), Math.round(g / n), Math.round(b / n)];
}

function isBackgroundPixel(r, g, b, bg, lightBg) {
  const d = dist([r, g, b], bg);
  const maxC = Math.max(r, g, b);
  const minC = Math.min(r, g, b);
  if (d <= TOL) return true;
  if (lightBg) {
    if (minC > 198 && maxC - minC < 38) return true;
    if (r > 228 && g > 228 && b > 228) return true;
    return false;
  }
  if (r < 55 && g < 55 && b < 55) return true;
  if (maxC < 75 && maxC - minC < 20) return true;
  return false;
}

function edgeFloodTransparent(data, w, h, lightBg) {
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
  const bg = cornerBg(data, w, h);
  while (q.length) {
    const [x, y] = q.pop();
    const i = (w * y + x) << 2;
    const r = data[i], g = data[i + 1], b = data[i + 2];
    if (!isBackgroundPixel(r, g, b, bg, lightBg)) continue;
    data[i + 3] = 0;
    push(x + 1, y); push(x - 1, y); push(x, y + 1); push(x, y - 1);
  }
}

function processPng(buf) {
  const src = PNG.sync.read(buf);
  let { width: w, height: h, data } = src;
  const scale = TARGET / Math.max(w, h);
  if (scale !== 1) {
    const nw = Math.max(1, Math.round(w * scale));
    const nh = Math.max(1, Math.round(h * scale));
    const tmp = new PNG({ width: nw, height: nh });
    for (let y = 0; y < nh; y++) {
      for (let x = 0; x < nw; x++) {
        const sx = Math.min(w - 1, Math.floor(x / scale));
        const sy = Math.min(h - 1, Math.floor(y / scale));
        const si = (w * sy + sx) << 2;
        const di = (nw * y + x) << 2;
        tmp.data[di] = data[si];
        tmp.data[di + 1] = data[si + 1];
        tmp.data[di + 2] = data[si + 2];
        tmp.data[di + 3] = data[si + 3];
      }
    }
    w = nw; h = nh; data = tmp.data;
  }
  const out = new PNG({ width: TARGET, height: TARGET });
  out.data.fill(0);
  const ox = Math.floor((TARGET - w) / 2);
  const oy = Math.floor((TARGET - h) / 2);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const si = (w * y + x) << 2;
      const di = (TARGET * (oy + y) + (ox + x)) << 2;
      out.data[di] = data[si];
      out.data[di + 1] = data[si + 1];
      out.data[di + 2] = data[si + 2];
      out.data[di + 3] = data[si + 3];
    }
  }
  const bg = cornerBg(out.data, TARGET, TARGET);
  const lightBg = (bg[0] + bg[1] + bg[2]) > 382;
  edgeFloodTransparent(out.data, TARGET, TARGET, lightBg);
  for (let i = 0; i < out.data.length; i += 4) {
    const r = out.data[i], g = out.data[i + 1], b = out.data[i + 2];
    if (out.data[i + 3] === 0) continue;
    if (lightBg) {
      if (r > 235 && g > 235 && b > 235) out.data[i + 3] = 0;
    } else if (r < 32 && g < 32 && b < 32) {
      out.data[i + 3] = 0;
    }
  }
  return PNG.sync.write(out);
}

const files = process.argv.slice(2);
if (!files.length) {
  console.error('Usage: node process-icon-bg.js file1.png ...');
  process.exit(1);
}

for (const name of files) {
  const filePath = path.join(imagesDir, name);
  if (!fs.existsSync(filePath)) {
    console.log('missing', name);
    continue;
  }
  fs.writeFileSync(filePath, processPng(fs.readFileSync(filePath)));
  console.log('OK', name);
}
