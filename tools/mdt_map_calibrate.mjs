/** Tune MDT map calibration — run: node tools/mdt_map_calibrate.mjs */
function linearFit(xs, ys) {
  const n = xs.length;
  let sumX = 0, sumY = 0, sumXX = 0, sumXY = 0;
  for (let i = 0; i < n; i++) {
    const x = xs[i], y = ys[i];
    sumX += x; sumY += y; sumXX += x * x; sumXY += x * y;
  }
  const denom = n * sumXX - sumX * sumX;
  const slope = (n * sumXY - sumX * sumY) / denom;
  const intercept = (sumY - slope * sumX) / n;
  return { intercept, slope };
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
    for (let r = c + 1; r < m; r++) if (Math.abs(A[r][c]) > Math.abs(A[p][c])) p = r;
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

// u = 0 vakarai (kairė), u = 1 rytai (dešinė); v = 0 šiaurė (viršus), v = 1 pietūs (apačia)
const landmarks = [
  { name: "Paleto PD", gx: -448.15, gy: 6012.0, u: 0.418, v: 0.072 },
  { name: "Mt Chiliad", gx: 450.77, gy: 5566.86, u: 0.500, v: 0.125 },
  { name: "Sandy PD", gx: 1853.2, gy: 3686.5, u: 0.708, v: 0.362 },
  { name: "Fort Zancudo", gx: -2360.0, gy: 3249.0, u: 0.138, v: 0.455 },
  { name: "MRPD", gx: 441.84, gy: -982.05, u: 0.404, v: 0.756 },
  { name: "Davis PD", gx: 379.39, gy: -1591.37, u: 0.410, v: 0.788 },
  { name: "LSIA", gx: -1037.0, gy: -2737.0, u: 0.276, v: 0.874 },
];

const minX = -4000;
const maxX = 4500;
const minY = -4000;
const maxY = 6625;
const rangeX = maxX - minX;
const rangeY = maxY - minY;

const rows = landmarks.map((p) => [p.gx, p.gy, 1]);
const affineLng = solveLs(rows, landmarks.map((p) => minX + p.u * rangeX));
const affineLat = solveLs(rows, landmarks.map((p) => maxY - p.v * rangeY));

function affineLatLng(gx, gy) {
  return {
    lng: affineLng[0] * gx + affineLng[1] * gy + affineLng[2],
    lat: affineLat[0] * gx + affineLat[1] * gy + affineLat[2],
  };
}

console.log("Affine calibration (MDT projection=affine):");
let sumSq = 0;
let maxErr = 0;
for (const p of landmarks) {
  const ll = affineLatLng(p.gx, p.gy);
  const tgtLng = minX + p.u * rangeX;
  const tgtLat = maxY - p.v * rangeY;
  const err = Math.hypot(ll.lng - tgtLng, ll.lat - tgtLat);
  sumSq += err * err;
  if (err > maxErr) maxErr = err;
  console.log(
    p.name,
    `err ${err.toFixed(1)}m`,
    `game ${p.gx},${p.gy}`,
    `target lng/lat ${tgtLng.toFixed(1)}/${tgtLat.toFixed(1)}`,
    `got ${ll.lng.toFixed(1)}/${ll.lat.toFixed(1)}`,
  );
}
console.log("");
console.log("rms", Math.sqrt(sumSq / landmarks.length).toFixed(1), "m");
console.log("max", maxErr.toFixed(1), "m");
console.log("");
console.log("Identity at MRPD for comparison:");
const mrpd = landmarks.find((p) => p.name === "MRPD");
const tgtLng = minX + mrpd.u * rangeX;
const tgtLat = maxY - mrpd.v * rangeY;
const idErr = Math.hypot(mrpd.gx - tgtLng, mrpd.gy - tgtLat);
console.log(`MRPD identity err ${idErr.toFixed(1)}m (lng ${(mrpd.gx - tgtLng).toFixed(1)} / lat ${(mrpd.gy - tgtLat).toFixed(1)})`);
