import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { REST, Routes } from 'discord.js';
import { env } from '../config.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const BOT_BRAND = {
  username: process.env.BOT_USERNAME || 'MRP',
  displayName: 'MRP',
  fullName: 'MAYHEM RP',
  footer: 'MRP | MAYHEM RP',
};

export function getAvatarPath() {
  return path.join(__dirname, '..', '..', 'assets', 'avatar.png');
}

export async function applyBotBranding(client) {
  const avatarPath = getAvatarPath();
  const hasAvatar = fs.existsSync(avatarPath);

  try {
    if (client?.user) {
      if (client.user.username !== BOT_BRAND.username) {
        await client.user.setUsername(BOT_BRAND.username);
        console.log(`[MRP] Username -> ${BOT_BRAND.username}`);
      }

      if (hasAvatar && !client.user.avatar) {
        const buffer = fs.readFileSync(avatarPath);
        await client.user.setAvatar(buffer);
        console.log('[MRP] Avatar nustatytas is assets/avatar.png');
      } else if (hasAvatar) {
        // Atnaujink avatar paleidus: npm run branding
        console.log('[MRP] Avatar jau nustatytas (atnaujinimui: npm run branding)');
      }
      return;
    }
  } catch (err) {
    console.warn('[MRP] Client branding:', err.message);
  }

  // Fallback: REST API (naudojama setup-branding.js)
  if (!env.token || !env.clientId) return;

  const body = { username: BOT_BRAND.username };
  if (hasAvatar) {
    const base64 = fs.readFileSync(avatarPath).toString('base64');
    body.avatar = `data:image/png;base64,${base64}`;
  }

  const rest = new REST({ version: '10' }).setToken(env.token);
  await rest.patch(Routes.user(), { body });
  console.log('[MRP] Profiline + vardas atnaujinti per API');
}
