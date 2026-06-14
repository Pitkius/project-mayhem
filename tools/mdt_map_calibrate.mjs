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

const u = [], v = [], gx = [], gy = [];
landmarks.forEach((p) => { u.push(p.u); v.push(p.v); gx.push(p.gx); gy.push(p.gy); });
const fitX = linearFit(u, gx);
const fitY = linearFit(v, gy);

const coordMinX = fitX.intercept;
const coordMaxX = fitX.intercept + fitX.slope;
const coordMaxY = fitY.intercept;
const coordMinY = fitY.intercept + fitY.slope;

function toLatLng(x, y) {
  const tX = (x - coordMinX) / (coordMaxX - coordMinX);
  const tY = (y - coordMinY) / (coordMaxY - coordMinY);
  const lat = coordMinY + tY * (coordMaxY - coordMinY);
  const lng = coordMinX + tX * (coordMaxX - coordMinX);
  return { lat, lng, tX, tY };
}

console.log("coordMinX", coordMinX.toFixed(2), "coordMaxX", coordMaxX.toFixed(2));
console.log("coordMinY", coordMinY.toFixed(2), "coordMaxY", coordMaxY.toFixed(2));
console.log("");
const offsetX = -32.0;
const offsetY = -38.0;
const rangeX = coordMaxX - coordMinX;
const rangeY = coordMaxY - coordMinY;

for (const p of landmarks) {
  const r = toLatLng(p.gx, p.gy);
  const vImg = 1 - r.tY;
  const errXm = (r.tX - p.u) * rangeX - offsetX;
  const errYm = (vImg - p.v) * rangeY - offsetY;
  console.log(
    p.name,
    `target u/v ${p.u}/${p.v}`,
    `got ${r.tX.toFixed(3)}/${vImg.toFixed(3)}`,
    `err ${errXm.toFixed(1)}m / ${errYm.toFixed(1)}m`,
    `game ${p.gx},${p.gy}`,
  );
}
