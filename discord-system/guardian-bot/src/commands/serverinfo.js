import { SlashCommandBuilder, EmbedBuilder } from 'discord.js';

export default {
  data: new SlashCommandBuilder()
    .setName('serverinfo')
    .setDescription('Serverio informacija'),
  async execute(interaction) {
    const g = interaction.guild;
    const embed = new EmbedBuilder()
      .setTitle(g.name)
      .setThumbnail(g.iconURL())
      .addFields(
        { name: 'ID', value: g.id, inline: true },
        { name: 'Members', value: `${g.memberCount}`, inline: true },
        { name: 'Channels', value: `${g.channels.cache.size}`, inline: true },
        { name: 'Roles', value: `${g.roles.cache.size}`, inline: true },
        { name: 'Owner', value: `<@${g.ownerId}>`, inline: true },
        { name: 'Created', value: `<t:${Math.floor(g.createdTimestamp / 1000)}:R>`, inline: true },
      )
      .setColor(0x5865f2);

    await interaction.reply({ embeds: [embed], ephemeral: true });
  },
};
