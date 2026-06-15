import { SlashCommandBuilder, PermissionFlagsBits, ChannelType } from 'discord.js';
import { setLogChannel } from '../database/sqlite.js';
import { LOG_TYPES } from '../config.js';
import { isAdmin } from '../utils/permissions.js';

export default {
  data: new SlashCommandBuilder()
    .setName('setlogchannel')
    .setDescription('Nustato logų kanalą')
    .addStringOption((opt) => opt.setName('type').setDescription('Logų tipas').setRequired(true)
      .addChoices(...LOG_TYPES.map((t) => ({ name: t, value: t }))))
    .addChannelOption((opt) => opt.setName('channel').setDescription('Kanalas').setRequired(true)
      .addChannelTypes(ChannelType.GuildText))
    .setDefaultMemberPermissions(PermissionFlagsBits.Administrator),
  async execute(interaction) {
    if (!isAdmin(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const type = interaction.options.getString('type', true);
    const channel = interaction.options.getChannel('channel', true);
    setLogChannel(interaction.guildId, type, channel.id);

    await interaction.reply({ content: `Log tipas \`${type}\` → ${channel}`, ephemeral: true });
  },
};
