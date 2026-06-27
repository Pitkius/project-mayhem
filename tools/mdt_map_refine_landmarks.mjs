import fs from "fs";
import { PNG } from "pngjs";

const IMG =
  "resources/[local]/mrp_ltpd/html/mdt/asset/gtav_satellite_2048.png";

const landmarks = [
  { name: "Paleto PD", gx: -448.15, gy: 6012.0 },
  { name: "Mt Chiliad", gx: 450.77, gy: 5566.86 },
  { name: "Sandy PD", gx: 1853.2, gy: 3686.5 },
  { name: "Fort Zancudo", gx: -2360.0, gy: 3249.0 },
  { name: "MRPD", gx: 441.84, gy: -982.05 },
  { name: "Davis PD", gx: 379.39, gy: -1591.37 },
  { name: "LSIA", gx: -1037.0, gy: -2737.0 },
  { name: "Port docks", gx: 1206.24, gy: -3157.06 },
  { name: "Vespucci", gx: -1098.0, gy: -808.0 },
  { name: "Grove St", gx: 85.0, gy: -1958.0 },
];

const seeds = {
  "Paleto PD": [856, 147],
  "Mt Chiliad": [1024, 256],
  "Sandy PD": [1480, 741],
  "Fort Zancudo": [280, 800],
  MRPD: [827, 1548],
  "Davis PD": [838, 1610],
  LSIA: [500, 1820],
  "Port docks": [1050, 1780],
  Vespucci: [680, 1510],
  "Grove St": [820, 1680],
};

function landScore(r, g, b) {
  const ocean = b > r + 20 && b > g + 10;
  return (r + g + b) / 3 + Math.max(r, g) * 0.05 - (ocean ? 50 : 0);
}

function solveLs(rows, target) {
  const m = 3;
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

const png = await new Promise((resolve, reject) => {
  fs.createReadStream(IMG)
    .pipe(new PNG())
    .on("parsed", function () {
      resolve(this);
    })
    .on("error", reject);
});

const w = png.width;
const h = png.height;
const measured = [];

for (const lm of landmarks) {
  const [sx, sy] = seeds[lm.name];
  let best = { score: -1, px: sx, py: sy };
  for (let py = sy - 50; py <= sy + 50; py += 2) {
    for (let px = sx - 50; px <= sx + 50; px += 2) {
      if (px < 0 || py < 0 || px >= w || py >= h) continue;
      const i = (py * w + px) << 2;
      const r = png.data[i];
      const g = png.data[i + 1];
      const b = png.data[i + 2];
      const s = landScore(r, g, b) - Math.hypot(px - sx, py - sy) * 0.04;
      if (s > best.score) best = { score: s, px, py };
    }
  }
  const u = best.px / w;
  const v = best.py / h;
  measured.push({ ...lm, u, v, px: best.px, py: best.py });
}

console.log("calibration = {");
for (const p of measured) {
  console.log(
    `  { name = '${p.name}', gx = ${p.gx}, gy = ${p.gy}, u = ${p.u.toFixed(4)}, v = ${p.v.toFixed(4)} },`,
  );
}
console.log("}");

const minX = -4000;
const maxX = 4500;
const minY = -4000;
const maxY = 6625;
const rangeX = maxX - minX;
const rangeY = maxY - minY;
const rows = measured.map((p) => [p.gx, p.gy, 1]);
const aU = solveLs(rows, measured.map((p) => p.u));
const aV = solveLs(rows, measured.map((p) => p.v));

function project(gx, gy) {
  const u = aU[0] * gx + aU[1] * gy + aU[2];
  const v = aV[0] * gx + aV[1] * gy + aV[2];
  return { u, v, lng: minX + u * rangeX, lat: maxY - v * rangeY };
}

let sumSq = 0;
let maxE = 0;
console.log("\nFit errors:");
for (const p of measured) {
  const pr = project(p.gx, p.gy);
  const errPx = Math.hypot((pr.u - p.u) * w, (pr.v - p.v) * h);
  const errM = errPx * (rangeX / w);
  sumSq += errM * errM;
  maxE = Math.max(maxE, errM);
  console.log(p.name.padEnd(12), `${errM.toFixed(1)}m`, `px ${p.px},${p.py} -> ${(pr.u * w).toFixed(0)},${(pr.v * h).toFixed(0)}`);
}
console.log(`RMS ${Math.sqrt(sumSq / measured.length).toFixed(1)}m max ${maxE.toFixed(1)}m`);

console.log("\naffineU =", JSON.stringify(aU));
console.log("affineV =", JSON.stringify(aV));
