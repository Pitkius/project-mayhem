#!/usr/bin/env node
/**
 * Patikrina ar Discord API priima tokeną (be discord.js).
 * Naudojimas VPS:
 *   cd /home/fivem/FIVEMPROJEKTAS/discord-system/guardian-bot
 *   node scripts/verify-discord-token.js
 * arba:
 *   MRP_DISCORD_ENV_FILE=/home/fivem/.config/mrp-discord.env node scripts/verify-discord-token.js
 */
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const botRoot = path.join(__dirname, '..');

const candidates = [
  process.env.MRP_DISCORD_ENV_FILE,
  path.join(os.homedir(), '.config', 'mrp-discord.env'),
  '/home/fivem/.config/mrp-discord.env',
  path.join(botRoot, '.env'),
].filter(Boolean);

for (const file of candidates) {
  if (fs.existsSync(file)) {
    dotenv.config({ path: file, override: true });
    console.log(`[verify] loaded ${file}`);
    break;
  }
}

let token = String(process.env.DISCORD_TOKEN || '')
  .replace(/^\uFEFF/, '')
  .trim()
  .replace(/^Bot\s+/i, '');
if ((token.startsWith('"') && token.endsWith('"')) || (token.startsWith("'") && token.endsWith("'"))) {
  token = token.slice(1, -1).trim();
}

if (!token) {
  console.error('[verify] FAIL: DISCORD_TOKEN tuščias');
  process.exit(1);
}

const parts = token.split('.');
console.log(`[verify] len=${token.length} parts=${parts.length}`);

const res = await fetch('https://discord.com/api/v10/users/@me', {
  headers: { Authorization: `Bot ${token}` },
});

const body = await res.text();
console.log(`[verify] HTTP ${res.status}`);

if (res.status === 200) {
  try {
    const json = JSON.parse(body);
    console.log(`[verify] OK — bot user: ${json.username}#${json.discriminator || '0'} id=${json.id}`);
  } catch {
    console.log('[verify] OK — token priimtas');
  }
  process.exit(0);
}

if (res.status === 401) {
  console.error('[verify] FAIL 401 — Discord atmeta šį tokeną (neteisingas arba reset’intas portale).');
  console.error('[verify] Portal → Bot → Reset Token → įklijuok NAUJĄ į mrp-discord.env → paleisk šį scriptą vėl.');
  process.exit(2);
}

console.error(`[verify] FAIL — netikėtas atsakymas: ${body.slice(0, 200)}`);
process.exit(3);
