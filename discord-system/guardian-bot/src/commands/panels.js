import {
  SlashCommandBuilder,
  PermissionFlagsBits,
  ChannelType,
} from 'discord.js';
import { isAdmin } from '../utils/permissions.js';
import { postRolePicker } from '../roles/picker.js';
import { postTicketPanel } from '../tickets/panel.js';
import { getServerSetup, setServerSetup } from '../database/sqlite.js';
import { serverConfig } from '../server/config.js';
import { applyCivilGatePermissions } from '../server/apply.js';

export default {
  data: new SlashCommandBuilder()
    .setName('panels')
    .setDescription('Paskelbia modernias paneles (roles / ticket / gate)')
    .setDMPermission(false)
    .setDefaultMemberPermissions(PermissionFlagsBits.Administrator)
    .addSubcommand((sc) => sc
      .setName('roles')
      .setDescription('Civilis + ping role picker (select menu — tikrai duoda rolę)')
      .addRoleOption((o) => o.setName('civilis').setDescription('Civilis rolė').setRequired(true))
      .addChannelOption((o) => o
        .setName('channel')
        .setDescription('Kanalas paneliui')
        .addChannelTypes(ChannelType.GuildText, ChannelType.GuildAnnouncement))
      .addRoleOption((o) => o.setName('naujienos').setDescription('Naujienų ping'))
      .addRoleOption((o) => o.setName('atnaujinimai').setDescription('Atnaujinimų ping'))
      .addRoleOption((o) => o.setName('eventai').setDescription('Eventų ping')))
    .addSubcommand((sc) => sc
      .setName('tickets')
      .setDescription('Ticket panelė')
      .addChannelOption((o) => o
        .setName('channel')
        .setDescription('Kanalas paneliui')
        .addChannelTypes(ChannelType.GuildText, ChannelType.GuildAnnouncement)))
    .addSubcommand((sc) => sc
      .setName('gate')
      .setDescription('Be Civilis — mato tik Sveiki atvykę + pasirink-roles')
      .addRoleOption((o) => o.setName('civilis').setDescription('Civilis rolė').setRequired(true))),

  async execute(interaction) {
    if (!isAdmin(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const sub = interaction.options.getSubcommand();
    const channel = interaction.options.getChannel('channel') || interaction.channel;

    if (sub === 'roles') {
      const civil = interaction.options.getRole('civilis', true);
      await postRolePicker(channel, {
        civilRoleId: civil.id,
        newsPingRoleId: interaction.options.getRole('naujienos')?.id || serverConfig.newsPingRoleId,
        updatesPingRoleId: interaction.options.getRole('atnaujinimai')?.id || serverConfig.updatesPingRoleId,
        eventsPingRoleId: interaction.options.getRole('eventai')?.id || serverConfig.eventsPingRoleId,
      });
      const setup = getServerSetup(interaction.guildId) || {};
      setServerSetup(interaction.guildId, { ...setup, civilRoleId: civil.id });
      return interaction.reply({
        content: `Role picker paskelbta ${channel}. Civilis: ${civil}`,
        ephemeral: true,
      });
    }

    if (sub === 'tickets') {
      const setup = getServerSetup(interaction.guildId) || {};
      await postTicketPanel(channel, {
        categoryId: setup.categoryMap?.tickets,
        adminRoleIds: setup.adminRoleIds || serverConfig.adminRoleIds,
      });
      return interaction.reply({
        content: `Ticket panelė paskelbta ${channel}.`,
        ephemeral: true,
      });
    }

    if (sub === 'gate') {
      await interaction.deferReply({ ephemeral: true });
      const civil = interaction.options.getRole('civilis', true);
      const setup = getServerSetup(interaction.guildId) || {};
      setServerSetup(interaction.guildId, { ...setup, civilRoleId: civil.id });
      const result = await applyCivilGatePermissions(interaction.guild, {
        civilRoleId: civil.id,
        adminRoleIds: setup.adminRoleIds || serverConfig.adminRoleIds,
      });
      return interaction.editReply({
        content: [
          `Civilis gate pritaikytas. Rolė: ${civil}`,
          'Be Civilis mato tik **Sveiki atvykę** + **pasirink-roles**.',
          `Atnaujinta kanalų: **${result.updated.length}**`,
        ].join('\n'),
      });
    }
  },
};
