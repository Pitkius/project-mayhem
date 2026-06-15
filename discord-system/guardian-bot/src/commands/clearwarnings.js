import { SlashCommandBuilder, PermissionFlagsBits } from 'discord.js';
import { clearWarnings } from '../database/sqlite.js';
import { isModerator } from '../utils/permissions.js';

export default {
  data: new SlashCommandBuilder()
    .setName('clearwarnings')
    .setDescription('Išvalo nario įspėjimus')
    .addUserOption((o) => o.setName('user').setDescription('Narys').setRequired(true))
    .setDefaultMemberPermissions(PermissionFlagsBits.ModerateMembers),
  async execute(interaction) {
    if (!isModerator(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const user = interaction.options.getUser('user', true);
    const removed = clearWarnings(interaction.guildId, user.id);
    await interaction.reply({ content: `Pašalinta ${removed} įspėjimų — ${user.tag}.`, ephemeral: true });
  },
};
