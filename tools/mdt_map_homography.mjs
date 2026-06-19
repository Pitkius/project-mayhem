/** Fit homography (gx,gy) -> (u,v) for MDT map calibration. */
const measured = [
  { name: "Paleto PD", gx: -448.15, gy: 6012.0, u: 0.418, v: 0.072 },
  { name: "Mt Chiliad", gx: 450.77, gy: 5566.86, u: 0.5, v: 0.125 },
  { name: "Sandy PD", gx: 1853.2, gy: 3686.5, u: 0.708, v: 0.362 },
  { name: "Fort Zancudo", gx: -2360.0, gy: 3249.0, u: 0.138, v: 0.455 },
  { name: "MRPD", gx: 441.84, gy: -982.05, u: 0.404, v: 0.756 },
  { name: "Davis PD", gx: 379.39, gy: -1591.37, u: 0.41, v: 0.788 },
  { name: "LSIA", gx: -1037.0, gy: -2737.0, u: 0.276, v: 0.874 },
  { name: "Port docks", gx: 1206.24, gy: -3157.06, u: 0.513, v: 0.87 },
  { name: "Vespucci", gx: -1098.0, gy: -808.0, u: 0.332, v: 0.738 },
  { name: "Grove St", gx: 85.0, gy: -1958.0, u: 0.4, v: 0.82 },
];

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
    if (Math.abs(d) < 1e-12) return null;
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
    const { gx, gy, u, v } = p;
    rows.push([gx, gy, 1, 0, 0, 0, -u * gx, -u * gy]);
    rhs.push(u);
    rows.push([0, 0, 0, gx, gy, 1, -v * gx, -v * gy]);
    rhs.push(v);
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

const h = fitHomography(measured);
const minX = -4000;
const maxX = 4500;
const minY = -4000;
const maxY = 6625;
const rangeX = maxX - minX;
const rangeY = maxY - minY;
const w = 2048;
const hPx = 2048;

let sumSq = 0;
let maxE = 0;
for (const p of measured) {
  const uv = applyH(h, p.gx, p.gy);
  const errPx = Math.hypot((uv.u - p.u) * w, (uv.v - p.v) * hPx);
  const errM = errPx * (rangeX / w);
  sumSq += errM * errM;
  maxE = Math.max(maxE, errM);
  console.log(p.name.padEnd(12), `${errM.toFixed(2)}m`);
}
console.log(`RMS ${Math.sqrt(sumSq / measured.length).toFixed(2)}m max ${maxE.toFixed(2)}m`);
console.log("H", h);

// Compare identity vs homography for port
for (const p of [
  { name: "Port", gx: 1206.24, gy: -3157.06 },
  { name: "MRPD", gx: 441.84, gy: -982.05 },
]) {
  const id = { u: (p.gx - minX) / rangeX, v: (maxY - p.gy) / rangeY };
  const hv = applyH(h, p.gx, p.gy);
  console.log(
    p.name,
    "identity px",
    Math.round(id.u * w),
    Math.round(id.v * hPx),
    "homography px",
    Math.round(hv.u * w),
    Math.round(hv.v * hPx),
  );
}
