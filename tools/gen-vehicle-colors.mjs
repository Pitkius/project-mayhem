import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const jsonPath = process.argv[2];
const outPath = process.argv[3];
const j = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
const colors = j.PrimarySecondaryColors.slice(0, 160).map((c) => ({
  hex: '#' + c.ColorHex.slice(2),
  name: c.ColorName,
}));

const content = `// GTA V PrimarySecondaryColors (0-159) — DurtyFree vehicleColors.json
export type VehicleColorSwatch = { hex: string; name: string };

export const VEHICLE_COLORS: VehicleColorSwatch[] = ${JSON.stringify(colors, null, 2)};

export function colorForIndex(index: number): string {
  return VEHICLE_COLORS[index]?.hex ?? '#888888';
}

export function colorNameForIndex(index: number): string {
  return VEHICLE_COLORS[index]?.name ?? \`Indeksas \${index}\`;
}
`;

fs.writeFileSync(outPath, content);
console.log('Wrote', colors.length, 'colors to', outPath);
