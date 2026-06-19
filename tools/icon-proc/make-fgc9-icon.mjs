/**
 * FGC-9 inventoriaus ikona iš in-game screenshot.
 * Usage: npm run fgc9-icon
 */
import { spawnSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const script = path.join(__dirname, 'make-weapon-photo-icon.mjs');
const src = 'weapon_fgc9_ingame.png';
const out = 'weapon_fgc9.png';
const rotate = '-28';

const result = spawnSync(process.execPath, [script, src, out, rotate], {
  stdio: 'inherit',
  cwd: __dirname,
});

process.exit(result.status ?? 1);
