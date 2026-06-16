const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const imagesDir = path.join(__dirname, '../../resources/[qb]/qb-inventory/html/images');
const files = process.argv.slice(2);
if (!files.length) {
  console.error('Usage: node remove-black-bg.js file1.png ...');
  process.exit(1);
}

for (const name of files) {
  const filePath = path.join(imagesDir, name);
  const buffer = fs.readFileSync(filePath);
  const png = PNG.sync.read(buffer);

  for (let y = 0; y < png.height; y++) {
    for (let x = 0; x < png.width; x++) {
      const idx = (png.width * y + x) << 2;
      const r = png.data[idx];
      const g = png.data[idx + 1];
      const b = png.data[idx + 2];
      const m = Math.max(r, g, b);

      if (m < 18) {
        png.data[idx + 3] = 0;
      } else if (m < 42) {
        const fade = Math.round(((m - 18) / 24) * 255);
        png.data[idx + 3] = Math.min(png.data[idx + 3], fade);
      }
    }
  }

  fs.writeFileSync(filePath, PNG.sync.write(png));
  console.log('OK', name, `${png.width}x${png.height}`);
}
