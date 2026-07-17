import { SlashCommandBuilder } from 'discord.js';
import { ipEmbed } from '../server/embeds.js';
import { serverConfig } from '../server/config.js';

export default {
  data: new SlashCommandBuilder()
    .setName('ip')
    .setDescription('Parodo FiveM serverio prisijungimo adresą')
    .setDMPermission(false),

  async execute(interaction) {
    const channelName = interaction.channel?.name || '';
    const preferred = serverConfig.offTopicChannelMatch.test(channelName);

    if (!preferred) {
      await interaction.reply({
        content: 'Šią komandą naudok kanale **🎉・off-topic**. Žemiau vis tiek pateikiu IP.',
        embeds: [ipEmbed()],
        ephemeral: true,
      });
      return;
    }

    await interaction.reply({
      embeds: [ipEmbed()],
      ephemeral: true,
    });
  },
};
