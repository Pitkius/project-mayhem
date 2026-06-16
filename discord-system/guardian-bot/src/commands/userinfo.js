import { SlashCommandBuilder, EmbedBuilder } from 'discord.js';
import { getWarnings } from '../database/sqlite.js';

export default {
  data: new SlashCommandBuilder()
    .setName('userinfo')
    .setDescription('Nario informacija')
    .addUserOption((o) => o.setName('user').setDescription('Narys')),
  async execute(interaction) {
    const user = interaction.options.getUser('user') || interaction.user;
    const member = await interaction.guild.members.fetch(user.id).catch(() => null);
    const warnings = getWarnings(interaction.guild.id, user.id).length;

    const embed = new EmbedBuilder()
      .setTitle(user.tag)
      .setThumbnail(user.displayAvatarURL())
      .addFields(
        { name: 'ID', value: user.id, inline: true },
        { name: 'Bot', value: user.bot ? 'Yes' : 'No', inline: true },
        { name: 'Warnings', value: `${warnings}`, inline: true },
        { name: 'Joined', value: member ? `<t:${Math.floor(member.joinedTimestamp / 1000)}:R>` : 'N/A', inline: true },
        { name: 'Created', value: `<t:${Math.floor(user.createdTimestamp / 1000)}:R>`, inline: true },
        { name: 'Roles', value: member ? member.roles.cache.filter((r) => r.id !== interaction.guild.id).map((r) => r.toString()).join(' ') || 'None' : 'N/A' },
      )
      .setColor(member?.displayColor || 0x5865f2);

    await interaction.reply({ embeds: [embed], ephemeral: true });
  },
};
