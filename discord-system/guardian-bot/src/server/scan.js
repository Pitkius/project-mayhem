import { ChannelType, PermissionFlagsBits } from 'discord.js';
import { getAllLogChannels } from '../database/sqlite.js';
import { LOG_LAYOUT } from '../logs/channelLayout.js';
import { normalizeChannelName } from '../verification/helpers.js';
import { SERVER_LAYOUT } from './layout.js';
import { serverConfig } from './config.js';

function isLogLike(channel, knownLogIds) {
  if (!channel) return false;
  if (knownLogIds.has(channel.id)) return true;
  const n = normalizeChannelName(channel.name);
  if (n.includes('log')) return true;
  if (LOG_LAYOUT.anchorMatch.test(channel.name)) return true;
  if (channel.parent && LOG_LAYOUT.anchorMatch.test(channel.parent.name)) return true;
  if (channel.parent && /log|fivem|discord/i.test(channel.parent.name) && /log/i.test(channel.name)) {
    return true;
  }
  return false;
}

function findByMatch(collection, match, type = null) {
  return collection.find((item) => {
    if (type != null && item.type !== type) return false;
    return match.test(item.name);
  }) || null;
}

export async function scanGuild(guild) {
  await guild.channels.fetch().catch(() => null);
  await guild.roles.fetch().catch(() => null);

  const knownLogIds = new Set(getAllLogChannels(guild.id).map((r) => r.channel_id));
  const channels = [...guild.channels.cache.values()];
  const categories = channels.filter((c) => c.type === ChannelType.GuildCategory);
  const text = channels.filter((c) => c.type === ChannelType.GuildText || c.type === ChannelType.GuildAnnouncement);
  const voice = channels.filter((c) => c.type === ChannelType.GuildVoice);
  const roles = [...guild.roles.cache.values()].filter((r) => r.id !== guild.id && !r.managed);

  const logChannels = text.filter((c) => isLogLike(c, knownLogIds));
  const uncertainLogs = text.filter((c) => {
    const n = normalizeChannelName(c.name);
    return n.includes('log') && !knownLogIds.has(c.id) && !isLogLike(c, knownLogIds);
  });

  const adminCandidates = roles
    .filter((r) => r.permissions.has(PermissionFlagsBits.Administrator)
      || r.permissions.has(PermissionFlagsBits.ManageGuild)
      || /admin|staff|mod|vadov|owner/i.test(r.name))
    .sort((a, b) => b.position - a.position);

  const plan = {
    createCategories: [],
    reuseCategories: [],
    createChannels: [],
    reuseChannels: [],
    skipLogs: logChannels.map((c) => ({ id: c.id, name: c.name })),
    uncertain: uncertainLogs.map((c) => ({ id: c.id, name: c.name })),
    adminCandidates: adminCandidates.map((r) => ({ id: r.id, name: r.name })),
  };

  for (const [catKey, catDef] of Object.entries(SERVER_LAYOUT.categories)) {
    const existingCat = findByMatch(categories, catDef.match, ChannelType.GuildCategory);
    if (existingCat) {
      plan.reuseCategories.push({ key: catKey, id: existingCat.id, name: existingCat.name });
    } else {
      plan.createCategories.push({ key: catKey, name: catDef.name });
    }

    for (const chDef of catDef.channels || []) {
      const type = chDef.type === 'voice' ? ChannelType.GuildVoice : ChannelType.GuildText;
      const pool = type === ChannelType.GuildVoice ? voice : text;
      const existing = findByMatch(pool, chDef.match || new RegExp(normalizeChannelName(chDef.name), 'i'), type);
      if (existing) {
        if (isLogLike(existing, knownLogIds)) {
          plan.skipLogs.push({ id: existing.id, name: existing.name, reason: 'log-like' });
          continue;
        }
        plan.reuseChannels.push({
          key: chDef.key,
          id: existing.id,
          name: existing.name,
          categoryKey: catKey,
        });
      } else {
        plan.createChannels.push({
          key: chDef.key,
          name: chDef.name,
          type: chDef.type,
          categoryKey: catKey,
          readOnly: !!chDef.readOnly,
          faction: chDef.faction || null,
        });
      }
    }
  }

  return {
    counts: {
      categories: categories.length,
      text: text.length,
      voice: voice.length,
      roles: roles.length,
      logs: logChannels.length,
    },
    plan,
    logChannelIds: [...knownLogIds],
    civilRole: roles.find((r) => /civil|verified|narys|member/i.test(r.name)) || null,
    factionRoles: {
      police: roles.find((r) => /policij|police|lspd|ltpd/i.test(r.name)) || null,
      ems: roles.find((r) => /medik|ems|ambulance/i.test(r.name)) || null,
      mechanic: roles.find((r) => /mechanik|mechanic/i.test(r.name)) || null,
      taxi: roles.find((r) => /taxi/i.test(r.name)) || null,
    },
  };
}

export function buildPreviewText(scan, adminRoleIds = []) {
  const { plan, counts } = scan;
  const lines = [
    '**Pilnas serverio rebuild** (dar niekas nekeista)',
    '',
    `Dabar: **${counts.categories}** kat. · **${counts.text}** tekst. · **${counts.voice}** voice`,
    '',
    '**Kas bus padaryta:**',
    '1. Backup į `data/backups/`',
    '2. Visa sena struktūra → **📦・SENAS SERVERIO ARCHYVAS**',
    '3. Nauja moderni struktūra iš naujo (PRADŽIA / TAISYKLĖS / BENDRUOMENĖ / ANKETOS / FRAKCIJOS / TICKETAI)',
    '4. Civilis + ping role picker + ticket + anketų panelės',
    '',
    `**Logai NELIEČIAMI:** ${plan.skipLogs.length} kanalų/kat.`,
    plan.uncertain.length
      ? `**Neaiškūs (taip pat neliečiami):** ${plan.uncertain.map((c) => `#${c.name}`).join(', ')}`
      : null,
    '',
    `**Admin rolės (teisėms):** ${adminRoleIds.length ? adminRoleIds.map((id) => `<@&${id}>`).join(', ') : '_pasirink žemiau_'}`,
    '',
    'Administracijos rolių **nekursiu**. Logų **neištrinsiu / nepervadinsiu**.',
  ];
  return lines.filter((l) => l !== null).join('\n');
}
