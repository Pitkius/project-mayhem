import fs from 'fs';
import path from 'path';
import { PNG } from 'pngjs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const imagesDir = path.join(__dirname, '..', 'resources', '[qb]', 'qb-inventory', 'html', 'images');
const TARGET = 256;

/** Naujos / atnaujintos narkotikų ir samagono ikonos */
const NAMES = [
  'cocaine_paste',
  'cocaine_powder_loose',
  'cocaine_baggy',
  'heroin_powder_loose',
  'heroin_bag',
  'chemical_mix',
  'weed_buds',
  'weed_leaf',
  'weed_resin',
  'moonshine_spirit',
  'poppy_flower',
  'heroin_paste',
  'cartel_pack',
  'coke_small_brick',
  'meth_crystal',
];

/** Stipresnis šviesinimas tamsesnėms ikonoms */
const BRIGHT_BOOST = {
  weed_buds: { lift: 42, mult: 1.34 },
  weed_leaf: { lift: 38, mult: 1.3 },
  weed_resin: { lift: 34, mult: 1.28 },
  poppy_flower: { lift: 32, mult: 1.26 },
};

const DEFAULT_BOOST = { lift: 26, mult: 1.22 };

function brightenRgb(r, g, b, boost) {
  const lift = boost.lift;
  const mult = boost.mult;
  return [
    Math.min(255, Math.round(r * mult + lift)),
    Math.min(255, Math.round(g * mult + lift)),
    Math.min(255, Math.round(b * mult + lift)),
  ];
}

function dist(a, b) {
  return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
}

function edgeFloodTransparent(data, w, h, tol) {
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
    const d = dist([r, g, b], bg);
    const maxC = Math.max(r, g, b);
    const minC = Math.min(r, g, b);
    if (d <= tol || (r < 55 && g < 55 && b < 55) || (maxC < 75 && maxC - minC < 20)) {
      data[i + 3] = 0;
      push(x + 1, y); push(x - 1, y); push(x, y + 1); push(x, y - 1);
    }
  }
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
  if (!n) return [0, 0, 0];
  return [Math.round(r / n), Math.round(g / n), Math.round(b / n)];
}

function processPng(buf, name) {
  const boost = BRIGHT_BOOST[name] || DEFAULT_BOOST;
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
  edgeFloodTransparent(out.data, TARGET, TARGET, 78);
  for (let i = 0; i < out.data.length; i += 4) {
    const r = out.data[i], g = out.data[i + 1], b = out.data[i + 2], a = out.data[i + 3];
    if (a === 0) continue;
    if (r < 32 && g < 32 && b < 32) {
      out.data[i + 3] = 0;
      continue;
    }
    const [nr, ng, nb] = brightenRgb(r, g, b, boost);
    out.data[i] = nr;
    out.data[i + 1] = ng;
    out.data[i + 2] = nb;
  }
  return PNG.sync.write(out);
}

let n = 0;
for (const name of NAMES) {
  const p = path.join(imagesDir, `${name}.png`);
  if (!fs.existsSync(p)) {
    console.log('missing', name);
    continue;
  }
  fs.writeFileSync(p, processPng(fs.readFileSync(p), name));
  console.log('fixed', name);
  n++;
}
console.log(`Done. ${n} file(s).`);
