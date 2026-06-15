import { SlashCommandBuilder, PermissionFlagsBits, ChannelType } from 'discord.js';
import { sendModLog } from '../logs/dispatcher.js';
import { isModerator } from '../utils/permissions.js';

export default {
  data: new SlashCommandBuilder()
    .setName('unlock')
    .setDescription('Atrakina kanalą')
    .addChannelOption((o) => o.setName('channel').setDescription('Kanalas').addChannelTypes(ChannelType.GuildText))
    .setDefaultMemberPermissions(PermissionFlagsBits.ManageChannels),
  async execute(interaction) {
    if (!isModerator(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const channel = interaction.options.getChannel('channel') || interaction.channel;
    const everyone = interaction.guild.roles.everyone;
    await channel.permissionOverwrites.edit(everyone, { SendMessages: null });
    await sendModLog(interaction.guild, 'Unlock', `${channel} unlocked by ${interaction.user}`);
    await interaction.reply({ content: `${channel} atrakintas.`, ephemeral: true });
  },
};
