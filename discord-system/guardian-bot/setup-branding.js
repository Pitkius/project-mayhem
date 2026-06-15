import 'dotenv/config';
import { assertEnv } from './src/config.js';
import { applyBotBranding, BOT_BRAND, getAvatarPath } from './src/utils/branding.js';
import fs from 'node:fs';

assertEnv();

if (!fs.existsSync(getAvatarPath())) {
  console.error('Nerastas assets/avatar.png — ikėlk MAYHEM RP logo.');
  process.exit(1);
}

await applyBotBranding(null);
console.log(`[MRP] Bot vardas: ${BOT_BRAND.username}`);
console.log('[MRP] Profiline nuotrauka nustatyta.');
