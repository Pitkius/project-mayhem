import { SlashCommandBuilder, PermissionFlagsBits } from 'discord.js';
import { upsertGuildSettings, setLogChannel } from '../database/sqlite.js';
import { appConfig } from '../config.js';
import { isAdmin } from '../utils/permissions.js';

export default {
  data: new SlashCommandBuilder()
    .setName('setup')
    .setDescription('Inicializuoja Guardian bota siame serveryje')
    .setDefaultMemberPermissions(PermissionFlagsBits.Administrator),
  async execute(interaction) {
    if (!isAdmin(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    upsertGuildSettings(interaction.guildId, {
      antinuke_enabled: true,
      antinuke: appConfig.defaultAntinuke,
    });

    const airportChannel = interaction.guild.channels.cache.find(
      (channel) => channel.isTextBased() && /oro[\s_-]?uostas/i.test(channel.name),
    );

    if (airportChannel) {
      setLogChannel(interaction.guildId, 'join', airportChannel.id);
    }

    const lines = ['**MRP Guardian** sukonfigūruotas.'];
    if (airportChannel) {
      lines.push(`Prisijungimai → ${airportChannel}`);
    } else {
      lines.push('Nustatyk prisijungimų kanalą: `/setlogchannel type:join channel:#oro-uostas`');
    }
    lines.push('Kiti logai: `/setlogchannel`');

    await interaction.reply({
      content: lines.join('\n'),
      ephemeral: true,
    });
  },
};
