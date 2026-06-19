import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const out = path.join(__dirname, '_ref');
const commits = ['2d937c37', '3e7c9907', 'd8e61edd', '6711cbd8', 'c97e6e86'];
const names = ['weed_buds', 'pistol_ammo', 'joint', 'cocaine_baggy', 'meth_crystal'];

for (const c of commits) {
  const dir = path.join(out, c);
  fs.mkdirSync(dir, { recursive: true });
  for (const name of names) {
    const gitPath = `resources/[qb]/qb-inventory/html/images/${name}.png`;
    try {
      const buf = execSync(`git show ${c}:"${gitPath}"`, { stdio: ['pipe', 'pipe', 'ignore'] });
      fs.writeFileSync(path.join(dir, `${name}.png`), buf);
      console.log(c, name, buf.length);
    } catch {
      console.log(c, name, 'missing');
    }
  }
}
