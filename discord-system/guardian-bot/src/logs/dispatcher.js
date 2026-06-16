import { getLogChannel } from '../database/sqlite.js';
import { baseEmbed, joinEmbed, logColors } from '../utils/embeds.js';

export async function sendJoinLog(member) {
  const guild = member.guild;
  const channelId = getLogChannel(guild.id, 'join') || getLogChannel(guild.id, 'member');
  if (!channelId) return;

  const channel = await guild.channels.fetch(channelId).catch(() => null);
  if (!channel?.isTextBased()) return;

  await channel.send({
    content: `Sveikas atvykęs, ${member}!`,
    embeds: [joinEmbed(member)],
  }).catch(() => null);
}

export async function sendGuildLog(guild, type, title, description, extraFields = []) {
  const channelId = getLogChannel(guild.id, type);
  if (!channelId) return;

  const channel = await guild.channels.fetch(channelId).catch(() => null);
  if (!channel?.isTextBased()) return;

  const colors = logColors();
  const embed = baseEmbed(title, description, colors[type] || 0x5865f2);
  if (extraFields.length) embed.addFields(extraFields);

  await channel.send({ embeds: [embed] }).catch(() => null);
}

export async function sendAntinukeLog(guild, title, description, fields = []) {
  return sendGuildLog(guild, 'antinuke', title, description, fields);
}

export async function sendSecurityLog(guild, title, description, fields = []) {
  return sendGuildLog(guild, 'security', title, description, fields);
}

export async function sendModLog(guild, title, description, fields = []) {
  return sendGuildLog(guild, 'mod', title, description, fields);
}
