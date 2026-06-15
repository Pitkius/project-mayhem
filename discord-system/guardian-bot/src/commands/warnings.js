import { SlashCommandBuilder, PermissionFlagsBits } from 'discord.js';
import { getWarnings } from '../database/sqlite.js';
import { isModerator } from '../utils/permissions.js';

export default {
  data: new SlashCommandBuilder()
    .setName('warnings')
    .setDescription('Rodo nario įspėjimus')
    .addUserOption((o) => o.setName('user').setDescription('Narys').setRequired(true))
    .setDefaultMemberPermissions(PermissionFlagsBits.ModerateMembers),
  async execute(interaction) {
    if (!isModerator(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const user = interaction.options.getUser('user', true);
    const rows = getWarnings(interaction.guildId, user.id);

    if (!rows.length) {
      return interaction.reply({ content: 'Įspėjimų nėra.', ephemeral: true });
    }

    const text = rows.map((w) => `#${w.id} — <@${w.moderator_id}>: ${w.reason} (<t:${Math.floor(new Date(w.created_at).getTime() / 1000)}:R>)`).join('\n');
    await interaction.reply({ content: `**${user.tag} warnings:**\n${text.slice(0, 1900)}`, ephemeral: true });
  },
};
