import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const rehLua = fs.readFileSync(
  path.join(root, 'resources/[qb]/qb-core/shared/vehicles_reh.lua'),
  'utf8'
);
const imgDir = path.join(
  root,
  'resources/[local]/fivempro_dealership/html/images/vehicles'
);

const models = [...rehLua.matchAll(/model = '([^']+)'/g)].map((m) => m[1]);
const existing = new Set(
  fs.existsSync(imgDir)
    ? fs.readdirSync(imgDir).map((f) => path.parse(f).name)
    : []
);

console.log(`REH models in dealership: ${models.length}`);
console.log(`Images in folder: ${existing.size - (existing.has('.gitkeep') ? 1 : 0)}`);
console.log('');

const missing = models.filter((m) => !existing.has(m));
if (missing.length === 0) {
  console.log('All REH vehicle images present.');
} else {
  console.log(`Missing images (${missing.length}):`);
  for (const m of missing) console.log(`  ${m}.webp`);
}
