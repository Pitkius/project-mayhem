import { ActivityType, ChannelType } from 'discord.js';
import { env } from '../config.js';
import { fetchDiscordGuildStats, formatGuildChannelName } from './guildStats.js';

const state = {
  timer: null,
  debounceTimer: null,
  lastLabel: null,
  lastRenameAt: 0,
  running: false,
  client: null,
};

function statsConfig() {
  const enabled = String(
    process.env.DISCORD_STATS_ENABLED ?? process.env.FIVEM_STATUS_ENABLED ?? 'true',
  ).toLowerCase() !== 'false';

  return {
    enabled,
    guildId: process.env.DISCORD_STATS_GUILD_ID || process.env.FIVEM_STATUS_GUILD_ID || env.guildId || null,
    channelId: process.env.DISCORD_STATS_CHANNEL_ID || process.env.FIVEM_STATUS_CHANNEL_ID || null,
    channelMatch: process.env.DISCORD_STATS_CHANNEL_MATCH || process.env.FIVEM_STATUS_CHANNEL_MATCH || 'gyventojai',
    template:
      process.env.DISCORD_STATS_CHANNEL_TEMPLATE
      || process.env.FIVEM_STATUS_CHANNEL_TEMPLATE
      || 'Gyventojai: {members}',
    intervalMs: Math.max(
      30_000,
      Number(process.env.DISCORD_STATS_INTERVAL_MS || process.env.FIVEM_STATUS_INTERVAL_MS) || 60_000,
    ),
    minRenameGapMs: Math.max(
      15_000,
      Number(process.env.DISCORD_STATS_MIN_RENAME_MS || process.env.FIVEM_STATUS_MIN_RENAME_MS) || 60_000,
    ),
    eventDebounceMs: Math.max(
      1_000,
      Number(process.env.DISCORD_STATS_EVENT_DEBOUNCE_MS) || 3_000,
    ),
    eventMinRenameGapMs: Math.max(
      10_000,
      Number(process.env.DISCORD_STATS_EVENT_MIN_RENAME_MS) || 15_000,
    ),
    updatePresence: String(
      process.env.DISCORD_STATS_UPDATE_PRESENCE ?? process.env.FIVEM_STATUS_UPDATE_PRESENCE ?? 'true',
    ).toLowerCase() !== 'false',
  };
}

function isStatsGuild(guild, cfg) {
  if (!guild) return false;
  if (!cfg.guildId) return true;
  return guild.id === cfg.guildId;
}

function findStatsChannel(guild, cfg) {
  if (cfg.channelId) {
    const ch = guild.channels.cache.get(cfg.channelId);
    if (ch?.isVoiceBased?.()) return ch;
  }
  const match = String(cfg.channelMatch || '').trim().toLowerCase();
  if (!match) return null;
  return guild.channels.cache.find((ch) => {
    if (ch.type !== ChannelType.GuildVoice && ch.type !== ChannelType.GuildStageVoice) return false;
    return String(ch.name || '').toLowerCase().includes(match);
  }) || null;
}

async function renameChannel(channel, nextName, minRenameGapMs) {
  const now = Date.now();
  if (channel.name === nextName) return false;
  if (state.lastLabel === nextName) return false;
  if (now - state.lastRenameAt < minRenameGapMs && state.lastLabel != null) {
    return false;
  }
  await channel.setName(nextName, 'Discord gyventojų skaičius');
  state.lastLabel = nextName;
  state.lastRenameAt = now;
  return true;
}

/**
 * @param {import('discord.js').Client} client
 * @param {{ guild?: import('discord.js').Guild, reason?: string, fromEvent?: boolean }} [opts]
 */
async function tick(client, opts = {}) {
  if (state.running) return;
  state.running = true;
  const cfg = statsConfig();
  try {
    if (!cfg.enabled) return;

    const guild = opts.guild
      || (cfg.guildId
        ? client.guilds.cache.get(cfg.guildId) || await client.guilds.fetch(cfg.guildId).catch(() => null)
        : client.guilds.cache.first());
    if (!guild) {
      console.warn('[MRP] Discord stats: serveris nerastas (nustatyk DISCORD_GUILD_ID)');
      return;
    }

    const stats = await fetchDiscordGuildStats(guild);
    const channel = findStatsChannel(guild, cfg);
    if (!channel) {
      console.warn('[MRP] Discord stats: nerastas voice kanalas (DISCORD_STATS_CHANNEL_ID)');
      return;
    }

    const nextName = formatGuildChannelName(cfg.template, stats);
    const gap = opts.fromEvent ? cfg.eventMinRenameGapMs : cfg.minRenameGapMs;
    const renamed = await renameChannel(channel, nextName, gap);
    if (renamed) {
      const tag = opts.reason ? ` (${opts.reason})` : '';
      console.log(`[MRP] Discord stats: ${nextName}${tag}`);
    }

    if (cfg.updatePresence && client.user) {
      const onlinePart = stats.online != null ? ` · ${stats.online} prisijungę` : '';
      client.user.setPresence({
        activities: [{ name: `${stats.members} nariai${onlinePart}`, type: ActivityType.Watching }],
        status: 'online',
      });
    }
  } catch (err) {
    console.warn('[MRP] Discord stats klaida:', err.message);
  } finally {
    state.running = false;
  }
}

/**
 * Iškviesti kai narys prisijungia / išeina — atnaujina po trumpo debounce.
 * @param {import('discord.js').Client} client
 * @param {import('discord.js').Guild} guild
 * @param {string} [reason]
 */
export function requestMemberStatsRefresh(client, guild, reason = 'narys') {
  const cfg = statsConfig();
  if (!cfg.enabled || !isStatsGuild(guild, cfg)) return;

  state.client = client;
  if (state.debounceTimer) clearTimeout(state.debounceTimer);
  state.debounceTimer = setTimeout(() => {
    tick(client, { guild, reason, fromEvent: true });
  }, cfg.eventDebounceMs);
}

export function startMemberChannelTracker(client) {
  const cfg = statsConfig();
  if (!cfg.enabled) {
    console.log('[MRP] Discord stats kanalas išjungtas');
    return;
  }

  state.client = client;
  if (state.timer) clearInterval(state.timer);
  tick(client, { reason: 'start' });
  state.timer = setInterval(() => tick(client, { reason: 'interval' }), cfg.intervalMs);
  console.log(
    `[MRP] Discord narių sekimas įjungtas (interval ${Math.round(cfg.intervalMs / 1000)}s, live join/leave)`,
  );
}

export function stopMemberChannelTracker() {
  if (state.timer) clearInterval(state.timer);
  if (state.debounceTimer) clearTimeout(state.debounceTimer);
  state.timer = null;
  state.debounceTimer = null;
}

/** @deprecated naudok startMemberChannelTracker */
export const startPlayerChannelTracker = startMemberChannelTracker;
export const stopPlayerChannelTracker = stopMemberChannelTracker;
