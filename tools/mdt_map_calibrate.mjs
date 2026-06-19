/** Tune MDT map calibration — run: node tools/mdt_map_calibrate.mjs */
function solveLinear(A, b) {
  const M = A.map((row) => row.slice());
  const x = b.slice();
  const n = M.length;
  for (let i = 0; i < n; i += 1) {
    let piv = i;
    for (let r = i + 1; r < n; r += 1) {
      if (Math.abs(M[r][i]) > Math.abs(M[piv][i])) piv = r;
    }
    [M[i], M[piv]] = [M[piv], M[i]];
    [x[i], x[piv]] = [x[piv], x[i]];
    const d = M[i][i];
    if (Math.abs(d) < 1e-12) return null;
    for (let j = i; j < n; j += 1) M[i][j] /= d;
    x[i] /= d;
    for (let r = 0; r < n; r += 1) {
      if (r === i) continue;
      const f = M[r][i];
      for (let j = i; j < n; j += 1) M[r][j] -= f * M[i][j];
      x[r] -= f * x[i];
    }
  }
  return x;
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
  return solveLinear(ata, atb);
}

function fitAffine(points) {
  const rows = points.map((p) => [p.gx, p.gy, 1]);
  const aU = solveLs(rows, points.map((p) => p.u));
  const aV = solveLs(rows, points.map((p) => p.v));
  return { aU, aV };
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

// u = 0 vakarai, u = 1 rytai; v = 0 šiaurė, v = 1 pietūs
const landmarks = [
  { name: "Paleto PD", gx: -448.15, gy: 6012.0, u: 0.418, v: 0.072 },
  { name: "Mt Chiliad", gx: 450.77, gy: 5566.86, u: 0.5, v: 0.125 },
  { name: "Sandy PD", gx: 1853.2, gy: 3686.5, u: 0.708, v: 0.362 },
  { name: "Fort Zancudo", gx: -2360.0, gy: 3249.0, u: 0.138, v: 0.455 },
  { name: "MRPD", gx: 441.84, gy: -982.05, u: 0.404, v: 0.756 },
  { name: "Davis PD", gx: 379.39, gy: -1591.37, u: 0.41, v: 0.788 },
  { name: "LSIA", gx: -1037.0, gy: -2737.0, u: 0.276, v: 0.874 },
  { name: "Port docks", gx: 1206.24, gy: -3157.06, u: 0.503, v: 0.87 },
  { name: "Vespucci", gx: -1098.0, gy: -808.0, u: 0.332, v: 0.738 },
  { name: "Grove St", gx: 85.0, gy: -1958.0, u: 0.4, v: 0.82 },
];

const minX = -4000;
const maxX = 4500;
const minY = -4000;
const maxY = 6625;
const rangeX = maxX - minX;
const rangeY = maxY - minY;
const w = 2048;

function tgt(p) {
  return { lng: minX + p.u * rangeX, lat: maxY - p.v * rangeY };
}

function errReport(label, project) {
  console.log(`\n${label}:`);
  let sumSq = 0;
  let maxErr = 0;
  for (const p of landmarks) {
    const got = project(p.gx, p.gy);
    const want = tgt(p);
    const err = Math.hypot(got.lng - want.lng, got.lat - want.lat);
    sumSq += err * err;
    maxErr = Math.max(maxErr, err);
    console.log(
      p.name,
      `err ${err.toFixed(1)}m`,
      `px ${(got.u * w).toFixed(0)},${(got.v * w).toFixed(0)}`,
    );
  }
  console.log("rms", Math.sqrt(sumSq / landmarks.length).toFixed(1), "m");
  console.log("max", maxErr.toFixed(1), "m");
}

errReport("Identity", (gx, gy) => ({ lng: gx, lat: gy, u: (gx - minX) / rangeX, v: (maxY - gy) / rangeY }));

const { aU, aV } = fitAffine(landmarks);
errReport("Affine", (gx, gy) => {
  const u = aU[0] * gx + aU[1] * gy + aU[2];
  const v = aV[0] * gx + aV[1] * gy + aV[2];
  return { lng: minX + u * rangeX, lat: maxY - v * rangeY, u, v };
});

const h = fitHomography(landmarks);
errReport("Homography", (gx, gy) => {
  const den = h[6] * gx + h[7] * gy + 1;
  const u = (h[0] * gx + h[1] * gy + h[2]) / den;
  const v = (h[3] * gx + h[4] * gy + h[5]) / den;
  return { lng: minX + u * rangeX, lat: maxY - v * rangeY, u, v };
});

console.log("\nConfig: projection = 'homography'");
