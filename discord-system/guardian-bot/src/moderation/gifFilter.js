import { PermissionFlagsBits, StickerFormatType } from 'discord.js';
import { isAdmin, isModerator } from '../utils/permissions.js';
import { isWhitelisted } from '../database/sqlite.js';

const GIF_URL_RE = /(?:tenor\.com|giphy\.com|media\.tenor\.com|gph\.is|\.gif(?:\?|$)|discord(?:app)?\.com\/attachments\/[^\s]+\.gif)/i;
const GIF_NOTIFY = 'Šiame serveryje **GIF siųsti negalima**. Žinutė ištrinta.';
const notifyCooldown = new Map();
const NOTIFY_COOLDOWN_MS = 8000;

function isStaff(member) {
  if (!member) return false;
  if (isAdmin(member) || isModerator(member)) return true;
  return member.permissions.has(PermissionFlagsBits.ManageMessages);
}

export function messageContainsGif(message) {
  for (const att of message.attachments?.values?.() || []) {
    const name = String(att.name || '').toLowerCase();
    const ct = String(att.contentType || '').toLowerCase();
    if (ct.includes('gif') || name.endsWith('.gif')) return true;
  }

  for (const sticker of message.stickers?.values?.() || []) {
    // 2 = GIF format in discord.js enum
    if (sticker.format === StickerFormatType.GIF || sticker.format === 2) return true;
  }

  const content = message.content || '';
  if (GIF_URL_RE.test(content)) return true;

  for (const embed of message.embeds || []) {
    const provider = String(embed.provider?.name || '');
    if (/^tenor$/i.test(provider) || /^giphy$/i.test(provider)) return true;

    const blob = [
      embed.url,
      embed.title,
      embed.description,
      embed.thumbnail?.url,
      embed.image?.url,
      embed.video?.url,
      embed.provider?.url,
    ].filter(Boolean).join(' ');

    if (GIF_URL_RE.test(blob) || /\.gif(?:\?|$)/i.test(blob)) return true;
    if (embed.video && /tenor|giphy|gif/i.test(String(embed.video.url || ''))) return true;
  }

  return false;
}

async function notifySenderOnly(message) {
  const key = `${message.guildId}:${message.author.id}`;
  const now = Date.now();
  if (notifyCooldown.has(key) && now - notifyCooldown.get(key) < NOTIFY_COOLDOWN_MS) return;
  notifyCooldown.set(key, now);

  try {
    const dm = await message.author.createDM();
    await dm.send({ content: GIF_NOTIFY });
  } catch {
    // Jei DM uždaryti — Discord neleidžia ephemeral ant paprastų žinučių.
    // Nieko viešai nerašom, kad kiti nematytų.
  }
}

/**
 * Ištrina GIF žinutes. Grąžina true jei apdorota.
 */
export async function handleGifMessage(message) {
  if (!message?.guild || message.author?.bot) return false;
  if (!messageContainsGif(message)) return false;

  const member = message.member
    || await message.guild.members.fetch(message.author.id).catch(() => null);

  if (isStaff(member)) return false;
  if (isWhitelisted(message.guild.id, message.author.id, message.guild)) return false;

  const deleted = await message.delete().catch(() => null);
  if (!deleted) return false;

  await notifySenderOnly(message);
  return true;
}
