import {
  SlashCommandBuilder,
  PermissionFlagsBits,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  StringSelectMenuBuilder,
} from 'discord.js';
import { isAdmin } from '../utils/permissions.js';
import { setSetupSession, getSetupSession, clearSetupSession, addWhitelist } from '../database/sqlite.js';
import { scanGuild, buildPreviewText } from '../server/scan.js';
import { applyServerSetup, formatReport } from '../server/apply.js';
import { modernEmbed } from '../server/embeds.js';
import { serverConfig, mergeServerConfig } from '../server/config.js';

export const SETUP_CONFIRM_ID = 'mrp:setup:confirm';
export const SETUP_CANCEL_ID = 'mrp:setup:cancel';
export const SETUP_ADMIN_SELECT_ID = 'mrp:setup:admins';

export default {
  data: new SlashCommandBuilder()
    .setName('setup-server')
    .setDescription('Perdaro Discord serverį iš naujo (logai lieka)')
    .setDMPermission(false)
    .setDefaultMemberPermissions(PermissionFlagsBits.Administrator)
    .addRoleOption((o) => o.setName('civilis').setDescription('Civilis rolė (jei jau egzistuoja)'))
    .addRoleOption((o) => o.setName('naujienos_ping').setDescription('Naujienų ping rolė'))
    .addRoleOption((o) => o.setName('atnaujinimai_ping').setDescription('Atnaujinimų ping rolė'))
    .addRoleOption((o) => o.setName('eventai_ping').setDescription('Eventų ping rolė'))
    .addRoleOption((o) => o.setName('policija').setDescription('Policijos permission rolė'))
    .addRoleOption((o) => o.setName('medikai').setDescription('Medikų permission rolė'))
    .addRoleOption((o) => o.setName('mechanikai').setDescription('Mechanikų permission rolė'))
    .addRoleOption((o) => o.setName('taxi').setDescription('Taxi permission rolė')),

  async execute(interaction) {
    if (!isAdmin(interaction.member)) {
      return interaction.reply({ content: 'Tik serverio savininkas / Administrator.', ephemeral: true });
    }

    await interaction.deferReply({ ephemeral: true });

    const civil = interaction.options.getRole('civilis');
    const news = interaction.options.getRole('naujienos_ping');
    const updates = interaction.options.getRole('atnaujinimai_ping');
    const events = interaction.options.getRole('eventai_ping');
    const police = interaction.options.getRole('policija');
    const ems = interaction.options.getRole('medikai');
    const mechanic = interaction.options.getRole('mechanikai');
    const taxi = interaction.options.getRole('taxi');

    const scan = await scanGuild(interaction.guild);

    const session = {
      civilRoleId: civil?.id || scan.civilRole?.id || serverConfig.civilRoleId || null,
      newsPingRoleId: news?.id || serverConfig.newsPingRoleId || null,
      updatesPingRoleId: updates?.id || serverConfig.updatesPingRoleId || null,
      eventsPingRoleId: events?.id || serverConfig.eventsPingRoleId || null,
      factionRoles: {
        police: police?.id || scan.factionRoles.police?.id || serverConfig.policeRoleId || null,
        ems: ems?.id || scan.factionRoles.ems?.id || serverConfig.emsRoleId || null,
        mechanic: mechanic?.id || scan.factionRoles.mechanic?.id || serverConfig.mechanicRoleId || null,
        taxi: taxi?.id || scan.factionRoles.taxi?.id || serverConfig.taxiRoleId || null,
      },
      adminRoleIds: serverConfig.adminRoleIds?.length
        ? [...serverConfig.adminRoleIds]
        : scan.plan.adminCandidates.slice(0, 5).map((r) => r.id),
      scanSummary: {
        createCategories: scan.plan.createCategories.length,
        createChannels: scan.plan.createChannels.length,
        reuseChannels: scan.plan.reuseChannels.length,
        logs: scan.plan.skipLogs.length,
      },
    };

    setSetupSession(interaction.guildId, interaction.user.id, session);

    const components = [];
    if (scan.plan.adminCandidates.length) {
      components.push(
        new ActionRowBuilder().addComponents(
          new StringSelectMenuBuilder()
            .setCustomId(SETUP_ADMIN_SELECT_ID)
            .setPlaceholder('Pasirink administracijos roles…')
            .setMinValues(1)
            .setMaxValues(Math.min(10, scan.plan.adminCandidates.length))
            .addOptions(
              scan.plan.adminCandidates.slice(0, 25).map((r) => ({
                label: r.name.slice(0, 100),
                value: r.id,
                description: `ID ${r.id}`.slice(0, 100),
              })),
            ),
        ),
      );
    }

    components.push(
      new ActionRowBuilder().addComponents(
        new ButtonBuilder().setCustomId(SETUP_CONFIRM_ID).setLabel('Patvirtinti').setStyle(ButtonStyle.Success),
        new ButtonBuilder().setCustomId(SETUP_CANCEL_ID).setLabel('Atšaukti').setStyle(ButtonStyle.Secondary),
      ),
    );

    await interaction.editReply({
      embeds: [
        modernEmbed(
          '⚠️ Pilnas serverio rebuild',
          buildPreviewText(scan, session.adminRoleIds)
            + `\n\n**Civilis:** ${session.civilRoleId ? `<@&${session.civilRoleId}>` : '_bus sukurta_'}`
            + `\n**Frakcijos:** PD ${session.factionRoles.police ? '✓' : '—'} · EMS ${session.factionRoles.ems ? '✓' : '—'} · Mech ${session.factionRoles.mechanic ? '✓' : '—'} · Taxi ${session.factionRoles.taxi ? '✓' : '—'}`
            + '\n\nSpausk **Patvirtinti** — senas kanalai į archyvą, nauja struktūra sukuriama automatiškai.',
        ),
      ],
      components,
    });
  },
};

export async function handleSetupInteraction(interaction) {
  const id = interaction.customId;
  if (![SETUP_CONFIRM_ID, SETUP_CANCEL_ID, SETUP_ADMIN_SELECT_ID].includes(id)) return false;

  if (!isAdmin(interaction.member)) {
    await interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    return true;
  }

  const session = getSetupSession(interaction.guildId, interaction.user.id);
  if (!session) {
    await interaction.reply({
      content: 'Sesija pasibaigė. Paleisk `/setup-server` iš naujo.',
      ephemeral: true,
    });
    return true;
  }

  if (id === SETUP_ADMIN_SELECT_ID) {
    session.adminRoleIds = [...interaction.values];
    setSetupSession(interaction.guildId, interaction.user.id, session);
    await interaction.reply({
      content: `Administracijos rolės: ${session.adminRoleIds.map((rid) => `<@&${rid}>`).join(', ')}`,
      ephemeral: true,
    });
    return true;
  }

  if (id === SETUP_CANCEL_ID) {
    clearSetupSession(interaction.guildId, interaction.user.id);
    await interaction.update({
      content: 'Setup atšauktas. Nieko nekeista.',
      embeds: [],
      components: [],
    });
    return true;
  }

  if (id === SETUP_CONFIRM_ID) {
    await interaction.update({
      content: 'Vykdoma pilnas rebuild (~3–6 min, lėtai kad neužšaltų PC)…\n1) Backup → 2) Senas kanalai į archyvą → 3) Nauja struktūra.\n**Neuždarinėk Discord / kompo.** Logų neliečiu.',
      embeds: [],
      components: [],
    });

    // Anti-nuke: whitelist bot during mass create
    addWhitelist(interaction.guildId, interaction.client.user.id, 'bot', interaction.user.id, 'setup-server');

    mergeServerConfig({
      civilRoleId: session.civilRoleId,
      newsPingRoleId: session.newsPingRoleId,
      updatesPingRoleId: session.updatesPingRoleId,
      eventsPingRoleId: session.eventsPingRoleId,
      adminRoleIds: session.adminRoleIds,
      policeRoleId: session.factionRoles?.police,
      emsRoleId: session.factionRoles?.ems,
      mechanicRoleId: session.factionRoles?.mechanic,
      taxiRoleId: session.factionRoles?.taxi,
    });

    const report = await applyServerSetup(interaction.guild, {
      civilRoleId: session.civilRoleId,
      adminRoleIds: session.adminRoleIds,
      newsPingRoleId: session.newsPingRoleId,
      updatesPingRoleId: session.updatesPingRoleId,
      eventsPingRoleId: session.eventsPingRoleId,
      factionRoles: session.factionRoles,
    });

    if (report.civilRoleId) {
      mergeServerConfig({
        civilRoleId: report.civilRoleId,
        newsPingRoleId: session.newsPingRoleId,
        updatesPingRoleId: session.updatesPingRoleId,
        eventsPingRoleId: session.eventsPingRoleId,
      });
    }

    clearSetupSession(interaction.guildId, interaction.user.id);

    await interaction.followUp({
      embeds: [modernEmbed('Setup baigtas', formatReport(report))],
      ephemeral: true,
    });
    return true;
  }

  return false;
}
