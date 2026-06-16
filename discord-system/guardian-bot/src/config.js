import 'dotenv/config';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function loadJson(name) {
  const example = path.join(__dirname, '..', name);
  const local = path.join(__dirname, '..', name.replace('.example', ''));
  const target = fs.existsSync(local) ? local : example;
  if (!fs.existsSync(target)) return {};
  return JSON.parse(fs.readFileSync(target, 'utf8'));
}

export const env = {
  token: process.env.DISCORD_TOKEN,
  clientId: process.env.DISCORD_CLIENT_ID,
  guildId: process.env.DISCORD_GUILD_ID || null,
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

export function assertEnv() {
  if (!env.token || !env.clientId) {
    throw new Error('Missing DISCORD_TOKEN or DISCORD_CLIENT_ID in .env');
  }
}
