import {
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  ChannelType,
  ModalBuilder,
  PermissionFlagsBits,
  TextInputBuilder,
  TextInputStyle,
} from 'discord.js';
import {
  getServerSetup,
  setServerSetup,
  nextTicketNumber,
  upsertTicket,
  countOpenTicketsForUser,
} from '../database/sqlite.js';
import { APPLICATION_TYPES } from '../server/layout.js';
import {
  applicationsPanelEmbed,
  factionInfoEmbed,
  applicationSubmittedEmbed,
} from '../server/embeds.js';
import { serverConfig, factionDiscordUrl } from '../server/config.js';

export const APP_BTN_PREFIX = 'mrp:app:open:';
export const APP_MODAL_PREFIX = 'mrp:app:modal:';
export const APP_CLOSE_ID = 'mrp:app:close';

const openCooldown = new Map();

function appType(id) {
  return APPLICATION_TYPES.find((t) => t.id === id) || null;
}

function staffAppButtons() {
  return new ActionRowBuilder().addComponents(
    new ButtonBuilder()
      .setCustomId(`${APP_BTN_PREFIX}admin`)
      .setLabel('Admin anketa')
      .setEmoji('🛡️')
      .setStyle(ButtonStyle.Primary),
    new ButtonBuilder()
      .setCustomId(`${APP_BTN_PREFIX}faction_leader`)
      .setLabel('Frakcijų vadovas')
      .setEmoji('👑')
      .setStyle(ButtonStyle.Secondary),
  );
}

function factionAppButton(factionId) {
  const t = appType(factionId);
  return new ActionRowBuilder().addComponents(
    new ButtonBuilder()
      .setCustomId(`${APP_BTN_PREFIX}${factionId}`)
      .setLabel(t?.buttonLabel || 'Pildyti anketą')
      .setEmoji(t?.emoji || '📝')
      .setStyle(ButtonStyle.Success),
  );
}

function applicationCloseRow() {
  return new ActionRowBuilder().addComponents(
    new ButtonBuilder()
      .setCustomId(APP_CLOSE_ID)
      .setLabel('Uždaryti anketą')
      .setStyle(ButtonStyle.Danger),
  );
}

export async function postApplicationsPanel(channel, opts = {}) {
  const setup = getServerSetup(channel.guild.id) || {};
  const adminRoleIds = opts.adminRoleIds || setup.adminRoleIds || serverConfig.adminRoleIds || [];

  if (setup.applicationsPanelMessageId && setup.applicationsPanelChannelId === channel.id) {
    const existing = await channel.messages.fetch(setup.applicationsPanelMessageId).catch(() => null);
    if (existing) {
      await existing.edit({
        embeds: [applicationsPanelEmbed()],
        components: [staffAppButtons()],
      }).catch(() => null);
      setServerSetup(channel.guild.id, {
        ...setup,
        applicationsPanelChannelId: channel.id,
        applicationsCategoryId: opts.categoryId || setup.categoryMap?.applications || setup.applicationsCategoryId,
        adminRoleIds,
      });
      return true;
    }
  }

  const message = await channel.send({
    embeds: [applicationsPanelEmbed()],
    components: [staffAppButtons()],
  });

  setServerSetup(channel.guild.id, {
    ...setup,
    applicationsPanelChannelId: channel.id,
    applicationsPanelMessageId: message.id,
    applicationsCategoryId: opts.categoryId || setup.categoryMap?.applications || setup.applicationsCategoryId,
    categoryMap: {
      ...(setup.categoryMap || {}),
      applications: opts.categoryId || setup.categoryMap?.applications,
    },
    adminRoleIds,
  });
  return true;
}

export async function postFactionApplicationPanel(channel, factionKey, opts = {}) {
  const labels = {
    police: 'Policija',
    ems: 'Medikai',
    mechanic: 'Mechanikai',
    taxi: 'Taxi',
  };
  const label = labels[factionKey] || factionKey;
  const setup = getServerSetup(channel.guild.id) || {};
  const mapKey = `factionPanel_${factionKey}`;
  const existingId = setup[mapKey];

  if (existingId) {
    const existing = await channel.messages.fetch(existingId).catch(() => null);
    if (existing) {
      await existing.edit({
        embeds: [factionInfoEmbed(label, factionDiscordUrl(factionKey))],
        components: [factionAppButton(factionKey)],
      }).catch(() => null);
      return true;
    }
  }

  const message = await channel.send({
    embeds: [factionInfoEmbed(label, factionDiscordUrl(factionKey))],
    components: [factionAppButton(factionKey)],
  });

  setServerSetup(channel.guild.id, {
    ...setup,
    [mapKey]: message.id,
    applicationsCategoryId: opts.categoryId || setup.categoryMap?.applications || setup.applicationsCategoryId,
  });
  return true;
}

function buildApplicationModal(type) {
  const modal = new ModalBuilder()
    .setCustomId(`${APP_MODAL_PREFIX}${type.id}`)
    .setTitle(type.label.slice(0, 45));

  modal.addComponents(
    new ActionRowBuilder().addComponents(
      new TextInputBuilder()
        .setCustomId('ic_name')
        .setLabel('IC vardas / pavardė')
        .setStyle(TextInputStyle.Short)
        .setRequired(true)
        .setMaxLength(80),
    ),
    new ActionRowBuilder().addComponents(
      new TextInputBuilder()
        .setCustomId('age')
        .setLabel('Amžius (OOC)')
        .setStyle(TextInputStyle.Short)
        .setRequired(true)
        .setMaxLength(8),
    ),
    new ActionRowBuilder().addComponents(
      new TextInputBuilder()
        .setCustomId('experience')
        .setLabel('Patirtis (RP / ši pozicija)')
        .setStyle(TextInputStyle.Paragraph)
        .setRequired(true)
        .setMaxLength(800),
    ),
    new ActionRowBuilder().addComponents(
      new TextInputBuilder()
        .setCustomId('why')
        .setLabel('Kodėl nori šios pozicijos?')
        .setStyle(TextInputStyle.Paragraph)
        .setRequired(true)
        .setMaxLength(800),
    ),
    new ActionRowBuilder().addComponents(
      new TextInputBuilder()
        .setCustomId('extra')
        .setLabel('Papildoma info (nebūtina)')
        .setStyle(TextInputStyle.Paragraph)
        .setRequired(false)
        .setMaxLength(500),
    ),
  );

  return modal;
}

export async function handleApplicationButton(interaction) {
  if (!interaction.customId?.startsWith(APP_BTN_PREFIX) && interaction.customId !== APP_CLOSE_ID) {
    return false;
  }

  if (interaction.customId === APP_CLOSE_ID) {
    const setup = getServerSetup(interaction.guildId) || {};
    const adminRoleIds = setup.adminRoleIds || serverConfig.adminRoleIds || [];
    const isStaff = interaction.memberPermissions?.has(PermissionFlagsBits.Administrator)
      || adminRoleIds.some((id) => interaction.member.roles.cache.has(id));
    if (!isStaff && interaction.channel?.name && !interaction.channel.name.includes(interaction.user.username.slice(0, 8))) {
      // allow channel owner-ish: ticket creator mentioned in topic
    }
    if (!isStaff) {
      const topic = interaction.channel?.topic || '';
      if (!topic.includes(interaction.user.id)) {
        await interaction.reply({ content: 'Anketą uždaryti gali tik administracija arba pateikėjas.', ephemeral: true });
        return true;
      }
    }
    await interaction.reply({ content: 'Anketa uždaroma…', ephemeral: true });
    await interaction.channel?.delete('MRP application closed').catch(() => null);
    return true;
  }

  const typeId = interaction.customId.slice(APP_BTN_PREFIX.length);
  const type = appType(typeId);
  if (!type) {
    await interaction.reply({ content: 'Nežinoma anketa.', ephemeral: true });
    return true;
  }

  await interaction.showModal(buildApplicationModal(type));
  return true;
}

export async function handleApplicationModal(interaction) {
  if (!interaction.customId?.startsWith(APP_MODAL_PREFIX)) return false;

  const typeId = interaction.customId.slice(APP_MODAL_PREFIX.length);
  const type = appType(typeId);
  if (!type) {
    await interaction.reply({ content: 'Nežinoma anketa.', ephemeral: true });
    return true;
  }

  const key = `${interaction.guildId}:${interaction.user.id}:app`;
  const now = Date.now();
  if (openCooldown.has(key) && now - openCooldown.get(key) < 8000) {
    await interaction.reply({ content: 'Palauk kelias sekundes.', ephemeral: true });
    return true;
  }
  openCooldown.set(key, now);

  const max = serverConfig.maxTicketsPerUser || 2;
  if (countOpenTicketsForUser(interaction.guildId, interaction.user.id) >= max) {
    await interaction.reply({
      content: `Jau turi maksimalų aktyvių ticketų/anketų skaičių (${max}).`,
      ephemeral: true,
    });
    return true;
  }

  await interaction.deferReply({ ephemeral: true });

  const setup = getServerSetup(interaction.guildId) || {};
  const adminRoleIds = setup.adminRoleIds || serverConfig.adminRoleIds || [];
  const parentId = setup.categoryMap?.applications || setup.applicationsCategoryId || setup.categoryMap?.tickets;

  const answers = {
    icName: interaction.fields.getTextInputValue('ic_name'),
    age: interaction.fields.getTextInputValue('age'),
    experience: interaction.fields.getTextInputValue('experience'),
    why: interaction.fields.getTextInputValue('why'),
    extra: interaction.fields.getTextInputValue('extra') || '—',
  };

  const num = nextTicketNumber(interaction.guildId);
  const safeName = interaction.user.username.toLowerCase().replace(/[^a-z0-9]/gi, '').slice(0, 12) || 'user';
  const channelName = `anketa-${type.id}-${safeName}-${num}`.slice(0, 90);

  const overs = [
    { id: interaction.guild.roles.everyone.id, deny: [PermissionFlagsBits.ViewChannel] },
    {
      id: interaction.user.id,
      allow: [
        PermissionFlagsBits.ViewChannel,
        PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.ReadMessageHistory,
        PermissionFlagsBits.AttachFiles,
      ],
    },
    {
      id: interaction.client.user.id,
      allow: [
        PermissionFlagsBits.ViewChannel,
        PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.ManageChannels,
        PermissionFlagsBits.ReadMessageHistory,
      ],
    },
    ...adminRoleIds.map((id) => ({
      id,
      allow: [
        PermissionFlagsBits.ViewChannel,
        PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.ReadMessageHistory,
        PermissionFlagsBits.ManageMessages,
        PermissionFlagsBits.EmbedLinks,
      ],
    })),
  ];

  const channel = await interaction.guild.channels.create({
    name: channelName,
    type: ChannelType.GuildText,
    parent: parentId || undefined,
    topic: `Anketa:${type.id}|user:${interaction.user.id}`,
    permissionOverwrites: overs,
    reason: `MRP application ${type.id}`,
  });

  upsertTicket(interaction.guildId, {
    id: channel.id,
    guildId: interaction.guildId,
    channelId: channel.id,
    userId: interaction.user.id,
    number: num,
    category: `app:${type.id}`,
    categoryLabel: type.label,
    status: 'open',
    createdAt: Date.now(),
  });

  await channel.send({
    content: `${interaction.user} ${adminRoleIds.map((id) => `<@&${id}>`).join(' ')}`.trim(),
    embeds: [applicationSubmittedEmbed(type, interaction.user, answers)],
    components: [applicationCloseRow()],
  });

  await interaction.editReply({
    content: `Anketa pateikta: ${channel}`,
  });
  return true;
}
