/**
 * FGC-9 inventoriaus ikona — tik ginklas, permatomas fonas (švarus profilis).
 * Usage: npm run fgc9-icon
 */
import fs from 'fs';
import { spawnSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const script = path.join(__dirname, 'make-weapon-photo-icon.mjs');
const outIcon = path.join(
  __dirname,
  '..',
  '..',
  'resources',
  '[qb]',
  'qb-inventory',
  'html',
  'images',
  'weapon_fgc9.png',
);
const classicCopy = path.join(__dirname, 'sources', 'weapon_fgc9_classic.png');

const result = spawnSync(
  process.execPath,
  [script, 'weapon_fgc9_clean.jpg', 'weapon_fgc9.png', '-38', 'clean'],
  { stdio: 'inherit', cwd: __dirname },
);

if (result.status === 0 && fs.existsSync(outIcon)) {
  fs.copyFileSync(outIcon, classicCopy);
  console.log('Saved backup:', classicCopy);
}

process.exit(result.status ?? 1);
