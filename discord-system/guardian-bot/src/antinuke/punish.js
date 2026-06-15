import { sendAntinukeLog } from '../logs/dispatcher.js';
import { isWhitelisted } from '../database/sqlite.js';
import { trackAction, resetAction } from './tracker.js';
import { getAntinukeConfig, getThreshold } from './config.js';

export async function punishMember(guild, member, punishment, reason) {
  if (!member || !guild.members.me) return false;

  try {
    switch (punishment) {
      case 'removeRoles': {
        const roles = member.roles.cache.filter((r) => r.id !== guild.id);
        if (roles.size) await member.roles.set([], reason);
        break;
      }
      case 'timeout':
        await member.timeout(60 * 60 * 1000, reason);
        break;
      case 'kick':
        if (member.kickable) await member.kick(reason);
        break;
      case 'ban':
      default:
        if (member.bannable) await member.ban({ reason, deleteMessageSeconds: 0 });
        break;
    }
    return true;
  } catch {
    return false;
  }
}

export async function handleAntinuke(guild, executorId, actionType, details = '') {
  const config = getAntinukeConfig(guild.id);
  if (!config.enabled) return false;

  if (isWhitelisted(guild.id, executorId, guild)) return false;

  const threshold = getThreshold(config, actionType);
  const count = trackAction(guild.id, executorId, actionType, threshold.windowSec);

  if (count < threshold.limit) return false;

  const member = await guild.members.fetch(executorId).catch(() => null);
  const reason = `Anti-nuke: ${actionType} threshold exceeded (${count}/${threshold.limit})`;

  if (member) {
    await punishMember(guild, member, config.punishment, reason);
  }

  resetAction(guild.id, executorId, actionType);

  await sendAntinukeLog(
    guild,
    'Anti-Nuke Triggered',
    `Action: **${actionType}**\n${details}`,
    [
      { name: 'Executor', value: `<@${executorId}> (${executorId})`, inline: true },
      { name: 'Punishment', value: config.punishment, inline: true },
      { name: 'Count', value: `${count} in ${threshold.windowSec}s`, inline: true },
    ],
  );

  return true;
}

export async function getAuditExecutor(guild, type, targetId = null) {
  const logs = await guild.fetchAuditLogs({ type, limit: 6 }).catch(() => null);
  if (!logs) return null;

  const entry = logs.entries.find((e) => {
    if (Date.now() - e.createdTimestamp > 15_000) return false;
    if (targetId && e.target?.id && e.target.id !== targetId) return false;
    return true;
  });

  return entry?.executor || null;
}
