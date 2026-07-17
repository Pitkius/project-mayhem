import {
  ActionRowBuilder,
  StringSelectMenuBuilder,
  ButtonBuilder,
  ButtonStyle,
  ChannelType,
  PermissionFlagsBits,
} from 'discord.js';
import {
  nextTicketNumber,
  upsertTicket,
  deleteTicket,
  countOpenTicketsForUser,
  listTickets,
  getServerSetup,
  setServerSetup,
} from '../database/sqlite.js';
import { TICKET_CATEGORIES } from '../server/layout.js';
import { ticketPanelEmbed, modernEmbed } from '../server/embeds.js';
import { serverConfig } from '../server/config.js';
import { isAdmin } from '../utils/permissions.js';

export const TICKET_OPEN_ID = 'mrp:ticket:open';
export const TICKET_CLAIM_ID = 'mrp:ticket:claim';
export const TICKET_CLOSE_ID = 'mrp:ticket:close';
export const TICKET_CLOSE_CONFIRM_ID = 'mrp:ticket:closeconfirm';
export const TICKET_CLOSE_CANCEL_ID = 'mrp:ticket:closecancel';
export const TICKET_DELETE_ID = 'mrp:ticket:delete';

const openCooldown = new Map();

function ticketSelectRow() {
  return new ActionRowBuilder().addComponents(
    new StringSelectMenuBuilder()
      .setCustomId(TICKET_OPEN_ID)
      .setPlaceholder('Pasirink ticket kategoriją…')
      .addOptions(
        TICKET_CATEGORIES.map((c) => ({
          label: c.label.slice(0, 100),
          value: c.id,
          emoji: c.emoji,
        })),
      ),
  );
}

function ticketControlRow() {
  return new ActionRowBuilder().addComponents(
    new ButtonBuilder().setCustomId(TICKET_CLAIM_ID).setLabel('Perimti').setStyle(ButtonStyle.Primary),
    new ButtonBuilder().setCustomId(TICKET_CLOSE_ID).setLabel('Uždaryti').setStyle(ButtonStyle.Secondary),
  );
}

function closeConfirmRow() {
  return new ActionRowBuilder().addComponents(
    new ButtonBuilder().setCustomId(TICKET_CLOSE_CONFIRM_ID).setLabel('Taip, uždaryti').setStyle(ButtonStyle.Danger),
    new ButtonBuilder().setCustomId(TICKET_CLOSE_CANCEL_ID).setLabel('Atšaukti').setStyle(ButtonStyle.Secondary),
  );
}

export async function postTicketPanel(channel, opts = {}) {
  const setup = getServerSetup(channel.guild.id) || {};
  const categoryId = opts.categoryId || setup.categoryMap?.tickets;
  const adminRoleIds = opts.adminRoleIds || setup.adminRoleIds || serverConfig.adminRoleIds || [];

  if (setup.ticketPanelMessageId && setup.ticketPanelChannelId === channel.id) {
    const existing = await channel.messages.fetch(setup.ticketPanelMessageId).catch(() => null);
    if (existing) {
      await existing.edit({
        embeds: [ticketPanelEmbed()],
        components: [ticketSelectRow()],
      }).catch(() => null);
      return true;
    }
  }

  const message = await channel.send({
    embeds: [ticketPanelEmbed()],
    components: [ticketSelectRow()],
  });

  setServerSetup(channel.guild.id, {
    ...setup,
    ticketPanelChannelId: channel.id,
    ticketPanelMessageId: message.id,
    categoryMap: { ...(setup.categoryMap || {}), tickets: categoryId },
    adminRoleIds,
  });
  return true;
}

function findTicketByChannel(guildId, channelId) {
  return listTickets(guildId).find((t) => t.channelId === channelId) || null;
}

export async function handleTicketSelect(interaction) {
  if (interaction.customId !== TICKET_OPEN_ID) return false;

  const catId = interaction.values?.[0];
  const cat = TICKET_CATEGORIES.find((c) => c.id === catId);
  if (!cat) {
    await interaction.reply({ content: 'Nežinoma kategorija.', ephemeral: true });
    return true;
  }

  const key = `${interaction.guildId}:${interaction.user.id}`;
  const now = Date.now();
  if (openCooldown.has(key) && now - openCooldown.get(key) < 5000) {
    await interaction.reply({ content: 'Palauk kelias sekundes.', ephemeral: true });
    return true;
  }
  openCooldown.set(key, now);

  const max = serverConfig.maxTicketsPerUser || 2;
  if (countOpenTicketsForUser(interaction.guildId, interaction.user.id) >= max) {
    await interaction.reply({
      content: `Jau turi maksimalų aktyvių ticketų skaičių (${max}).`,
      ephemeral: true,
    });
    return true;
  }

  await interaction.deferReply({ ephemeral: true });

  const setup = getServerSetup(interaction.guildId) || {};
  const parentId = setup.categoryMap?.tickets;
  const adminRoleIds = setup.adminRoleIds || serverConfig.adminRoleIds || [];
  const num = nextTicketNumber(interaction.guildId);
  const ticketId = `T-${String(num).padStart(4, '0')}`;

  const overwrites = [
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
      ],
    })),
  ];

  let channel;
  try {
    const safeName = `ticket-${num}-${interaction.user.username}`
      .slice(0, 90)
      .toLowerCase()
      .replace(/[^a-z0-9\-]/g, '-');
    channel = await interaction.guild.channels.create({
      name: safeName,
      type: ChannelType.GuildText,
      parent: parentId || undefined,
      permissionOverwrites: overwrites,
      topic: `${ticketId} · ${cat.label} · ${interaction.user.id}`,
      reason: `Ticket ${ticketId}`,
    });
  } catch (err) {
    await interaction.editReply(`Nepavyko sukurti ticket: ${err.message}`);
    return true;
  }

  upsertTicket(interaction.guildId, {
    id: ticketId,
    number: num,
    guildId: interaction.guildId,
    channelId: channel.id,
    userId: interaction.user.id,
    category: cat.id,
    categoryLabel: cat.label,
    status: 'open',
    claimedBy: null,
    createdAt: new Date().toISOString(),
  });

  await channel.send({
    content: `${interaction.user} ${adminRoleIds.map((id) => `<@&${id}>`).join(' ')}`.trim(),
    embeds: [
      modernEmbed(
        `${ticketId} · ${cat.label}`,
        [
          `**Autorius:** ${interaction.user} (\`${interaction.user.id}\`)`,
          `**Kategorija:** ${cat.label}`,
          '',
          'Aprašyk problemą kuo aiškiau. Administratorius netrukus atsakys.',
        ].join('\n'),
      ),
    ],
    components: [ticketControlRow()],
  });

  await interaction.editReply(`Ticket sukurtas: ${channel}`);
  return true;
}

async function buildTranscript(channel) {
  const messages = await channel.messages.fetch({ limit: 100 }).catch(() => null);
  if (!messages) return 'Transcript nepavyko.';
  const lines = [...messages.values()]
    .reverse()
    .map((m) => {
      const time = m.createdAt.toISOString();
      const content = m.content || (m.embeds?.[0]?.title ? `[embed] ${m.embeds[0].title}` : '[be teksto]');
      return `[${time}] ${m.author.tag}: ${content}`;
    });
  return lines.join('\n').slice(0, 1800) || 'Tuščia.';
}

export async function handleTicketButton(interaction) {
  const id = interaction.customId;
  if (![TICKET_CLAIM_ID, TICKET_CLOSE_ID, TICKET_CLOSE_CONFIRM_ID, TICKET_CLOSE_CANCEL_ID, TICKET_DELETE_ID].includes(id)) {
    return false;
  }

  const ticket = findTicketByChannel(interaction.guildId, interaction.channelId);
  if (!ticket) {
    await interaction.reply({ content: 'Šis kanalas nėra aktyvus ticket.', ephemeral: true });
    return true;
  }

  const setup = getServerSetup(interaction.guildId) || {};
  const adminRoleIds = new Set(setup.adminRoleIds || serverConfig.adminRoleIds || []);
  const isStaff = isAdmin(interaction.member)
    || [...interaction.member.roles.cache.keys()].some((rid) => adminRoleIds.has(rid));

  if (id === TICKET_CLAIM_ID) {
    if (!isStaff) {
      await interaction.reply({ content: 'Tik administracija gali perimti.', ephemeral: true });
      return true;
    }
    ticket.claimedBy = interaction.user.id;
    upsertTicket(interaction.guildId, ticket);
    await interaction.reply({ content: `${interaction.user} perėmė ticket **${ticket.id}**.` });
    return true;
  }

  if (id === TICKET_CLOSE_ID) {
    if (!isStaff && interaction.user.id !== ticket.userId) {
      await interaction.reply({ content: 'Neturi teisės uždaryti.', ephemeral: true });
      return true;
    }
    await interaction.reply({
      content: 'Uždaryti ticket?',
      ephemeral: true,
      components: [closeConfirmRow()],
    });
    return true;
  }

  if (id === TICKET_CLOSE_CANCEL_ID) {
    await interaction.update({ content: 'Uždarymas atšauktas.', components: [] });
    return true;
  }

  if (id === TICKET_CLOSE_CONFIRM_ID) {
    if (!isStaff && interaction.user.id !== ticket.userId) {
      await interaction.reply({ content: 'Neturi teisės.', ephemeral: true });
      return true;
    }
    await interaction.update({ content: 'Uždaroma…', components: [] });
    const transcript = await buildTranscript(interaction.channel);
    ticket.status = 'closed';
    ticket.closedAt = new Date().toISOString();
    ticket.closedBy = interaction.user.id;
    upsertTicket(interaction.guildId, ticket);

    await interaction.channel.send({
      embeds: [
        modernEmbed(
          `${ticket.id} uždarytas`,
          [
            `Uždarė: ${interaction.user}`,
            '',
            '**Trumpas transcript (paskutinės žinutės):**',
            `\`\`\`\n${transcript}\n\`\`\``,
          ].join('\n'),
        ),
      ],
      components: [
        new ActionRowBuilder().addComponents(
          new ButtonBuilder()
            .setCustomId(TICKET_DELETE_ID)
            .setLabel('Ištrinti kanalą')
            .setStyle(ButtonStyle.Danger),
        ),
      ],
    });
    return true;
  }

  if (id === TICKET_DELETE_ID) {
    if (!isStaff) {
      await interaction.reply({ content: 'Tik administracija gali ištrinti.', ephemeral: true });
      return true;
    }
    await interaction.reply({ content: 'Kanalas bus ištrintas po 3 s…', ephemeral: true });
    deleteTicket(interaction.guildId, ticket.id);
    setTimeout(() => {
      interaction.channel.delete('Ticket deleted').catch(() => null);
    }, 3000);
    return true;
  }

  return false;
}
