/**
 * Perkelia ticket panelę iš off-topic į 🎫・ticket-chat (TICKETAI).
 */
import 'dotenv/config';
import {
  Client,
  GatewayIntentBits,
  ChannelType,
  PermissionFlagsBits,
} from 'discord.js';
import { assertEnv, env } from './src/config.js';
import {
  getDb,
  getServerSetup,
  setServerSetup,
  upsertGuildSettings,
  getGuildSettings,
  addWhitelist,
} from './src/database/sqlite.js';
import { postTicketPanel } from './src/tickets/panel.js';
import { applyCivilGatePermissions } from './src/server/apply.js';

assertEnv();
getDb();

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const GUILD_ID = env.guildId || '1515783639890137198';

function ticketPanelOverwrites(guild, civilRoleId, adminRoleIds = []) {
  const overs = [
    { id: guild.roles.everyone.id, deny: [PermissionFlagsBits.ViewChannel] },
  ];
  if (civilRoleId) {
    overs.push({
      id: civilRoleId,
      allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.ReadMessageHistory],
      deny: [
        PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.CreatePublicThreads,
        PermissionFlagsBits.CreatePrivateThreads,
      ],
    });
  }
  for (const id of adminRoleIds) {
    overs.push({
      id,
      allow: [
        PermissionFlagsBits.ViewChannel,
        PermissionFlagsBits.ReadMessageHistory,
        PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.ManageMessages,
      ],
    });
  }
  return overs;
}

const client = new Client({ intents: [GatewayIntentBits.Guilds] });

client.once('clientReady', async () => {
  console.log(`[ticket-move] ${client.user.tag}`);
  const guild = await client.guilds.fetch(GUILD_ID);
  await guild.channels.fetch();

  const setup = getServerSetup(guild.id);
  if (!setup?.categoryMap?.tickets) {
    console.error('Nėra tickets kategorijos setup DB');
    process.exit(1);
  }

  const prevAn = getGuildSettings(guild.id)?.antinuke_enabled;
  upsertGuildSettings(guild.id, { antinuke_enabled: false });
  addWhitelist(guild.id, client.user.id, 'bot', client.user.id, 'ticket-move');

  const ticketsCat = guild.channels.cache.get(setup.categoryMap.tickets);
  if (!ticketsCat) {
    console.error('Tickets kategorija nerasta Discord');
    process.exit(1);
  }

  const overs = ticketPanelOverwrites(guild, setup.civilRoleId, setup.adminRoleIds || []);
  await ticketsCat.permissionOverwrites.set(overs).catch(() => null);

  // Ištrinti seną panelę iš off-topic
  const oldChId = setup.ticketPanelChannelId;
  const oldMsgId = setup.ticketPanelMessageId;
  if (oldChId && oldMsgId) {
    const oldCh = guild.channels.cache.get(oldChId);
    if (oldCh?.isTextBased?.()) {
      const msg = await oldCh.messages.fetch(oldMsgId).catch(() => null);
      if (msg) {
        await msg.delete().catch(() => null);
        console.log(`[ticket-move] Ištrinta sena panelė iš #${oldCh.name}`);
      }
      // papildomai — bot ticket embeds off-topic
      const recent = await oldCh.messages.fetch({ limit: 30 }).catch(() => null);
      if (recent) {
        for (const m of recent.values()) {
          if (m.author.id !== client.user.id) continue;
          if (m.embeds?.[0]?.title?.includes('Ticket') || m.components?.length) {
            await m.delete().catch(() => null);
            console.log('[ticket-move] Ištrinta dar viena boto ticket žinutė off-topic');
            await sleep(400);
          }
        }
      }
    }
  }

  let ticketChat = setup.channelMap?.ticket_chat
    ? guild.channels.cache.get(setup.channelMap.ticket_chat)
    : guild.channels.cache.find(
      (c) => c.parentId === ticketsCat.id && /ticket.?chat/i.test(c.name),
    );

  if (!ticketChat) {
    ticketChat = await guild.channels.create({
      name: '🎫・ticket-chat',
      type: ChannelType.GuildText,
      parent: ticketsCat.id,
      permissionOverwrites: overs,
      reason: 'MRP — ticket panelė',
    });
    console.log('[ticket-move] Sukurtas #🎫・ticket-chat');
    await sleep(500);
  } else {
    await ticketChat.permissionOverwrites.set(overs).catch(() => null);
    await ticketChat.setParent(ticketsCat.id).catch(() => null);
  }

  // Nauja panelė (force naują žinutę)
  setServerSetup(guild.id, {
    ...setup,
    ticketPanelChannelId: null,
    ticketPanelMessageId: null,
    channelMap: { ...(setup.channelMap || {}), ticket_chat: ticketChat.id },
  });

  await postTicketPanel(ticketChat, {
    categoryId: ticketsCat.id,
    adminRoleIds: setup.adminRoleIds,
  });
  console.log('[ticket-move] Panelė paskelbta ticket-chat');

  await applyCivilGatePermissions(guild, {
    civilRoleId: setup.civilRoleId,
    adminRoleIds: setup.adminRoleIds,
  });

  upsertGuildSettings(guild.id, { antinuke_enabled: prevAn !== false });
  console.log('[ticket-move] BAIGTA');
  process.exit(0);
});

client.login(env.token);
