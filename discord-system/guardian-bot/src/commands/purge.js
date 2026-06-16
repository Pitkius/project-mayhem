import { SlashCommandBuilder, PermissionFlagsBits } from 'discord.js';
import { sendModLog } from '../logs/dispatcher.js';
import { isModerator } from '../utils/permissions.js';

export default {
  data: new SlashCommandBuilder()
    .setName('purge')
    .setDescription('Ištrina žinutes')
    .addIntegerOption((o) => o.setName('amount').setDescription('Kiekis (1-100)').setRequired(true).setMinValue(1).setMaxValue(100))
    .setDefaultMemberPermissions(PermissionFlagsBits.ManageMessages),
  async execute(interaction) {
    if (!isModerator(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const amount = interaction.options.getInteger('amount', true);
    await interaction.deferReply({ ephemeral: true });

    const deleted = await interaction.channel.bulkDelete(amount, true).catch(() => null);
    await sendModLog(interaction.guild, 'Purge', `${deleted?.size || 0} messages in ${interaction.channel}`, [
      { name: 'Moderator', value: `${interaction.user}`, inline: true },
    ]);
    await interaction.editReply({ content: `Ištrinta: ${deleted?.size || 0}` });
  },
};
