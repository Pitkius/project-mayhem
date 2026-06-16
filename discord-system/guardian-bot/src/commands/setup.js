import { SlashCommandBuilder, PermissionFlagsBits } from 'discord.js';
import { upsertGuildSettings } from '../database/sqlite.js';
import { appConfig } from '../config.js';
import { isAdmin } from '../utils/permissions.js';
import { provisionLogChannels, formatProvisionSummary } from '../logs/provision.js';

export default {
  data: new SlashCommandBuilder()
    .setName('setup')
    .setDescription('Inicializuoja Guardian bota ir sukuria logų kanalus')
    .setDefaultMemberPermissions(PermissionFlagsBits.Administrator),
  async execute(interaction) {
    if (!isAdmin(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    await interaction.deferReply({ ephemeral: true });

    upsertGuildSettings(interaction.guildId, {
      antinuke_enabled: true,
      antinuke: appConfig.defaultAntinuke,
    });

    const lines = ['**MRP Guardian** sukonfigūruotas.', ''];

    try {
      const results = await provisionLogChannels(interaction.guild, interaction.client);
      lines.push(formatProvisionSummary(results));
      lines.push('', 'Jei reikia perkurti kanalus vėliau: `/setuplogs`');
      lines.push('Whitelist: `/whitelist add` · Anti-nuke: `/antinuke settings`');
    } catch (err) {
      console.error('[MRP] setup logs error:', err);
      lines.push(`Logų kanalų klaida: ${err.message}`);
      lines.push('Bandyk rankiniu būdu: `/setuplogs`');
    }

    await interaction.editReply({ content: lines.join('\n') });
  },
};
