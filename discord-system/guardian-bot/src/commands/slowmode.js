import { SlashCommandBuilder, PermissionFlagsBits, ChannelType } from 'discord.js';
import { isModerator } from '../utils/permissions.js';

export default {
  data: new SlashCommandBuilder()
    .setName('slowmode')
    .setDescription('Nustato slowmode')
    .addIntegerOption((o) => o.setName('seconds').setDescription('Sekundės (0 = off)').setRequired(true).setMinValue(0).setMaxValue(21600))
    .addChannelOption((o) => o.setName('channel').setDescription('Kanalas').addChannelTypes(ChannelType.GuildText))
    .setDefaultMemberPermissions(PermissionFlagsBits.ManageChannels),
  async execute(interaction) {
    if (!isModerator(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const seconds = interaction.options.getInteger('seconds', true);
    const channel = interaction.options.getChannel('channel') || interaction.channel;
    await channel.setRateLimitPerUser(seconds);
    await interaction.reply({
      content: seconds ? `${channel} slowmode: ${seconds}s` : `${channel} slowmode išjungtas.`,
      ephemeral: true,
    });
  },
};
