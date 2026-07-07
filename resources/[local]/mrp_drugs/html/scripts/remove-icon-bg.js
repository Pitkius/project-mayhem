/* Pašalina vientisą PNG foną (kampų spalva) — įrankių ikonoms */
const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const ICONS = [
  'grow_pot',
  'watering_can',
  'drug_scale',
  'trimming_scissors',
  'gloves_item',
  'weed_leaf',
];

const iconsDir = path.join(__dirname, '..', 'icons');
const TOLERANCE = 42;

function dist(a, b) {
  return Math.sqrt(
    (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2
  );
}

function sampleCorners(data, width, height) {
  const pts = [
    [0, 0],
    [width - 1, 0],
    [0, height - 1],
    [width - 1, height - 1],
    [Math.floor(width / 2), 0],
    [0, Math.floor(height / 2)],
  ];
  return pts.map(([x, y]) => {
    const i = (width * y + x) << 2;
    return [data[i], data[i + 1], data[i + 2]];
  });
}

function dominantBg(samples) {
  const buckets = new Map();
  samples.forEach((c) => {
    const key = c.map((v) => Math.round(v / 8) * 8).join(',');
    buckets.set(key, (buckets.get(key) || 0) + 1);
  });
  let best = samples[0];
  let max = 0;
  buckets.forEach((count, key) => {
    if (count > max) {
      max = count;
      best = key.split(',').map(Number);
    }
  });
  return best;
}

function processFile(name) {
  const file = path.join(iconsDir, `${name}.png`);
  const buf = fs.readFileSync(file);
  const png = PNG.sync.read(buf);
  const { width, height, data } = png;
  const bg = dominantBg(sampleCorners(data, width, height));

  let removed = 0;
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const i = (width * y + x) << 2;
      const px = [data[i], data[i + 1], data[i + 2]];
      if (dist(px, bg) <= TOLERANCE) {
        data[i + 3] = 0;
        removed += 1;
      }
    }
  }

  fs.writeFileSync(file, PNG.sync.write(png));
  console.log(`${name}.png — bg rgb(${bg.join(',')}) removed ${removed} px`);
}

ICONS.forEach(processFile);
