import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const botRoot = path.join(__dirname, '..');

/**
 * systemd EnvironmentFile + lokalus .env.
 * Trimina tokeną (CR/LF/BOM/"Bot " prefix) — dažna VPS priežastis TokenInvalid.
 */
function loadEnvFiles() {
  const candidates = [
    process.env.MRP_DISCORD_ENV_FILE,
    path.join(os.homedir(), '.config', 'mrp-discord.env'),
    '/home/fivem/.config/mrp-discord.env',
    path.join(botRoot, '.env'),
  ].filter(Boolean);

  // mrp-discord.env visada override — systemd EnvironmentFile kartais perduoda sugadintą tokeną
  for (const file of candidates) {
    if (!fs.existsSync(file)) continue;
    const isPrimary = file.includes('mrp-discord.env');
    dotenv.config({ path: file, override: isPrimary });
    if (isPrimary) break;
  }

  dotenv.config({ path: path.join(process.cwd(), '.env'), override: false });
}

loadEnvFiles();

function cleanToken(raw) {
  if (raw == null) return null;
  let t = String(raw).replace(/^\uFEFF/, '').trim();
  if (/^Bot\s+/i.test(t)) t = t.replace(/^Bot\s+/i, '').trim();
  // Nuimti vienas sluoksnis kabučių jei kas įklijavo su jomis
  if ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'"))) {
    t = t.slice(1, -1).trim();
  }
  return t || null;
}

function loadJson(name) {
  const example = path.join(botRoot, name);
  const local = path.join(botRoot, name.replace('.example', ''));
  const target = fs.existsSync(local) ? local : example;
  if (!fs.existsSync(target)) return {};
  return JSON.parse(fs.readFileSync(target, 'utf8'));
}

export const env = {
  token: cleanToken(process.env.DISCORD_TOKEN),
  clientId: String(process.env.DISCORD_CLIENT_ID || '').trim() || null,
  guildId: String(process.env.DISCORD_GUILD_ID || '').trim() || null,
  databasePath: process.env.DATABASE_PATH || './data/guardian.db',
};

export const appConfig = loadJson('config.example.json');

export const LOG_TYPES = [
  'mod',
  'antinuke',
  'message',
  'member',
  'join',
  'role',
  'channel',
  'voice',
  'webhook',
  'security',
];

export function tokenDiagnostics(token = env.token) {
  if (!token) return { ok: false, reason: 'missing' };
  const parts = token.split('.');
  return {
    ok: parts.length === 3 && parts.every((p) => p.length > 0),
    length: token.length,
    parts: parts.length,
    hasWhitespace: /\s/.test(token),
  };
}

export function assertEnv() {
  if (!env.token || !env.clientId) {
    throw new Error('Missing DISCORD_TOKEN or DISCORD_CLIENT_ID in env (mrp-discord.env / .env)');
  }
  const diag = tokenDiagnostics();
  if (!diag.ok) {
    throw new Error(
      `DISCORD_TOKEN formatas blogas (len=${diag.length}, parts=${diag.parts}). Reikia 3 dalių su taškais.`,
    );
  }
  console.log(`[MRP] Token OK format: len=${diag.length} parts=${diag.parts}`);
}
