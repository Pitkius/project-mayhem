import { readdir, unlink } from 'fs/promises';
import { join } from 'path';
import sharp from 'sharp';

const dir = join('..', 'resources', '[local]', 'fivempro_loadscreen', 'html', 'assets');
const files = (await readdir(dir)).filter((f) => f.endsWith('.png'));

for (const file of files) {
  const src = join(dir, file);
  const out = join(dir, file.replace(/\.png$/i, '.jpg'));
  await sharp(src)
    .resize(1920, 1080, { fit: 'cover', position: 'centre' })
    .jpeg({ quality: 82, mozjpeg: true })
    .toFile(out);
  await unlink(src);
  console.log('compressed', file, '->', out.split(/[/\\]/).pop());
}
