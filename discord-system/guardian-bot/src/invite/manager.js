import { ChannelType, PermissionFlagsBits } from 'discord.js';
import {
  getInviteSettings,
  listGuildsWithInvite,
  setInviteSettings,
} from '../database/sqlite.js';
import { sendSecurityLog } from '../logs/dispatcher.js';

const tracker = {
  timer: null,
  running: false,
  client: null,
};

function inviteConfig() {
  return {
    enabled: String(process.env.DISCORD_INVITE_ENABLED ?? 'true').toLowerCase() !== 'false',
    defaultChannelId: process.env.DISCORD_INVITE_CHANNEL_ID || null,
    checkIntervalMs: Math.max(
      60_000,
      Number(process.env.DISCORD_INVITE_CHECK_INTERVAL_MS) || 900_000,
    ),
    reason: process.env.DISCORD_INVITE_REASON || 'MAYHEM RP permanent invite',
  };
}

function inviteUrlFromCode(code) {
  return `https://discord.gg/${code}`;
}

function buildInviteRecord(invite, channelId, messageId = null) {
  return {
    code: invite.code,
    channelId: String(channelId),
    url: invite.url || inviteUrlFromCode(invite.code),
    messageId: messageId || null,
    maxAge: 0,
    maxUses: 0,
    updatedAt: new Date().toISOString(),
  };
}

async function resolveInviteChannel(guild, preferredChannelId) {
  const cfg = inviteConfig();
  const channelId = preferredChannelId || cfg.defaultChannelId;
  if (!channelId) {
    throw new Error('Nenurodytas invite kanalas. Naudok /invite setup channel:#...');
  }

  const channel = await guild.channels.fetch(channelId).catch(() => null);
  if (!channel || (channel.type !== ChannelType.GuildText && channel.type !== ChannelType.GuildAnnouncement)) {
    throw new Error('Invite kanalas nerastas arba nėra tekstinis.');
  }

  const me = guild.members.me;
  if (!me) throw new Error('Bot narys nerastas guild’e.');

  const perms = channel.permissionsFor(me);
  if (!perms?.has(PermissionFlagsBits.CreateInstantInvite)) {
    throw new Error(`Botui trūksta Create Instant Invite teisės kanale #${channel.name}.`);
  }

  return channel;
}

async function createPermanentInvite(channel, reason) {
  return channel.createInvite({
    maxAge: 0,
    maxUses: 0,
    unique: true,
    reason: reason || inviteConfig().reason,
  });
}

async function upsertPublicInviteMessage(channel, record, previousMessageId) {
  const me = channel.guild.members.me;
  const canSend = channel.permissionsFor(me)?.has(PermissionFlagsBits.SendMessages);
  if (!canSend) return previousMessageId || null;

  const body = [
    '**MAYHEM RP — Discord invite**',
    'Ši nuoroda galioja nuolat (permanent).',
    '',
    record.url,
    '',
    '_Jei nesijungia į FiveM — patvirtink ✅ (Member) Discord’e._',
  ].join('\n');

  if (previousMessageId) {
    const existing = await channel.messages.fetch(previousMessageId).catch(() => null);
    if (existing?.editable) {
      await existing.edit({ content: body }).catch(() => null);
      return existing.id;
    }
  }

  const sent = await channel.send({ content: body }).catch(() => null);
  if (!sent) return previousMessageId || null;

  if (channel.permissionsFor(me)?.has(PermissionFlagsBits.ManageMessages)) {
    await sent.pin().catch(() => null);
  }

  return sent.id;
}

/**
 * Sukuria / atnaujina permanent invite ir išsaugo DB.
 * @param {{ forceNew?: boolean, notify?: boolean, reason?: string }} options
 */
export async function ensureGuildInvite(guild, channelId, options = {}) {
  const {
    forceNew = false,
    notify = false,
    reason = inviteConfig().reason,
  } = options;

  const channel = await resolveInviteChannel(guild, channelId);
  const existing = getInviteSettings(guild.id);
  let invite = null;
  let recreated = false;

  if (!forceNew && existing?.code && String(existing.channelId) === String(channel.id)) {
    invite = await guild.invites.fetch(existing.code).catch(() => null);
  }

  if (!invite) {
    invite = await createPermanentInvite(channel, reason);
    recreated = Boolean(existing?.code);
  }

  const messageId = await upsertPublicInviteMessage(
    channel,
    buildInviteRecord(invite, channel.id, existing?.messageId),
    existing?.messageId,
  );

  const record = buildInviteRecord(invite, channel.id, messageId);
  setInviteSettings(guild.id, record);

  if (notify && recreated) {
    await sendSecurityLog(
      guild,
      'Discord invite atkurtas',
      [
        'Senas permanent invite nebegaliojo — sukurtas naujas.',
        '',
        `Naujas URL: ${record.url}`,
        '',
        'Atnaujinkite:',
        '• txAdmin → Allowlist instructions',
        '• `QBConfig.Server.Discord` (qb-core/config.lua)',
      ].join('\n'),
      [
        { name: 'Kanalas', value: `<#${record.channelId}>`, inline: true },
        { name: 'Kodas', value: `\`${record.code}\``, inline: true },
      ],
    );
  }

  return { record, recreated, created: !existing?.code || recreated || forceNew };
}

export async function checkAndRepairGuildInvite(guild) {
  const existing = getInviteSettings(guild.id);
  if (!existing?.code || !existing?.channelId) {
    return { skipped: true };
  }

  const live = await guild.invites.fetch(existing.code).catch(() => null);
  if (live) {
    return { ok: true, record: existing };
  }

  return ensureGuildInvite(guild, existing.channelId, {
    forceNew: true,
    notify: true,
    reason: 'MAYHEM RP invite auto-repair (expired/deleted)',
  });
}

async function runInviteHealthCheck(client) {
  if (tracker.running) return;
  tracker.running = true;
  try {
    const rows = listGuildsWithInvite();
    for (const { guildId } of rows) {
      const guild = client.guilds.cache.get(guildId)
        || await client.guilds.fetch(guildId).catch(() => null);
      if (!guild) continue;
      try {
        await checkAndRepairGuildInvite(guild);
      } catch (err) {
        console.warn(`[MRP] Invite health-check (${guild.name}):`, err.message);
      }
    }
  } finally {
    tracker.running = false;
  }
}

export function startInviteHealthChecker(client) {
  const cfg = inviteConfig();
  if (!cfg.enabled) {
    console.log('[MRP] Discord invite health-check išjungtas');
    return;
  }

  tracker.client = client;
  if (tracker.timer) clearInterval(tracker.timer);

  const tick = () => {
    runInviteHealthCheck(client).catch((err) => {
      console.warn('[MRP] Invite health-check klaida:', err.message);
    });
  };

  // Trumpas delay po ready, paskui periodinis check
  setTimeout(tick, 15_000);
  tracker.timer = setInterval(tick, cfg.checkIntervalMs);
  console.log(`[MRP] Invite health-check kas ${Math.round(cfg.checkIntervalMs / 60_000)} min`);
}

export function getInviteStatus(guildId) {
  return getInviteSettings(guildId);
}
