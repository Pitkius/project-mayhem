/** Fit & validate MDT map projections. Run: node tools/mdt_map_fit.mjs */
import fs from "fs";
import { PNG } from "pngjs";

const IMG =
  "resources/[local]/mrp_ltpd/html/mdt/asset/gtav_satellite_2048.png";

const landmarks = [
  { name: "Paleto PD", gx: -448.15, gy: 6012.0 },
  { name: "Mt Chiliad", gx: 450.77, gy: 5566.86 },
  { name: "Sandy PD", gx: 1853.2, gy: 3686.5 },
  { name: "Grapeseed", gx: 1695.0, gy: 4785.0 },
  { name: "Harmony", gx: 611.0, gy: 2745.0 },
  { name: "Fort Zancudo", gx: -2360.0, gy: 3249.0 },
  { name: "Chumash", gx: -3192.0, gy: 1100.0 },
  { name: "Del Perro", gx: -1520.0, gy: -440.0 },
  { name: "Vespucci", gx: -1098.0, gy: -808.0 },
  { name: "MRPD", gx: 441.84, gy: -982.05 },
  { name: "Legion Sq", gx: 195.0, gy: -933.0 },
  { name: "Pillbox", gx: 311.0, gy: -590.0 },
  { name: "Davis PD", gx: 379.39, gy: -1591.37 },
  { name: "Grove St", gx: 85.0, gy: -1958.0 },
  { name: "LSIA", gx: -1037.0, gy: -2737.0 },
  { name: "Port docks", gx: 1206.24, gy: -3157.06 },
  { name: "Vinewood", gx: 293.0, gy: 180.0 },
  { name: "Rockford", gx: -800.0, gy: 180.0 },
  { name: "Lost MC", gx: 981.69, gy: -102.8 },
  { name: "ONeil farm", gx: 2452.28, gy: 4969.7 },
  { name: "La Mesa PD", gx: 826.0, gy: -1290.0 },
  { name: "Maze Bank", gx: -75.0, gy: -818.0 },
];

const seeds = {
  "Paleto PD": [920, 179],
  "Mt Chiliad": [994, 266],
  "Sandy PD": [1420, 679],
  Grapeseed: [1376, 394],
  Harmony: [1110, 734],
  "Fort Zancudo": [350, 816],
  Chumash: [200, 1180],
  "Del Perro": [520, 1372],
  Vespucci: [678, 1508],
  MRPD: [833, 1544],
  "Legion Sq": [830, 1526],
  Pillbox: [922, 1516],
  "Davis PD": [784, 1592],
  "Grove St": [826, 1692],
  LSIA: [560, 1762],
  "Port docks": [1030, 1772],
  Vinewood: [916, 1226],
  Rockford: [564, 1322],
  "Lost MC": [1006, 1388],
  "ONeil farm": [1538, 250],
  "La Mesa PD": [900, 1580],
  "Maze Bank": [800, 1520],
};

function landScore(r, g, b) {
  const ocean = b > r + 20 && b > g + 10;
  const urban = r > 70 && g > 65 && b > 60;
  return (r + g + b) / 3 + Math.max(r, g) * 0.06 + (urban ? 12 : 0) - (ocean ? 55 : 0);
}

function solveLs(rows, target) {
  const m = rows[0].length;
  const ata = Array.from({ length: m }, () => Array(m).fill(0));
  const atb = Array(m).fill(0);
  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
    const y = target[i];
    for (let j = 0; j < m; j++) {
      atb[j] += r[j] * y;
      for (let k = 0; k < m; k++) ata[j][k] += r[j] * r[k];
    }
  }
  const A = ata.map((row, i) => [...row, atb[i]]);
  for (let c = 0; c < m; c++) {
    let p = c;
    for (let r = c + 1; r < m; r++) {
      if (Math.abs(A[r][c]) > Math.abs(A[p][c])) p = r;
    }
    [A[c], A[p]] = [A[p], A[c]];
    const d = A[c][c];
    for (let r = c + 1; r < m; r++) {
      const f = A[r][c] / d;
      for (let j = c; j <= m; j++) A[r][j] -= f * A[c][j];
    }
  }
  const x = Array(m);
  for (let i = m - 1; i >= 0; i--) {
    let s = A[i][m];
    for (let j = i + 1; j < m; j++) s -= A[i][j] * x[j];
    x[i] = s / A[i][i];
  }
  return x;
}

function fitAffine(points, key) {
  const rows = points.map((p) => [p.gx, p.gy, 1]);
  return solveLs(rows, points.map((p) => p[key]));
}

function fitHomography(points) {
  const rows = [];
  const rhs = [];
  for (const p of points) {
    rows.push([p.gx, p.gy, 1, 0, 0, 0, -p.u * p.gx, -p.u * p.gy]);
    rhs.push(p.u);
    rows.push([0, 0, 0, p.gx, p.gy, 1, -p.v * p.gx, -p.v * p.gy]);
    rhs.push(p.v);
  }
  return solveLs(rows, rhs);
}

function applyH(h, gx, gy) {
  const den = h[6] * gx + h[7] * gy + 1;
  return {
    u: (h[0] * gx + h[1] * gy + h[2]) / den,
    v: (h[3] * gx + h[4] * gy + h[5]) / den,
  };
}

function tpsU(r) {
  return r < 1e-10 ? 0 : r * r * Math.log(r);
}

function fitTps(points) {
  const n = points.length;
  const s = n + 3;
  const A = Array.from({ length: s }, () => Array(s).fill(0));
  const bu = Array(s).fill(0);
  const bv = Array(s).fill(0);
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      const dx = points[i].gx - points[j].gx;
      const dy = points[i].gy - points[j].gy;
      A[i][j] = tpsU(Math.hypot(dx, dy));
    }
    A[i][n] = 1;
    A[i][n + 1] = points[i].gx;
    A[i][n + 2] = points[i].gy;
    A[n][i] = 1;
    A[n + 1][i] = points[i].gx;
    A[n + 2][i] = points[i].gy;
    bu[i] = points[i].u;
    bv[i] = points[i].v;
  }
  return { points, wx: solveLs(A, bu), wy: solveLs(A, bv) };
}

function evalTps(gx, gy, m) {
  const n = m.points.length;
  let u = m.wx[n] + m.wx[n + 1] * gx + m.wx[n + 2] * gy;
  let v = m.wy[n] + m.wy[n + 1] * gx + m.wy[n + 2] * gy;
  for (let i = 0; i < n; i++) {
    const k = tpsU(Math.hypot(gx - m.points[i].gx, gy - m.points[i].gy));
    u += m.wx[i] * k;
    v += m.wy[i] * k;
  }
  return { u, v };
}

function idw(gx, gy, points, power = 2) {
  let wSum = 0;
  let uSum = 0;
  let vSum = 0;
  for (const p of points) {
    const d2 = (gx - p.gx) ** 2 + (gy - p.gy) ** 2;
    if (d2 < 0.25) return { u: p.u, v: p.v };
    const w = 1 / d2 ** (power / 2);
    wSum += w;
    uSum += w * p.u;
    vSum += w * p.v;
  }
  return { u: uSum / wSum, v: vSum / wSum };
}

function searchBest(png, w, hPx, sx, sy, radius, step) {
  let best = { score: -1e9, px: sx, py: sy };
  for (let py = sy - radius; py <= sy + radius; py += step) {
    for (let px = sx - radius; px <= sx + radius; px += step) {
      if (px < 1 || py < 1 || px >= w - 1 || py >= hPx - 1) continue;
      const i = (py * w + px) << 2;
      const r = png.data[i];
      const g = png.data[i + 1];
      const b = png.data[i + 2];
      const s = landScore(r, g, b) - Math.hypot(px - sx, py - sy) * 0.02;
      if (s > best.score) best = { score: s, px, py };
    }
  }
  return best;
}

const png = await new Promise((resolve, reject) => {
  fs.createReadStream(IMG)
    .pipe(new PNG())
    .on("parsed", function () {
      resolve(this);
    })
    .on("error", reject);
});

const w = png.width;
const hPx = png.height;
const measured = [];

for (const lm of landmarks) {
  const [sx, sy] = seeds[lm.name] || [w / 2, hPx / 2];
  let best = searchBest(png, w, hPx, sx, sy, 80, 2);
  best = searchBest(png, w, hPx, best.px, best.py, 12, 1);
  measured.push({
    ...lm,
    u: best.px / w,
    v: best.py / hPx,
    px: best.px,
    py: best.py,
  });
}

const au = fitAffine(measured, "u");
const av = fitAffine(measured, "v");
for (const p of measured) {
  const predU = au[0] * p.gx + au[1] * p.gy + au[2];
  const predV = av[0] * p.gx + av[1] * p.gy + av[2];
  const px = Math.round(predU * w);
  const py = Math.round(predV * hPx);
  const refined = searchBest(png, w, hPx, px, py, 36, 1);
  if (refined.score > -1e8) {
    p.px = refined.px;
    p.py = refined.py;
    p.u = refined.px / w;
    p.v = refined.py / hPx;
  }
}

const rangeX = 8500;

function errReport(label, project) {
  let sumSq = 0;
  let maxE = 0;
  console.log(`\n${label}:`);
  for (const p of measured) {
    const uv = project(p.gx, p.gy);
    const errPx = Math.hypot((uv.u - p.u) * w, (uv.v - p.v) * hPx);
    const errM = errPx * (rangeX / w);
    sumSq += errM * errM;
    maxE = Math.max(maxE, errM);
    console.log(`  ${p.name.padEnd(14)} ${errM.toFixed(1)}m`);
  }
  console.log(`  RMS ${Math.sqrt(sumSq / measured.length).toFixed(1)}m  max ${maxE.toFixed(1)}m`);
}

function looReport(label, fitFn, evalFn) {
  let sumSq = 0;
  let maxE = 0;
  console.log(`\n${label} (leave-one-out):`);
  for (let i = 0; i < measured.length; i++) {
    const train = measured.filter((_, j) => j !== i);
    const model = fitFn(train);
    const uv = evalFn(measured[i].gx, measured[i].gy, model);
    const errM =
      Math.hypot((uv.u - measured[i].u) * w, (uv.v - measured[i].v) * hPx) *
      (rangeX / w);
    sumSq += errM * errM;
    maxE = Math.max(maxE, errM);
  }
  console.log(`  RMS ${Math.sqrt(sumSq / measured.length).toFixed(1)}m  max ${maxE.toFixed(1)}m`);
}

const hom = fitHomography(measured);
const tps = fitTps(measured);

errReport("Homography train", (gx, gy) => applyH(hom, gx, gy));
errReport("TPS train", (gx, gy) => evalTps(gx, gy, tps));
errReport("IDW train", (gx, gy) => idw(gx, gy, measured, 2));

looReport("IDW", (pts) => pts, (gx, gy, pts) => idw(gx, gy, pts, 2));
looReport("TPS", (pts) => fitTps(pts), (gx, gy, m) => evalTps(gx, gy, m));

console.log("\n-- Lua Config.MdtMap (TPS + pixel CRS) --");
console.log("Config.MdtMap = {");
console.log("    projection = 'homography',");
console.log("    coordSpace = 'pixel',");
console.log("    gameMin = { x = -4000.0, y = -4000.0 },");
console.log("    gameMax = { x = 4500.0, y = 6625.0 },");
console.log("    imageFile = 'mdt/asset/gtav_satellite_2048.png',");
console.log("    imageWidth = 2048,");
console.log("    imageHeight = 2048,");
console.log("    calibration = {");
for (const p of measured) {
  console.log(
    `        { gx = ${p.gx}, gy = ${p.gy}, u = ${p.u.toFixed(4)}, v = ${p.v.toFixed(4)} }, -- ${p.name}`,
  );
}
console.log("    },");
console.log("}");
