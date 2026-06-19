import { EmbedBuilder } from 'discord.js';
import { BOT_BRAND } from '../utils/branding.js';
import { findChannelBySlug } from './helpers.js';

export function buildAirportWelcomeEmbed(member, verification = {}) {
  const serverName = verification.welcomeTitle || BOT_BRAND.displayName;
  const lines = [
    `Sveikas atvykęs ${member} į **${serverName}**!`,
  ];

  if (verification.rulesChannelId) {
    lines.push(`Nepamirškite perskaityti <#${verification.rulesChannelId}> 📌 😄`);
  }

  const authorIcon = member.guild.iconURL({ size: 128 })
    || member.client.user?.displayAvatarURL({ size: 128 })
    || member.user.displayAvatarURL({ size: 128 });

  const thumbnail = member.user.displayAvatarURL({ size: 256 });

  return new EmbedBuilder()
    .setColor(0xFFFFFF)
    .setAuthor({
      name: `Sveikas ${member.user.username}!`,
      iconURL: authorIcon,
    })
    .setTitle(serverName)
    .setDescription(lines.join('\n'))
    .setThumbnail(thumbnail);
}

export async function sendWelcomeAnnouncement(member, verification) {
  const channelId = verification?.welcomeChannelId;
  if (!channelId) return;

  const channel = member.guild.channels.cache.get(channelId)
    ?? await member.guild.channels.fetch(channelId).catch(() => null);
  if (!channel?.isTextBased?.()) return;

  const rulesChannelId = verification.rulesChannelId
    || (await findChannelBySlug(member.guild, 'taisykles'))?.id
    || null;

  await channel.send({
    embeds: [buildAirportWelcomeEmbed(member, { ...verification, rulesChannelId })],
  }).catch((err) => {
    console.error('[Verification] welcome:', err.message);
  });
}
