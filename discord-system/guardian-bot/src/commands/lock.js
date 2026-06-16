import { SlashCommandBuilder, PermissionFlagsBits, ChannelType } from 'discord.js';
import { sendModLog } from '../logs/dispatcher.js';
import { isModerator } from '../utils/permissions.js';

async function setLock(channel, locked, interaction) {
  const everyone = interaction.guild.roles.everyone;
  await channel.permissionOverwrites.edit(everyone, { SendMessages: !locked });
}

export default {
  data: new SlashCommandBuilder()
    .setName('lock')
    .setDescription('Užrakina kanalą')
    .addChannelOption((o) => o.setName('channel').setDescription('Kanalas').addChannelTypes(ChannelType.GuildText))
    .setDefaultMemberPermissions(PermissionFlagsBits.ManageChannels),
  async execute(interaction) {
    if (!isModerator(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const channel = interaction.options.getChannel('channel') || interaction.channel;
    await setLock(channel, true, interaction);
    await sendModLog(interaction.guild, 'Lock', `${channel} locked by ${interaction.user}`);
    await interaction.reply({ content: `${channel} užrakintas.`, ephemeral: true });
  },
};
