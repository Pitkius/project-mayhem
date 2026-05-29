import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { PNG } from 'pngjs';

const __dir = dirname(fileURLToPath(import.meta.url));
const IMAGES = join(__dir, '..', 'resources', '[qb]', 'qb-inventory', 'html', 'images');
const TARGET = 256;
const NAMES = [
  'basic_tablet', 'advanced_tablet', 'military_tablet',
  'basic_flashdrive', 'encrypted_flashdrive', 'military_flashdrive',
  'tow_chain', 'drill', 'thermite', 'security_card_01', 'security_card_02',
];

function dist(a, b) {
  return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
}

function cornerBg(data, w, h) {
  const pts = [[1, 1], [w - 2, 1], [1, h - 2], [w - 2, h - 2], [Math.floor(w / 2), 1], [Math.floor(w / 2), h - 2]];
  let r = 0, g = 0, b = 0;
  for (const [x, y] of pts) {
    const i = (w * y + x) << 2;
    r += data[i]; g += data[i + 1]; b += data[i + 2];
  }
  return [Math.round(r / pts.length), Math.round(g / pts.length), Math.round(b / pts.length)];
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
  const tol = 55;
  for (let i = 0; i < out.data.length; i += 4) {
    const r = out.data[i], g = out.data[i + 1], b = out.data[i + 2];
    if (out.data[i + 3] === 0) continue;
    const rgb = [r, g, b];
    if (dist(rgb, bg) <= tol) { out.data[i + 3] = 0; continue; }
    if (r > 160 && g > 160 && b > 160 && Math.max(r, g, b) - Math.min(r, g, b) < 30) out.data[i + 3] = 0;
    else if (r > 200 && g > 200 && b > 200) out.data[i + 3] = 0;
  }
  return PNG.sync.write(out);
}

let n = 0;
for (const name of NAMES) {
  const p = join(IMAGES, `${name}.png`);
  if (!existsSync(p)) { console.log('missing', name); continue; }
  writeFileSync(p, processPng(readFileSync(p)));
  console.log('fixed', name);
  n++;
}
console.log(`Done. ${n} file(s).`);
