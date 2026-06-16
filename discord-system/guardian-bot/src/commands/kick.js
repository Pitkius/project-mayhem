import { SlashCommandBuilder, PermissionFlagsBits } from 'discord.js';
import { sendModLog } from '../logs/dispatcher.js';
import { isModerator } from '../utils/permissions.js';

export default {
  data: new SlashCommandBuilder()
    .setName('kick')
    .setDescription('Išmeta narį')
    .addUserOption((o) => o.setName('user').setDescription('Narys').setRequired(true))
    .addStringOption((o) => o.setName('reason').setDescription('Priežastis'))
    .setDefaultMemberPermissions(PermissionFlagsBits.KickMembers),
  async execute(interaction) {
    if (!isModerator(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const user = interaction.options.getUser('user', true);
    const reason = interaction.options.getString('reason') || 'No reason';
    const member = await interaction.guild.members.fetch(user.id).catch(() => null);

    if (!member?.kickable) {
      return interaction.reply({ content: 'Negaliu kickinti.', ephemeral: true });
    }

    await member.kick(`${interaction.user.tag}: ${reason}`);
    await sendModLog(interaction.guild, 'Kick', `${user.tag}`, [
      { name: 'Moderator', value: `${interaction.user}`, inline: true },
      { name: 'Reason', value: reason },
    ]);
    await interaction.reply({ content: `${user.tag} kicked.`, ephemeral: true });
  },
};
