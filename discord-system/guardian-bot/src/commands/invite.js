import {
  SlashCommandBuilder,
  PermissionFlagsBits,
  ChannelType,
  EmbedBuilder,
} from 'discord.js';
import { isAdmin } from '../utils/permissions.js';
import {
  ensureGuildInvite,
  getInviteStatus,
} from '../invite/manager.js';

export default {
  data: new SlashCommandBuilder()
    .setName('invite')
    .setDescription('Permanent Discord invite (txAdmin allowlist / serverio nuoroda)')
    .setDMPermission(false)
    .setDefaultMemberPermissions(PermissionFlagsBits.Administrator)
    .addSubcommand((sc) => sc
      .setName('setup')
      .setDescription('Sukuria permanent invite pasirinktame kanale')
      .addChannelOption((o) => o
        .setName('channel')
        .setDescription('Kanalas invite’ui (pvz. oro-uostas)')
        .addChannelTypes(ChannelType.GuildText, ChannelType.GuildAnnouncement)
        .setRequired(true)))
    .addSubcommand((sc) => sc
      .setName('status')
      .setDescription('Rodo dabartinį permanent invite'))
    .addSubcommand((sc) => sc
      .setName('refresh')
      .setDescription('Priverstinai sukuria naują permanent invite')),

  async execute(interaction) {
    if (!isAdmin(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const sub = interaction.options.getSubcommand();

    if (sub === 'status') {
      const record = getInviteStatus(interaction.guildId);
      if (!record?.url) {
        return interaction.reply({
          content: 'Invite dar nesukonfigūruotas. Naudok `/invite setup`.',
          ephemeral: true,
        });
      }

      const embed = new EmbedBuilder()
        .setTitle('Discord invite')
        .setColor(0x5865f2)
        .setDescription(record.url)
        .addFields(
          { name: 'Kodas', value: `\`${record.code}\``, inline: true },
          { name: 'Kanalas', value: `<#${record.channelId}>`, inline: true },
          {
            name: 'Atnaujinta',
            value: record.updatedAt ? `<t:${Math.floor(new Date(record.updatedAt).getTime() / 1000)}:R>` : '—',
            inline: true,
          },
        )
        .setFooter({ text: 'Nukopijuok į txAdmin allowlist instructions + QBConfig.Server.Discord' });

      return interaction.reply({ embeds: [embed], ephemeral: true });
    }

    await interaction.deferReply({ ephemeral: true });

    try {
      if (sub === 'setup') {
        const channel = interaction.options.getChannel('channel', true);
        const { record, recreated, created } = await ensureGuildInvite(
          interaction.guild,
          channel.id,
          { forceNew: false, notify: false },
        );

        const note = recreated
          ? 'Senas invite nebegaliojo — sukurtas naujas.'
          : created
            ? 'Permanent invite sukurtas.'
            : 'Esamas permanent invite galioja.';

        return interaction.editReply({
          content: [
            `**${note}**`,
            record.url,
            '',
            'Įrašykite šį URL į:',
            '• txAdmin → Allowlist instructions',
            '• `QBConfig.Server.Discord`',
            '',
            'Detaliau: `docs/TXADMIN_DISCORD.md`',
          ].join('\n'),
        });
      }

      if (sub === 'refresh') {
        const existing = getInviteStatus(interaction.guildId);
        if (!existing?.channelId) {
          return interaction.editReply({
            content: 'Pirmiau paleisk `/invite setup` su kanalu.',
          });
        }

        const { record } = await ensureGuildInvite(
          interaction.guild,
          existing.channelId,
          {
            forceNew: true,
            notify: true,
            reason: `MAYHEM RP invite refresh by ${interaction.user.tag}`,
          },
        );

        return interaction.editReply({
          content: [
            '**Naujas permanent invite sukurtas.**',
            record.url,
            '',
            'Atnaujinkite txAdmin rejection text ir `QBConfig.Server.Discord`.',
          ].join('\n'),
        });
      }
    } catch (err) {
      return interaction.editReply({
        content: `Klaida: ${err.message || err}`,
      });
    }

    return interaction.editReply({ content: 'Nežinoma subkomanda.' });
  },
};
