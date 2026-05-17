import fs from 'fs';
import path from 'path';
import { PNG } from 'pngjs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const imagesDir = path.join(__dirname, '..', 'resources', '[qb]', 'qb-inventory', 'html', 'images');
const prefixes = [
  'mining_pickaxe', 'stone', 'coal', 'gravel', 'ironore', 'copperore', 'aluminumore',
  'silverore', 'goldore', 'diamond', 'emerald', 'ruby', 'sapphire', 'mystery_ore', 'artifact',
];

function cornerBg(data, width, height) {
  const pts = [
    [1, 1], [width - 2, 1], [1, height - 2], [width - 2, height - 2],
  ];
  let r = 0, g = 0, b = 0;
  for (const [x, y] of pts) {
    const i = (width * y + x) << 2;
    r += data[i]; g += data[i + 1]; b += data[i + 2];
  }
  return [r / 4, g / 4, b / 4];
}

function dist(a, b) {
  return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
}

function processFile(filePath) {
  const buf = fs.readFileSync(filePath);
  const png = PNG.sync.read(buf);
  const { width, height, data } = png;
  const bg = cornerBg(data, width, height);
  let changed = false;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (width * y + x) << 2;
      const a = data[i + 3];
      if (a === 0) continue;
      const rgb = [data[i], data[i + 1], data[i + 2]];
      const maxC = Math.max(rgb[0], rgb[1], rgb[2]);
      const minC = Math.min(rgb[0], rgb[1], rgb[2]);
      const neutral = rgb[0] > 165 && rgb[1] > 165 && rgb[2] > 165 && maxC - minC < 28;
      if (dist(rgb, bg) <= 52 || neutral) {
        data[i + 3] = 0;
        changed = true;
      }
    }
  }
  if (changed) {
    try {
      fs.writeFileSync(filePath, PNG.sync.write(png));
    } catch (e) {
      if (e.code === 'EBUSY' || e.code === 'EPERM') {
        const alt = `${filePath}.fixed.png`;
        fs.writeFileSync(alt, PNG.sync.write(png));
        console.log('locked -> wrote', path.basename(alt));
        return 'locked';
      }
      throw e;
    }
  }
  return changed;
}

const files = fs.readdirSync(imagesDir).filter((n) => prefixes.some((p) => n.startsWith(p)) && n.endsWith('.png'));
let touched = 0;
let locked = 0;
for (const name of files) {
  const fp = path.join(imagesDir, name);
  const r = processFile(fp);
  if (r === true) {
    console.log('fixed', name);
    touched++;
  } else if (r === 'locked') {
    locked++;
  } else {
    console.log('skip ', name);
  }
}
console.log(`Done. Updated ${touched} file(s).${locked ? ` ${locked} locked (see *.fixed.png).` : ''}`);
