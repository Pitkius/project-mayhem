import { SlashCommandBuilder, PermissionFlagsBits } from 'discord.js';
import { addWarning, getWarnings } from '../database/sqlite.js';
import { sendModLog } from '../logs/dispatcher.js';
import { isModerator } from '../utils/permissions.js';

export default {
  data: new SlashCommandBuilder()
    .setName('warn')
    .setDescription('Įspėja narį')
    .addUserOption((o) => o.setName('user').setDescription('Narys').setRequired(true))
    .addStringOption((o) => o.setName('reason').setDescription('Priežastis').setRequired(true))
    .setDefaultMemberPermissions(PermissionFlagsBits.ModerateMembers),
  async execute(interaction) {
    if (!isModerator(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const user = interaction.options.getUser('user', true);
    const reason = interaction.options.getString('reason', true);
    const id = addWarning(interaction.guildId, user.id, interaction.user.id, reason);
    const count = getWarnings(interaction.guildId, user.id).length;

    await sendModLog(interaction.guild, 'Warn', `${user.tag} (#${id})`, [
      { name: 'Moderator', value: `${interaction.user}`, inline: true },
      { name: 'Total warnings', value: `${count}`, inline: true },
      { name: 'Reason', value: reason },
    ]);
    await interaction.reply({ content: `Warn #${id} — ${user.tag} (${count} total)`, ephemeral: true });
  },
};
