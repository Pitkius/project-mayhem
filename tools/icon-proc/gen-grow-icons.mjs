/**
 * Generuoja grow_pot, watering_can, drug_scale PNG ir kopijuoja į mrp_drugs NUI.
 * Naudojimas: node gen-grow-icons.mjs
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const names = ['grow_pot', 'watering_can', 'drug_scale'];
const invDir = path.join(__dirname, '..', '..', 'resources', '[qb]', 'qb-inventory', 'html', 'images');
const drugsDir = path.join(__dirname, '..', '..', 'resources', '[local]', 'mrp_drugs', 'html', 'icons');

fs.mkdirSync(drugsDir, { recursive: true });

execSync(`node unify-all-icons.mjs --only=${names.join(',')}`, {
  cwd: __dirname,
  stdio: 'inherit',
});

for (const name of names) {
  const src = path.join(invDir, `${name}.png`);
  const dest = path.join(drugsDir, `${name}.png`);
  if (!fs.existsSync(src)) {
    console.error('missing', src);
    process.exit(1);
  }
  fs.copyFileSync(src, dest);
  console.log('copied ->', dest);
}

console.log('Done. Inventory + mrp_drugs icons updated.');
