import { SlashCommandBuilder, PermissionFlagsBits } from 'discord.js';
import { provisionLogChannels, formatProvisionSummary } from '../logs/provision.js';
import { isAdmin } from '../utils/permissions.js';

export default {
  data: new SlashCommandBuilder()
    .setName('setuplogs')
    .setDescription('Automatiškai sukuria logų kategorijas ir kanalus po Admin-logai')
    .setDefaultMemberPermissions(PermissionFlagsBits.Administrator),
  async execute(interaction) {
    if (!isAdmin(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    await interaction.deferReply({ ephemeral: true });

    try {
      const results = await provisionLogChannels(interaction.guild, interaction.client);
      await interaction.editReply({ content: formatProvisionSummary(results) });
    } catch (err) {
      console.error('[MRP] setuplogs error:', err);
      await interaction.editReply({
        content: `Nepavyko sukurti logų struktūros: ${err.message}`,
      });
    }
  },
};
