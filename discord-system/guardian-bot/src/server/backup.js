import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ChannelType } from 'discord.js';
import { getAllLogChannels } from '../database/sqlite.js';
import { serverConfig } from './config.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backupsDir = path.join(__dirname, '..', '..', 'data', 'backups');

function serializeOverwrite(ow) {
  return {
    id: ow.id,
    type: ow.type,
    allow: ow.allow?.bitfield?.toString?.() || String(ow.allow || '0'),
    deny: ow.deny?.bitfield?.toString?.() || String(ow.deny || '0'),
  };
}

export async function createGuildBackup(guild, extras = {}) {
  await guild.channels.fetch().catch(() => null);
  await guild.roles.fetch().catch(() => null);

  const channels = [...guild.channels.cache.values()].map((ch) => ({
    id: ch.id,
    name: ch.name,
    type: ch.type,
    parentId: ch.parentId || null,
    position: ch.rawPosition ?? ch.position ?? 0,
    topic: ch.topic || null,
    nsfw: !!ch.nsfw,
    permissionOverwrites: ch.permissionOverwrites?.cache
      ? [...ch.permissionOverwrites.cache.values()].map(serializeOverwrite)
      : [],
  }));

  const roles = [...guild.roles.cache.values()]
    .filter((r) => r.id !== guild.id)
    .map((r) => ({
      id: r.id,
      name: r.name,
      color: r.color,
      position: r.position,
      permissions: r.permissions.bitfield.toString(),
      hoist: r.hoist,
      mentionable: r.mentionable,
      managed: r.managed,
    }));

  const categories = channels
    .filter((c) => c.type === ChannelType.GuildCategory)
    .sort((a, b) => a.position - b.position);

  const logChannelIds = getAllLogChannels(guild.id).map((r) => r.channel_id);

  const payload = {
    guildId: guild.id,
    guildName: guild.name,
    createdAt: new Date().toISOString(),
    categories,
    channels,
    roles,
    logChannelIds,
    adminRoleIds: extras.adminRoleIds || serverConfig.adminRoleIds || [],
    note: 'Structural backup only — no tokens/secrets.',
  };

  fs.mkdirSync(backupsDir, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const file = path.join(backupsDir, `guild-${guild.id}-${stamp}.json`);
  fs.writeFileSync(file, JSON.stringify(payload, null, 2), 'utf8');
  return { file, payload };
}
