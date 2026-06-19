import {
  SlashCommandBuilder,
  PermissionFlagsBits,
  ChannelType,
} from 'discord.js';
import { getVerificationSettings, setVerificationSettings } from '../database/sqlite.js';
import { isAdmin } from '../utils/permissions.js';
import {
  VERIFY_EMOJI_MEMBER,
  VERIFY_EMOJI_PING,
  applyGuestChannelPermissions,
  assertBotCanManageRoles,
  buildVerificationEmbed,
  findChannelBySlug,
} from '../verification/helpers.js';

async function resolveTextChannelAsync(guild, provided, fallbackSlug) {
  if (provided) return provided;
  return findChannelBySlug(guild, fallbackSlug);
}

export default {
  data: new SlashCommandBuilder()
    .setName('setupverify')
    .setDescription('Pasitvirtinimo sistema — oro-uostas + ✅ / 🔔 rolės')
    .setDMPermission(false)
    .setDefaultMemberPermissions(PermissionFlagsBits.Administrator)
    .addSubcommand((sc) => sc
      .setName('config')
      .setDescription('Išsaugo roles ir kanalus (oro-uostas + pasitvirtinimas)')
      .addRoleOption((o) => o.setName('verified_role').setDescription('Rolė po ✅ (mato visą serverį)').setRequired(true))
      .addRoleOption((o) => o.setName('ping_role').setDescription('Rolė po 🔔 (ping pranešimai)').setRequired(true))
      .addRoleOption((o) => o.setName('unverified_role').setDescription('Rolė naujiems nariams (nebūtina)'))
      .addChannelOption((o) => o
        .setName('welcome_channel')
        .setDescription('oro-uostas kanalas')
        .addChannelTypes(ChannelType.GuildText, ChannelType.GuildAnnouncement))
      .addChannelOption((o) => o
        .setName('verification_channel')
        .setDescription('Pasitvirtinimas kanalas')
        .addChannelTypes(ChannelType.GuildText, ChannelType.GuildAnnouncement))
      .addChannelOption((o) => o
        .setName('rules_channel')
        .setDescription('Taisyklių kanalas (embed nuoroda)')
        .addChannelTypes(ChannelType.GuildText, ChannelType.GuildAnnouncement)))
    .addSubcommand((sc) => sc
      .setName('permissions')
      .setDescription('Nauji nariai mato tik oro-uostas + pasitvirtinimas'))
    .addSubcommand((sc) => sc
      .setName('post')
      .setDescription('Paskelbia pasitvirtinimo žinutę su ✅ ir 🔔'))
    .addSubcommand((sc) => sc
      .setName('status')
      .setDescription('Rodo dabartinę pasitvirtinimo konfigūraciją')),

  async execute(interaction) {
    if (!isAdmin(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const sub = interaction.options.getSubcommand();

    if (sub === 'status') {
      const cfg = getVerificationSettings(interaction.guildId);
      if (!cfg?.enabled) {
        return interaction.reply({ content: 'Pasitvirtinimas dar nesukonfigūruotas. Naudok `/setupverify config`.', ephemeral: true });
      }
      const lines = [
        '**Pasitvirtinimo būsena**',
        `Verified rolė: <@&${cfg.verifiedRoleId}>`,
        `Ping rolė: <@&${cfg.pingRoleId}>`,
        cfg.unverifiedRoleId ? `Unverified rolė: <@&${cfg.unverifiedRoleId}>` : 'Unverified rolė: —',
        `oro-uostas: <#${cfg.welcomeChannelId}>`,
        `Pasitvirtinimas: <#${cfg.verificationChannelId}>`,
        cfg.rulesChannelId ? `Taisyklės: <#${cfg.rulesChannelId}>` : 'Taisyklės: auto (taisykles)',
        cfg.verificationMessageId ? `Žinutė: \`${cfg.verificationMessageId}\`` : 'Žinutė: dar nepaskelbta (`/setupverify post`)',
      ];
      return interaction.reply({ content: lines.join('\n'), ephemeral: true });
    }

    if (sub === 'config') {
      const verifiedRole = interaction.options.getRole('verified_role', true);
      const pingRole = interaction.options.getRole('ping_role', true);
      const unverifiedRole = interaction.options.getRole('unverified_role');
      const welcomeChannel = await resolveTextChannelAsync(
        interaction.guild,
        interaction.options.getChannel('welcome_channel'),
        'oro-uostas',
      );
      const verificationChannel = await resolveTextChannelAsync(
        interaction.guild,
        interaction.options.getChannel('verification_channel'),
        'pasitvirtinimas',
      );
      const rulesChannel = await resolveTextChannelAsync(
        interaction.guild,
        interaction.options.getChannel('rules_channel'),
        'taisykles',
      );

      if (!welcomeChannel) {
        return interaction.reply({ content: 'Nerastas **oro-uostas** kanalas. Pasirink jį ranka arba pervadink kanalą.', ephemeral: true });
      }
      if (!verificationChannel) {
        return interaction.reply({ content: 'Nerastas **pasitvirtinimas** kanalas.', ephemeral: true });
      }

      try {
        await assertBotCanManageRoles(interaction.guild, [
          verifiedRole.id,
          pingRole.id,
          unverifiedRole?.id,
        ]);
      } catch (err) {
        return interaction.reply({ content: err.message, ephemeral: true });
      }

      const existing = getVerificationSettings(interaction.guildId) || {};
      const verification = {
        enabled: true,
        verifiedRoleId: verifiedRole.id,
        pingRoleId: pingRole.id,
        unverifiedRoleId: unverifiedRole?.id || null,
        welcomeChannelId: welcomeChannel.id,
        verificationChannelId: verificationChannel.id,
        rulesChannelId: rulesChannel?.id || null,
        welcomeTitle: existing.welcomeTitle || 'MRP',
        visibleChannelIds: [welcomeChannel.id, verificationChannel.id],
        verificationMessageId: existing.verificationMessageId || null,
        memberEmoji: VERIFY_EMOJI_MEMBER,
        pingEmoji: VERIFY_EMOJI_PING,
      };
      setVerificationSettings(interaction.guildId, verification);

      return interaction.reply({
        content: [
          '**Pasitvirtinimas išsaugotas.**',
          `✅ → ${verifiedRole}`,
          `🔔 → ${pingRole}`,
          `oro-uostas → ${welcomeChannel}`,
          `Pasitvirtinimas → ${verificationChannel}`,
          '',
          '1. `/setupverify permissions`',
          '2. `/setupverify post`',
        ].join('\n'),
        ephemeral: true,
      });
    }

    await interaction.deferReply({ ephemeral: true });

    const verification = getVerificationSettings(interaction.guildId);
    if (!verification?.enabled) {
      return interaction.editReply('Pirmiausia `/setupverify config` su verified ir ping rolėmis.');
    }

    if (sub === 'permissions') {
      try {
        const changed = await applyGuestChannelPermissions(interaction.guild, verification);
        await interaction.editReply(`Kanalų teisės pritaikytos (**${changed}** overwrite). Nauji nariai mato tik oro-uostas + pasitvirtinimas.`);
      } catch (err) {
        console.error('[setupverify] permissions:', err);
        await interaction.editReply(`Klaida: ${err.message}`);
      }
      return;
    }

    if (sub === 'post') {
      const channel = interaction.guild.channels.cache.get(verification.verificationChannelId);
      if (!channel?.isTextBased?.()) {
        return interaction.editReply('Pasitvirtinimo kanalas nerastas. Paleisk `/setupverify config` iš naujo.');
      }

      try {
        const embed = buildVerificationEmbed(interaction.guild);
        const message = await channel.send({ embeds: [embed] });
        await message.react(VERIFY_EMOJI_MEMBER);
        await message.react(VERIFY_EMOJI_PING);

        setVerificationSettings(interaction.guildId, {
          ...verification,
          verificationMessageId: message.id,
        });

        await interaction.editReply(`Pasitvirtinimo žinutė paskelbta: ${message.url}`);
      } catch (err) {
        console.error('[setupverify] post:', err);
        await interaction.editReply(`Nepavyko paskelbti: ${err.message}`);
      }
    }
  },
};
