import fs from 'node:fs';
import path from 'node:path';
import { ChannelType, PermissionFlagsBits } from 'discord.js';
import { LOG_LAYOUT } from './channelLayout.js';
import { setLogChannel, setFivemWebhooks } from '../database/sqlite.js';

const WEBHOOK_NAME = 'MRP Server Logs';

function normalizeName(value) {
  return String(value || '').toLowerCase().replace(/[^a-z0-9-]/g, '');
}

function isLogCategoryName(name) {
  if (LOG_LAYOUT.anchorMatch.test(name)) return true;
  return LOG_LAYOUT.categories.some((cat) => cat.name === name);
}

function findTextChannel(guild, channelName) {
  const target = normalizeName(channelName);
  return guild.channels.cache.find(
    (channel) => channel.isTextBased?.() && normalizeName(channel.name) === target,
  );
}

function findCategory(guild, categoryName) {
  return guild.channels.cache.find(
    (channel) => channel.type === ChannelType.GuildCategory && channel.name === categoryName,
  );
}

function collectLogViewerRoleIds(guild) {
  const ids = new Set();
  for (const role of guild.roles.cache.values()) {
    if (role.permissions.has(PermissionFlagsBits.Administrator)) {
      ids.add(role.id);
    }
  }

  const extra = process.env.DISCORD_LOG_ROLE_IDS;
  if (extra) {
    for (const id of extra.split(',').map((s) => s.trim()).filter(Boolean)) {
      if (guild.roles.cache.has(id)) ids.add(id);
    }
  }

  return [...ids];
}

function buildOverwrites(guild, botId) {
  const overwrites = [
    {
      id: guild.roles.everyone.id,
      deny: [PermissionFlagsBits.ViewChannel],
    },
    {
      id: botId,
      allow: [
        PermissionFlagsBits.ViewChannel,
        PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.EmbedLinks,
        PermissionFlagsBits.AttachFiles,
        PermissionFlagsBits.ManageWebhooks,
        PermissionFlagsBits.ReadMessageHistory,
      ],
    },
  ];

  for (const roleId of collectLogViewerRoleIds(guild)) {
    overwrites.push({
      id: roleId,
      allow: [
        PermissionFlagsBits.ViewChannel,
        PermissionFlagsBits.ReadMessageHistory,
      ],
      deny: [
        PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.CreatePublicThreads,
        PermissionFlagsBits.SendMessagesInThreads,
      ],
    });
  }

  return overwrites;
}

async function applyPrivateLogOverwrites(channel, guild, botId) {
  if (!channel?.permissionOverwrites) return;
  await channel.permissionOverwrites.set(buildOverwrites(guild, botId));
}

async function ensureAnchor(guild) {
  const sorted = [...guild.channels.cache.values()].sort((a, b) => a.rawPosition - b.rawPosition);
  const existing = sorted.find(
    (channel) => channel.type === ChannelType.GuildCategory && LOG_LAYOUT.anchorMatch.test(channel.name),
  );
  if (existing) {
    await applyPrivateLogOverwrites(existing, guild, guild.members.me?.id || guild.client.user.id).catch(() => null);
    return existing;
  }

  const maxPos = sorted.length ? Math.max(...sorted.map((channel) => channel.rawPosition)) : 0;
  const anchor = await guild.channels.create({
    name: LOG_LAYOUT.anchorName,
    type: ChannelType.GuildCategory,
    position: maxPos + 1,
    permissionOverwrites: buildOverwrites(guild, guild.members.me?.id || guild.client.user.id),
    reason: 'MRP Guardian — logų zona',
  });
  return anchor;
}

async function resolveStartPosition(guild, anchor) {
  const sorted = [...guild.channels.cache.values()].sort((a, b) => a.rawPosition - b.rawPosition);
  const anchorIdx = sorted.findIndex((channel) => channel.id === anchor.id);
  let position = anchor.rawPosition + 1;

  for (let i = anchorIdx + 1; i < sorted.length; i += 1) {
    const channel = sorted[i];
    if (channel.type === ChannelType.GuildCategory && !isLogCategoryName(channel.name)) {
      break;
    }
    position = channel.rawPosition + 1;
  }

  return position;
}

async function ensureWebhook(channel) {
  const hooks = await channel.fetchWebhooks().catch(() => null);
  const existing = hooks?.find((hook) => hook.name === WEBHOOK_NAME);
  if (existing?.url) return existing.url;

  const hook = await channel.createWebhook({
    name: WEBHOOK_NAME,
    reason: 'FiveM server_logs integracija',
  });
  return hook.url;
}

function writeLuaExport(guildId, webhooks) {
  const lines = [
    `-- MRP Guardian auto-generated ${new Date().toISOString()}`,
    '-- Nukopijuok į resources/[local]/server_logs/config.lua → Config.Webhooks',
    'Config.Webhooks = {',
  ];

  for (const [key, url] of Object.entries(webhooks)) {
    lines.push(`    ${key} = '${url}',`);
  }
  lines.push('}');

  const dir = path.resolve(process.cwd(), 'data');
  fs.mkdirSync(dir, { recursive: true });
  const target = path.join(dir, `fivem-webhooks-${guildId}.lua`);
  fs.writeFileSync(target, `${lines.join('\n')}\n`, 'utf8');
  return target;
}

/**
 * Sukuria / atnaujina logų kategorijas ir kanalus po „Admin-logai“.
 * Discord logams — registruoja kanalus DB.
 * FiveM logams — sukuria webhook ir eksportuoja .lua failą.
 */
export async function provisionLogChannels(guild, client) {
  const results = {
    created: [],
    reused: [],
    webhooks: {},
    exportPath: null,
    errors: [],
    permissionsApplied: 0,
  };

  const botId = client.user.id;
  const anchor = await ensureAnchor(guild);
  let position = await resolveStartPosition(guild, anchor);

  for (const categoryDef of LOG_LAYOUT.categories) {
    let category = findCategory(guild, categoryDef.name);
    if (!category) {
      category = await guild.channels.create({
        name: categoryDef.name,
        type: ChannelType.GuildCategory,
        position,
        permissionOverwrites: buildOverwrites(guild, botId),
        reason: 'MRP Guardian — logų kategorija',
      });
      results.created.push(`Kategorija **${categoryDef.name}**`);
      position += 1;
    } else {
      await category.setPosition(position).catch((err) => {
        results.errors.push(`Kategorijos pozicija (${categoryDef.name}): ${err.message}`);
      });
      await applyPrivateLogOverwrites(category, guild, botId).catch((err) => {
        results.errors.push(`Kategorijos teisės (${categoryDef.name}): ${err.message}`);
      });
      results.reused.push(`Kategorija **${categoryDef.name}**`);
      results.permissionsApplied += 1;
      position += 1;
    }

    for (const channelDef of categoryDef.channels) {
      let channel = findTextChannel(guild, channelDef.name);
      if (!channel) {
        channel = await guild.channels.create({
          name: channelDef.name,
          type: ChannelType.GuildText,
          parent: category.id,
          permissionOverwrites: buildOverwrites(guild, botId),
          reason: 'MRP Guardian — logų kanalas',
        });
        results.created.push(`#${channelDef.name}`);
      } else {
        if (channel.parentId !== category.id) {
          await channel.setParent(category.id).catch((err) => {
            results.errors.push(`#${channelDef.name} perkėlimas: ${err.message}`);
          });
        }
        await applyPrivateLogOverwrites(channel, guild, botId).catch((err) => {
          results.errors.push(`#${channelDef.name} teisės: ${err.message}`);
        });
        results.reused.push(`#${channelDef.name}`);
        results.permissionsApplied += 1;
      }

      if (channelDef.discord) {
        setLogChannel(guild.id, channelDef.logType, channel.id);
      }

      if (channelDef.fivem) {
        try {
          const url = await ensureWebhook(channel);
          results.webhooks[channelDef.logType] = url;
        } catch (err) {
          results.errors.push(`Webhook #${channelDef.name}: ${err.message}`);
        }
      }
    }
  }

  if (Object.keys(results.webhooks).length) {
    setFivemWebhooks(guild.id, results.webhooks);
    results.exportPath = writeLuaExport(guild.id, results.webhooks);
  }

  return results;
}

export function formatProvisionSummary(results) {
  const lines = ['**Logų kanalai sukonfigūruoti.**', '🔒 Visi logų kanalai — tik **Administrator** rolėms.', ''];

  if (results.created.length) {
    lines.push(`Sukurta (${results.created.length}):`);
    lines.push(results.created.slice(0, 20).map((item) => `• ${item}`).join('\n'));
    if (results.created.length > 20) lines.push(`…ir dar ${results.created.length - 20}`);
    lines.push('');
  }

  if (results.reused.length) {
    lines.push(`Naudota esamų (${results.reused.length}): ${results.reused.length} elementų`);
    lines.push('');
  }

  const webhookCount = Object.keys(results.webhooks).length;
  if (webhookCount) {
    lines.push(`FiveM webhook: **${webhookCount}** tipų`);
    if (results.exportPath) {
      lines.push(`Lua eksportas: \`${results.exportPath}\``);
      lines.push('Nukopijuok URL į `server_logs/config.lua` → `Config.Webhooks`');
    }
  }

  if (results.errors.length) {
    lines.push('', '**Įspėjimai:**');
    lines.push(results.errors.slice(0, 8).map((item) => `• ${item}`).join('\n'));
  }

  return lines.join('\n');
}
