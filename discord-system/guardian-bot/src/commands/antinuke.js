import { SlashCommandBuilder, PermissionFlagsBits } from 'discord.js';
import { getGuildSettings, upsertGuildSettings } from '../database/sqlite.js';
import { getAntinukeConfig } from '../antinuke/config.js';
import { isAdmin } from '../utils/permissions.js';

export default {
  data: new SlashCommandBuilder()
    .setName('antinuke')
    .setDescription('Anti-nuke nustatymai')
    .addSubcommand((s) => s.setName('enable').setDescription('Įjungti'))
    .addSubcommand((s) => s.setName('disable').setDescription('Išjungti'))
    .addSubcommand((s) => s.setName('settings').setDescription('Rodyti nustatymus'))
    .setDefaultMemberPermissions(PermissionFlagsBits.Administrator),
  async execute(interaction) {
    if (!isAdmin(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const sub = interaction.options.getSubcommand();
    const current = getGuildSettings(interaction.guildId);
    const config = getAntinukeConfig(interaction.guildId);

    if (sub === 'enable') {
      upsertGuildSettings(interaction.guildId, {
        antinuke_enabled: true,
        antinuke: current?.antinuke || config,
      });
      return interaction.reply({ content: 'Anti-nuke įjungtas.', ephemeral: true });
    }

    if (sub === 'disable') {
      upsertGuildSettings(interaction.guildId, { antinuke_enabled: false, antinuke: current?.antinuke });
      return interaction.reply({ content: 'Anti-nuke išjungtas.', ephemeral: true });
    }

    const thresholds = Object.entries(config.thresholds || {})
      .map(([k, v]) => `• ${k}: ${v.limit}/${v.windowSec}s`)
      .join('\n');

    return interaction.reply({
      content: `**Anti-nuke:** ${config.enabled ? 'ON' : 'OFF'}\n**Punishment:** ${config.punishment}\n**Thresholds:**\n${thresholds}`,
      ephemeral: true,
    });
  },
};
