import { SlashCommandBuilder, PermissionFlagsBits } from 'discord.js';
import { sendModLog } from '../logs/dispatcher.js';
import { isModerator } from '../utils/permissions.js';

export default {
  data: new SlashCommandBuilder()
    .setName('timeout')
    .setDescription('Timeout (mute) narį')
    .addUserOption((o) => o.setName('user').setDescription('Narys').setRequired(true))
    .addIntegerOption((o) => o.setName('minutes').setDescription('Minutės').setRequired(true).setMinValue(1).setMaxValue(40320))
    .addStringOption((o) => o.setName('reason').setDescription('Priežastis'))
    .setDefaultMemberPermissions(PermissionFlagsBits.ModerateMembers),
  async execute(interaction) {
    if (!isModerator(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const user = interaction.options.getUser('user', true);
    const minutes = interaction.options.getInteger('minutes', true);
    const reason = interaction.options.getString('reason') || 'No reason';
    const member = await interaction.guild.members.fetch(user.id).catch(() => null);

    if (!member?.moderatable) {
      return interaction.reply({ content: 'Negaliu timeout.', ephemeral: true });
    }

    await member.timeout(minutes * 60 * 1000, `${interaction.user.tag}: ${reason}`);
    await sendModLog(interaction.guild, 'Timeout', `${user.tag} — ${minutes}m`, [
      { name: 'Moderator', value: `${interaction.user}`, inline: true },
      { name: 'Reason', value: reason },
    ]);
    await interaction.reply({ content: `${user.tag} timeout ${minutes}m.`, ephemeral: true });
  },
};
