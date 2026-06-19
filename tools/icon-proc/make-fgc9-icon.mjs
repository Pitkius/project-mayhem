/**
 * FGC-9 inventoriaus ikona — tik ginklas, be taikiklio, permatomas fonas.
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
const jpgSrc = path.join(__dirname, 'sources', 'weapon_fgc9_clean.jpg');
const pngSrc = path.join(__dirname, 'sources', 'weapon_fgc9_base.png');

const sourceName = fs.existsSync(jpgSrc)
  ? 'weapon_fgc9_clean.jpg'
  : fs.existsSync(pngSrc)
    ? 'weapon_fgc9_base.png'
    : outIcon;

const useClean = /\.jpe?g$/i.test(sourceName);
const sourceArgs = [
  script,
  sourceName,
  'weapon_fgc9.png',
  '-38',
  useClean ? 'clean' : 'raw',
  '0.22',
];

const result = spawnSync(process.execPath, sourceArgs, {
  stdio: 'inherit',
  cwd: __dirname,
});

if (result.status === 0 && fs.existsSync(outIcon)) {
  fs.mkdirSync(path.dirname(classicCopy), { recursive: true });
  fs.copyFileSync(outIcon, classicCopy);
  console.log('Saved backup:', classicCopy);
}

process.exit(result.status ?? 1);
