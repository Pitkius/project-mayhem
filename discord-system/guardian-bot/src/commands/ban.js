import { SlashCommandBuilder, PermissionFlagsBits } from 'discord.js';
import { sendModLog } from '../logs/dispatcher.js';
import { isModerator } from '../utils/permissions.js';

export default {
  data: new SlashCommandBuilder()
    .setName('ban')
    .setDescription('Banina narį')
    .addUserOption((o) => o.setName('user').setDescription('Narys').setRequired(true))
    .addStringOption((o) => o.setName('reason').setDescription('Priežastis'))
    .addIntegerOption((o) => o.setName('delete_days').setDescription('Ištrinti žinutes (dienos)').setMinValue(0).setMaxValue(7))
    .setDefaultMemberPermissions(PermissionFlagsBits.BanMembers),
  async execute(interaction) {
    if (!isModerator(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const user = interaction.options.getUser('user', true);
    const reason = interaction.options.getString('reason') || 'No reason';
    const days = interaction.options.getInteger('delete_days') ?? 0;

    const member = await interaction.guild.members.fetch(user.id).catch(() => null);
    if (!member?.bannable) {
      return interaction.reply({ content: 'Negaliu baninti šio nario.', ephemeral: true });
    }

    await member.ban({ reason: `${interaction.user.tag}: ${reason}`, deleteMessageSeconds: days * 86400 });
    await sendModLog(interaction.guild, 'Ban', `${user.tag}`, [
      { name: 'Moderator', value: `${interaction.user}`, inline: true },
      { name: 'Reason', value: reason },
    ]);
    await interaction.reply({ content: `${user.tag} banned.`, ephemeral: true });
  },
};
