/** Fit & validate MDT map projections. Run: node tools/mdt_map_fit.mjs */
import fs from "fs";
import { PNG } from "pngjs";

const IMG =
  "resources/[local]/fivempro_ltpd/html/mdt/asset/gtav_satellite_2048.png";

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
];

const seeds = {
  "Paleto PD": [856, 147],
  "Mt Chiliad": [1024, 256],
  "Sandy PD": [1480, 741],
  Grapeseed: [1380, 420],
  Harmony: [1180, 680],
  "Fort Zancudo": [280, 800],
  Chumash: [200, 1180],
  "Del Perro": [520, 1380],
  Vespucci: [680, 1510],
  MRPD: [827, 1548],
  "Legion Sq": [850, 1520],
  Pillbox: [880, 1480],
  "Davis PD": [838, 1610],
  "Grove St": [820, 1680],
  LSIA: [500, 1820],
  "Port docks": [1050, 1780],
  Vinewood: [900, 1280],
  Rockford: [620, 1280],
  "Lost MC": [960, 1320],
  "ONeil farm": [1580, 320],
};

function landScore(r, g, b) {
  const ocean = b > r + 20 && b > g + 10;
  return (r + g + b) / 3 + Math.max(r, g) * 0.05 - (ocean ? 50 : 0);
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

function idw(gx, gy, points, power = 2) {
  let wSum = 0;
  let uSum = 0;
  let vSum = 0;
  for (const p of points) {
    const d2 = (gx - p.gx) ** 2 + (gy - p.gy) ** 2;
    if (d2 < 1e-6) return { u: p.u, v: p.v };
    const w = 1 / d2 ** (power / 2);
    wSum += w;
    uSum += w * p.u;
    vSum += w * p.v;
  }
  return { u: uSum / wSum, v: vSum / wSum };
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
  const [sx, sy] = seeds[lm.name];
  let best = { score: -1, px: sx, py: sy };
  for (let py = sy - 70; py <= sy + 70; py += 2) {
    for (let px = sx - 70; px <= sx + 70; px += 2) {
      if (px < 0 || py < 0 || px >= w || py >= hPx) continue;
      const i = (py * w + px) << 2;
      const r = png.data[i];
      const g = png.data[i + 1];
      const b = png.data[i + 2];
      const s = landScore(r, g, b) - Math.hypot(px - sx, py - sy) * 0.03;
      if (s > best.score) best = { score: s, px, py };
    }
  }
  measured.push({
    ...lm,
    u: best.px / w,
    v: best.py / hPx,
    px: best.px,
    py: best.py,
  });
}

const minX = -4000;
const maxX = 4500;
const minY = -4000;
const maxY = 6625;
const rangeX = maxX - minX;
const rangeY = maxY - minY;

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
    console.log(`  ${p.name.padEnd(12)} ${errM.toFixed(1)}m  px ${p.px},${p.py}`);
  }
  console.log(`  RMS ${Math.sqrt(sumSq / measured.length).toFixed(1)}m  max ${maxE.toFixed(1)}m`);
}

const hom = fitHomography(measured);
errReport("Homography", (gx, gy) => applyH(hom, gx, gy));
errReport("IDW p=2", (gx, gy) => idw(gx, gy, measured, 2));
errReport("IDW p=3", (gx, gy) => idw(gx, gy, measured, 3));

console.log("\n-- Lua calibration (copy to Config.MdtMap) --");
console.log("calibration = {");
for (const p of measured) {
  console.log(
    `    { gx = ${p.gx}, gy = ${p.gy}, u = ${p.u.toFixed(4)}, v = ${p.v.toFixed(4)} },`,
  );
}
console.log("}");

console.log("\nhomographyH = {");
console.log(hom.map((v) => `    ${v},`).join("\n"));
console.log("}");
