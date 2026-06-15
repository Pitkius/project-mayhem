import { Colors, EmbedBuilder } from 'discord.js';

import { BOT_BRAND } from './branding.js';

export function baseEmbed(title, description, color = Colors.Blurple) {
  return new EmbedBuilder()
    .setTitle(title)
    .setDescription(description || '—')
    .setColor(color)
    .setTimestamp()
    .setFooter({ text: BOT_BRAND.footer });
}

export function userEmbed(title, fields, color = Colors.Blurple) {
  const embed = baseEmbed(title, null, color);
  if (fields?.length) embed.addFields(fields);
  return embed;
}

export function modEmbed(action, moderator, target, reason) {
  return baseEmbed(`Moderation: ${action}`, null, Colors.Red)
    .addFields(
      { name: 'Moderator', value: `${moderator}`, inline: true },
      { name: 'Target', value: `${target}`, inline: true },
      { name: 'Reason', value: reason || 'No reason provided' },
    );
}

export function auditEmbed(title, executor, details, color = Colors.Orange) {
  return baseEmbed(title, details, color)
    .setFooter({ text: executor ? `By: ${executor.tag} (${executor.id})` : 'Unknown executor' });
}

export function joinEmbed(member) {
  const created = Math.floor(member.user.createdTimestamp / 1000);

  return new EmbedBuilder()
    .setTitle('✈️ Naujas keleivis atvyko')
    .setDescription(`${member} prisijungė prie **${member.guild.name}**`)
    .setColor(Colors.Green)
    .setThumbnail(member.user.displayAvatarURL({ size: 256 }))
    .addFields(
      { name: 'Vartotojas', value: member.user.tag, inline: true },
      { name: 'ID', value: member.id, inline: true },
      { name: 'Paskyra sukurta', value: `<t:${created}:R>`, inline: true },
      { name: 'Narių skaičius', value: `${member.guild.memberCount}`, inline: true },
    )
    .setTimestamp()
    .setFooter({ text: BOT_BRAND.footer });
}

export function logColors() {
  return {
    mod: Colors.Red,
    antinuke: Colors.DarkRed,
    message: Colors.Grey,
    member: Colors.Green,
    join: Colors.Green,
    role: Colors.Purple,
    channel: Colors.Blue,
    voice: Colors.Aqua,
    webhook: Colors.Yellow,
    security: Colors.DarkOrange,
  };
}
