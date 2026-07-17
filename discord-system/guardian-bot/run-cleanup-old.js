/**
 * Ištrina VISUS senus Discord kanalus.
 * Palieka: logus, stats, naują /setup-server struktūrą.
 * Atkuria 🎭・pasirink-roles jei trūksta.
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
  getAllLogChannels,
  upsertGuildSettings,
  getGuildSettings,
  addWhitelist,
} from './src/database/sqlite.js';
import { isProtectedChannel } from './src/server/apply.js';
import { applyCivilGatePermissions } from './src/server/apply.js';
import { postRolePicker } from './src/roles/picker.js';
import { SERVER_LAYOUT } from './src/server/layout.js';
import { serverConfig } from './src/server/config.js';

assertEnv();
getDb();

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const GUILD_ID = env.guildId || '1515783639890137198';

const client = new Client({ intents: [GatewayIntentBits.Guilds] });

client.once('ready', async () => {
  console.log(`[cleanup] Prisijungta kaip ${client.user.tag}`);
  const guild = await client.guilds.fetch(GUILD_ID);
  await guild.channels.fetch();

  const setup = getServerSetup(guild.id);
  if (!setup?.categoryMap || !setup?.channelMap) {
    console.error('[cleanup] Nėra server_setup — paleisk /setup-server pirmiau.');
    process.exit(1);
  }

  const prevAn = getGuildSettings(guild.id)?.antinuke_enabled;
  upsertGuildSettings(guild.id, { antinuke_enabled: false });
  addWhitelist(guild.id, client.user.id, 'bot', client.user.id, 'cleanup-old');

  const knownLogs = new Set(getAllLogChannels(guild.id).map((r) => r.channel_id));
  const keep = new Set();

  for (const [key, id] of Object.entries(setup.categoryMap || {})) {
    if (key === 'archive') continue; // archyvą trinam
    if (id) keep.add(String(id));
  }
  for (const id of Object.values(setup.channelMap || {})) {
    if (id) keep.add(String(id));
  }
  // ticket panel channel = offtopic — jau channelMap
  if (setup.ticketPanelChannelId) keep.add(String(setup.ticketPanelChannelId));

  // log channel IDs + jų parent kategorijos
  for (const id of knownLogs) {
    keep.add(String(id));
    const ch = guild.channels.cache.get(id);
    if (ch?.parentId) keep.add(String(ch.parentId));
  }

  const statsId = process.env.DISCORD_STATS_CHANNEL_ID;
  if (statsId) {
    keep.add(String(statsId));
    const sch = guild.channels.cache.get(statsId);
    if (sch?.parentId) keep.add(String(sch.parentId));
  }

  // apsaugoti log/stats pagal vardą
  for (const ch of guild.channels.cache.values()) {
    if (isProtectedChannel(ch, knownLogs)) {
      keep.add(ch.id);
      if (ch.parentId) keep.add(ch.parentId);
    }
  }

  console.log(`[cleanup] Saugom ${keep.size} kanalų/kat. ID`);

  const deleted = [];
  const errors = [];

  // Pirma — ne-kategorijos
  const nonCats = [...guild.channels.cache.values()]
    .filter((c) => c.type !== ChannelType.GuildCategory)
    .sort((a, b) => (b.rawPosition ?? 0) - (a.rawPosition ?? 0));

  for (const ch of nonCats) {
    if (keep.has(ch.id)) continue;
    if (isProtectedChannel(ch, knownLogs)) continue;
    try {
      await ch.delete('MRP cleanup — senas kanalas');
      deleted.push(ch.name);
      console.log(`[cleanup] ištrinta #${ch.name}`);
      await sleep(700);
    } catch (err) {
      errors.push(`#${ch.name}: ${err.message}`);
      console.warn(`[cleanup] fail #${ch.name}:`, err.message);
      await sleep(1000);
    }
  }

  await guild.channels.fetch().catch(() => null);

  // Tada — tuščios / senos kategorijos (įskaitant archyvą)
  const cats = [...guild.channels.cache.values()]
    .filter((c) => c.type === ChannelType.GuildCategory);

  for (const cat of cats) {
    if (keep.has(cat.id)) continue;
    if (isProtectedChannel(cat, knownLogs)) continue;
    const kids = guild.channels.cache.filter((c) => c.parentId === cat.id);
    // jei dar yra saugomų vaikų — neliečiam
    const hasKeepKid = [...kids.keys()].some((id) => keep.has(id));
    if (hasKeepKid) continue;

    // ištrink likusius vaikus
    for (const kid of kids.values()) {
      if (keep.has(kid.id) || isProtectedChannel(kid, knownLogs)) continue;
      try {
        await kid.delete('MRP cleanup');
        deleted.push(kid.name);
        console.log(`[cleanup] ištrinta #${kid.name}`);
        await sleep(700);
      } catch (err) {
        errors.push(`#${kid.name}: ${err.message}`);
      }
    }

    try {
      await cat.delete('MRP cleanup — sena kategorija');
      deleted.push(cat.name);
      console.log(`[cleanup] ištrinta kat. ${cat.name}`);
      await sleep(700);
    } catch (err) {
      errors.push(`kat ${cat.name}: ${err.message}`);
    }
  }

  // Atnaujinti setup — archive išimti
  const { archive, ...catsKeep } = setup.categoryMap || {};
  setServerSetup(guild.id, {
    ...setup,
    categoryMap: catsKeep,
    cleanedAt: new Date().toISOString(),
  });

  // Atkurti roles kanalą jei trūksta
  await guild.channels.fetch().catch(() => null);
  let rolesCh = guild.channels.cache.get(setup.channelMap?.roles);
  const startCat = guild.channels.cache.get(setup.categoryMap?.start);

  if (!rolesCh && startCat) {
    const rolesDef = SERVER_LAYOUT.categories.start.channels.find((c) => c.key === 'roles');
    console.log('[cleanup] Kuriam iš naujo 🎭・pasirink-roles…');
    rolesCh = await guild.channels.create({
      name: rolesDef?.name || '🎭・pasirink-roles',
      type: ChannelType.GuildText,
      parent: startCat.id,
      permissionOverwrites: [
        {
          id: guild.roles.everyone.id,
          allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.ReadMessageHistory],
          deny: [PermissionFlagsBits.SendMessages, PermissionFlagsBits.CreatePublicThreads],
        },
      ],
      reason: 'MRP cleanup — atkurtas roles kanalas',
    });
    setServerSetup(guild.id, {
      channelMap: { ...(getServerSetup(guild.id)?.channelMap || {}), roles: rolesCh.id },
    });
    await sleep(500);
  }

  if (rolesCh) {
    const s = getServerSetup(guild.id) || setup;
    await postRolePicker(rolesCh, {
      civilRoleId: s.civilRoleId || serverConfig.civilRoleId,
      newsPingRoleId: s.newsPingRoleId || serverConfig.newsPingRoleId,
      updatesPingRoleId: s.updatesPingRoleId || serverConfig.updatesPingRoleId,
      eventsPingRoleId: s.eventsPingRoleId || serverConfig.eventsPingRoleId,
    });
    console.log('[cleanup] Role picker atkurtas');
  }

  await applyCivilGatePermissions(guild, {
    civilRoleId: setup.civilRoleId,
    adminRoleIds: setup.adminRoleIds,
  });
  console.log('[cleanup] Civilis gate pritaikytas');

  upsertGuildSettings(guild.id, { antinuke_enabled: prevAn !== false });

  console.log(`\n[cleanup] BAIGTA. Ištrinta: ${deleted.length}`);
  if (errors.length) console.log('Klaidos:\n- ' + errors.join('\n- '));
  process.exit(0);
});

client.login(env.token);
