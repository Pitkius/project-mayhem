import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const carsDir = path.join(root, 'resources', '[cars]');

function walk(dir, out = []) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) walk(p, out);
    else if (ent.name === 'handling.meta') out.push(p);
  }
  return out;
}

function readVal(text, key) {
  const m = text.match(new RegExp(`<${key}[^>]*value="([^"]+)"`, 'i'));
  return m ? parseFloat(m[1]) : null;
}

const rows = [];
for (const f of walk(carsDir)) {
  const text = fs.readFileSync(f, 'utf8');
  const name = path.basename(path.dirname(f));
  rows.push({
    name,
    file: f,
    df: readVal(text, 'fDownforceModifier') ?? 0,
    tmax: readVal(text, 'fTractionCurveMax'),
    tmin: readVal(text, 'fTractionCurveMin'),
    susp: readVal(text, 'fSuspensionForce'),
    mass: readVal(text, 'fMass'),
  });
}

rows.sort((a, b) => (b.df - a.df) || ((b.tmax || 0) - (a.tmax || 0)));

console.log('=== Explicit downforce > 0 ===');
rows.filter((r) => r.df > 0 || (r.tmax || 0) > 2.85).forEach((r) => {
  console.log(`${r.name.padEnd(22)} df=${r.df} tmax=${r.tmax} tmin=${r.tmin}`);
});
