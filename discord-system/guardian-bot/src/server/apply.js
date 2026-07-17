import {
  ChannelType,
  PermissionFlagsBits,
} from 'discord.js';
import { getAllLogChannels, setServerSetup, getServerSetup } from '../database/sqlite.js';
import { normalizeChannelName } from '../verification/helpers.js';
import { LOG_LAYOUT } from '../logs/channelLayout.js';
import { SERVER_LAYOUT, RULE_PLACEHOLDERS } from './layout.js';
import { serverConfig, factionRoleId, factionDiscordUrl } from './config.js';
import { createGuildBackup } from './backup.js';
import { modernEmbed, rulesEmbed, factionInfoEmbed } from './embeds.js';
import { postRolePicker } from '../roles/picker.js';
import { postTicketPanel } from '../tickets/panel.js';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function isLogCategoryName(name = '') {
  if (LOG_LAYOUT?.anchorMatch?.test(name)) return true;
  if (/admin[\s_-]?logai/i.test(name)) return true;
  if (/discord\s*[·•|-]/i.test(name) && /(saugum|žinut|nariai|serveris|log)/i.test(name)) return true;
  if (/fivem\s*[·•|-]/i.test(name)) return true;
  return false;
}

/** Logai + stats kanalas — niekada nejudinam / netrinam. */
export function isProtectedChannel(channel, knownLogIds = new Set()) {
  if (!channel) return false;
  if (knownLogIds.has(channel.id)) return true;

  const statsId = process.env.DISCORD_STATS_CHANNEL_ID;
  if (statsId && channel.id === statsId) return true;

  const name = channel.name || '';
  const n = normalizeChannelName(name);
  if (n.includes('log')) return true;
  if (isLogCategoryName(name)) return true;

  if (channel.parent) {
    if (knownLogIds.has(channel.parent.id)) return true;
    if (isLogCategoryName(channel.parent.name || '')) return true;
    if (normalizeChannelName(channel.parent.name || '').includes('log')) return true;
  }

  return false;
}

function everyoneDenyView(guild) {
  return [{ id: guild.roles.everyone.id, deny: [PermissionFlagsBits.ViewChannel] }];
}

/** Be Civilis — mato tik welcome + roles. */
function publicGateOverwrites(guild) {
  return [
    {
      id: guild.roles.everyone.id,
      allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.ReadMessageHistory],
      deny: [
        PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.AddReactions,
        PermissionFlagsBits.CreatePublicThreads,
        PermissionFlagsBits.CreatePrivateThreads,
        PermissionFlagsBits.AttachFiles,
        PermissionFlagsBits.EmbedLinks,
      ],
    },
  ];
}

/** Tik Civilis (read-only). */
function civilReadOnlyOverwrites(guild, civilRoleId) {
  const overs = [...everyoneDenyView(guild)];
  if (civilRoleId) {
    overs.push({
      id: civilRoleId,
      allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.ReadMessageHistory],
      deny: [
        PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.AddReactions,
        PermissionFlagsBits.CreatePublicThreads,
        PermissionFlagsBits.CreatePrivateThreads,
        PermissionFlagsBits.AttachFiles,
        PermissionFlagsBits.EmbedLinks,
      ],
    });
  }
  return overs;
}

function communityOverwrites(guild, civilRoleId) {
  const overs = [...everyoneDenyView(guild)];
  if (civilRoleId) {
    overs.push({
      id: civilRoleId,
      allow: [
        PermissionFlagsBits.ViewChannel,
        PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.ReadMessageHistory,
        PermissionFlagsBits.AttachFiles,
        PermissionFlagsBits.Connect,
        PermissionFlagsBits.Speak,
        PermissionFlagsBits.AddReactions,
      ],
      // GIF picker (Tenor) reikalauja Embed Links — civiliams draudžiama
      deny: [PermissionFlagsBits.EmbedLinks],
    });
  }
  return overs;
}

function adminViewOverwrites(guild, adminRoleIds) {
  return [
    ...everyoneDenyView(guild),
    ...adminRoleIds.map((id) => ({
      id,
      allow: [
        PermissionFlagsBits.ViewChannel,
        PermissionFlagsBits.ReadMessageHistory,
        PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.EmbedLinks,
        PermissionFlagsBits.AttachFiles,
      ],
    })),
  ];
}

function ticketPanelOverwrites(guild, civilRoleId, adminRoleIds = []) {
  const overs = [...everyoneDenyView(guild)];
  if (civilRoleId) {
    overs.push({
      id: civilRoleId,
      allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.ReadMessageHistory],
      deny: [
        PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.CreatePublicThreads,
        PermissionFlagsBits.CreatePrivateThreads,
        PermissionFlagsBits.EmbedLinks,
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
        PermissionFlagsBits.EmbedLinks,
      ],
    });
  }
  return overs;
}

function factionOverwrites(guild, factionRole, adminRoleIds) {
  const overs = [...everyoneDenyView(guild)];
  if (factionRole) {
    overs.push({
      id: factionRole,
      allow: [
        PermissionFlagsBits.ViewChannel,
        PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.ReadMessageHistory,
        PermissionFlagsBits.AttachFiles,
      ],
      deny: [PermissionFlagsBits.EmbedLinks],
    });
  }
  for (const id of adminRoleIds) {
    overs.push({
      id,
      allow: [
        PermissionFlagsBits.ViewChannel,
        PermissionFlagsBits.SendMessages,
        PermissionFlagsBits.ReadMessageHistory,
        PermissionFlagsBits.ManageMessages,
        PermissionFlagsBits.EmbedLinks,
      ],
    });
  }
  return overs;
}

/** Nuima GIF (Embed Links) nuo @everyone ir Civilis rolių — galioja visame serverį. */
export async function denyCivilianGifPermissions(guild, civilRoleId) {
  const report = { roles: [], errors: [] };

  try {
    const everyone = guild.roles.everyone;
    if (everyone.permissions.has(PermissionFlagsBits.EmbedLinks)) {
      await everyone.setPermissions(
        everyone.permissions.remove(PermissionFlagsBits.EmbedLinks),
        'MRP: civiliai be GIF',
      );
      report.roles.push('@everyone');
    }
  } catch (err) {
    report.errors.push(`@everyone: ${err.message}`);
  }

  if (civilRoleId) {
    try {
      const civil = guild.roles.cache.get(civilRoleId)
        || await guild.roles.fetch(civilRoleId).catch(() => null);
      if (civil && civil.permissions.has(PermissionFlagsBits.EmbedLinks)) {
        await civil.setPermissions(
          civil.permissions.remove(PermissionFlagsBits.EmbedLinks),
          'MRP: civiliai be GIF',
        );
        report.roles.push(civil.name);
      }
    } catch (err) {
      report.errors.push(`Civilis: ${err.message}`);
    }
  }

  return report;
}

/** @deprecated — naudok civilReadOnly / publicGate */
function startReadOnlyOvers(guild) {
  return publicGateOverwrites(guild);
}

/**
 * Pritaiko „be Civilis matai tik Sveiki + roles“ ant jau esamos struktūros.
 */
export async function applyCivilGatePermissions(guild, options = {}) {
  await guild.channels.fetch().catch(() => null);
  await guild.roles.fetch().catch(() => null);
  const setup = getServerSetup(guild.id) || {};
  const civilRoleId = options.civilRoleId || setup.civilRoleId || serverConfig.civilRoleId;
  const channelMap = setup.channelMap || {};
  const categoryMap = setup.categoryMap || {};
  const adminRoleIds = options.adminRoleIds || setup.adminRoleIds || serverConfig.adminRoleIds || [];

  const gifDeny = await denyCivilianGifPermissions(guild, civilRoleId);

  const find = (key, match) => {
    if (channelMap[key]) {
      const ch = guild.channels.cache.get(channelMap[key]);
      if (ch) return ch;
    }
    return guild.channels.cache.find((c) => match?.test(c.name)) || null;
  };

  const updated = [];
  const setOvers = async (ch, overs, label) => {
    if (!ch) return;
    await ch.permissionOverwrites.set(overs).catch(() => null);
    updated.push(label || ch.name);
    await sleep(250);
  };

  // PRADŽIA kategorija — @everyone mato (kad matytų welcome/roles)
  const startCat = categoryMap.start
    ? guild.channels.cache.get(categoryMap.start)
    : guild.channels.cache.find((c) => c.type === ChannelType.GuildCategory && /pradz|start/i.test(c.name));
  await setOvers(startCat, publicGateOverwrites(guild), startCat?.name);

  await setOvers(find('welcome', /sveiki|welcome/i), publicGateOverwrites(guild), 'welcome');
  await setOvers(find('roles', /pasirink.?rol|roles?/i), publicGateOverwrites(guild), 'roles');

  // Likę PRADŽIA — tik Civilis
  for (const [key, re] of [
    ['news', /naujien/i],
    ['howto', /kaip.?prad/i],
    ['faq', /dazniaus|faq|klausim/i],
  ]) {
    await setOvers(find(key, re), civilReadOnlyOverwrites(guild, civilRoleId), key);
  }

  // TAISYKLĖS — tik Civilis
  const rulesCat = categoryMap.rules
    ? guild.channels.cache.get(categoryMap.rules)
    : guild.channels.cache.find((c) => c.type === ChannelType.GuildCategory && /taisyk|rules/i.test(c.name));
  await setOvers(rulesCat, civilReadOnlyOverwrites(guild, civilRoleId), rulesCat?.name);
  if (rulesCat) {
    for (const ch of guild.channels.cache.filter((c) => c.parentId === rulesCat.id).values()) {
      await setOvers(ch, civilReadOnlyOverwrites(guild, civilRoleId), ch.name);
    }
  }

  // BENDRUOMENĖ — tik Civilis (rašyti)
  const communityCat = categoryMap.community
    ? guild.channels.cache.get(categoryMap.community)
    : guild.channels.cache.find((c) => c.type === ChannelType.GuildCategory && /bendruomen|community/i.test(c.name));
  const communityOvers = communityOverwrites(guild, civilRoleId);
  await setOvers(communityCat, communityOvers, communityCat?.name);
  if (communityCat) {
    for (const ch of guild.channels.cache.filter((c) => c.parentId === communityCat.id).values()) {
      await setOvers(ch, communityOvers, ch.name);
    }
  }

  // TICKETAI — Civilis mato ticket-chat (panelę), ne privatų ticket turinį
  const ticketsCat = categoryMap.tickets
    ? guild.channels.cache.get(categoryMap.tickets)
    : guild.channels.cache.find((c) => c.type === ChannelType.GuildCategory && /ticket/i.test(c.name));
  const ticketPanelOvers = ticketPanelOverwrites(guild, civilRoleId, adminRoleIds);
  await setOvers(ticketsCat, ticketPanelOvers, ticketsCat?.name);
  await setOvers(find('ticket_chat', /ticket.?chat/i), ticketPanelOvers, 'ticket_chat');

  return { updated, civilRoleId, adminRoleIds, gifDeny };
}

async function findOrCreateMemberRole(guild, preferredId, name, match, report) {
  if (preferredId) {
    const existing = guild.roles.cache.get(preferredId)
      || await guild.roles.fetch(preferredId).catch(() => null);
    if (existing && !existing.managed) return existing.id;
  }
  const byName = guild.roles.cache.find((r) => !r.managed && match.test(r.name));
  if (byName) return byName.id;

  try {
    const created = await guild.roles.create({
      name,
      mentionable: true,
      reason: 'MRP /setup-server member role',
    });
    report.rolesCreated.push(created.name);
    await sleep(350);
    return created.id;
  } catch (err) {
    report.errors.push(`Rolė ${name}: ${err.message}`);
    return null;
  }
}

async function createCategory(guild, name, overwrites) {
  const cat = await guild.channels.create({
    name,
    type: ChannelType.GuildCategory,
    permissionOverwrites: overwrites || undefined,
    reason: 'MRP /setup-server rebuild',
  });
  await sleep(400);
  return cat;
}

async function createChannel(guild, chDef, parent, overwrites) {
  const type = chDef.type === 'voice' ? ChannelType.GuildVoice : ChannelType.GuildText;
  const ch = await guild.channels.create({
    name: chDef.name,
    type,
    parent: parent?.id,
    permissionOverwrites: overwrites || undefined,
    reason: 'MRP /setup-server rebuild',
  });
  await sleep(400);
  return ch;
}

async function postOnce(channel, marker, embed) {
  if (!channel?.isTextBased?.()) return false;
  const recent = await channel.messages.fetch({ limit: 15 }).catch(() => null);
  const exists = recent?.find((m) => m.author.id === channel.client.user.id && m.embeds?.[0]?.title === embed.data?.title);
  if (exists) return false;
  await channel.send({ embeds: [embed] });
  await sleep(250);
  return true;
}

/**
 * Visą seną struktūrą (išskyrus logus) perkelia į archyvą, tuščias kategorijas ištrina.
 */
async function wipeIntoArchive(guild, archiveCat, knownLogIds, report) {
  await guild.channels.fetch().catch(() => null);

  const channels = [...guild.channels.cache.values()];
  const nonCats = channels.filter((c) => c.type !== ChannelType.GuildCategory);
  const cats = channels.filter((c) => c.type === ChannelType.GuildCategory);

  for (const ch of nonCats) {
    if (ch.id === archiveCat.id) continue;
    if (isProtectedChannel(ch, knownLogIds)) {
      report.logsUntouched.push(ch.id);
      continue;
    }
    try {
      await ch.setParent(archiveCat.id, { lockPermissions: false, reason: 'MRP setup archive' });
      report.archived.push(ch.name);
      await sleep(350);
    } catch (err) {
      report.errors.push(`Archyvas #${ch.name}: ${err.message}`);
    }
  }

  for (const cat of cats) {
    if (cat.id === archiveCat.id) continue;
    if (isProtectedChannel(cat, knownLogIds)) {
      report.logsUntouched.push(cat.id);
      continue;
    }
    const children = guild.channels.cache.filter((c) => c.parentId === cat.id);
    const unprotectedKids = [...children.values()].filter((c) => !isProtectedChannel(c, knownLogIds));
    for (const kid of unprotectedKids) {
      try {
        await kid.setParent(archiveCat.id, { lockPermissions: false, reason: 'MRP setup archive' });
        if (!report.archived.includes(kid.name)) report.archived.push(kid.name);
        await sleep(350);
      } catch (err) {
        report.errors.push(`Archyvas #${kid.name}: ${err.message}`);
      }
    }

    const stillLeft = guild.channels.cache.filter((c) => c.parentId === cat.id).size;
    if (stillLeft === 0) {
      try {
        await cat.delete('MRP setup — sena tuščia kategorija');
        report.categoriesDeleted.push(cat.name);
        await sleep(350);
      } catch (err) {
        report.errors.push(`Kat. trynimas ${cat.name}: ${err.message}`);
      }
    }
  }

  report.logsUntouched = [...new Set(report.logsUntouched)];
}

/**
 * Pilnas Discord serverio rebuild — senas kanalai į archyvą, nauja moderni struktūra.
 * Logų / Admin-logai / stats kanalų NELIEČIA.
 */
export async function applyServerSetup(guild, options = {}) {
  const report = {
    categoriesCreated: [],
    categoriesDeleted: [],
    channelsCreated: [],
    rolesCreated: [],
    archived: [],
    logsUntouched: [],
    adminRoles: options.adminRoleIds || serverConfig.adminRoleIds || [],
    factionRoles: {},
    panels: [],
    errors: [],
    backupFile: null,
    ipOk: !!serverConfig.serverConnectAddress,
    civilRoleId: null,
  };

  const knownLogs = new Set(getAllLogChannels(guild.id).map((r) => r.channel_id));

  try {
    const backup = await createGuildBackup(guild, { adminRoleIds: report.adminRoles });
    report.backupFile = backup.file;
  } catch (err) {
    report.errors.push(`Backup: ${err.message}`);
    return report;
  }

  await guild.roles.fetch().catch(() => null);
  await guild.channels.fetch().catch(() => null);

  const civilRoleId = await findOrCreateMemberRole(
    guild,
    options.civilRoleId || serverConfig.civilRoleId,
    'Civilis',
    /^civilis$|civil|verified|narys|^member$/i,
    report,
  );
  const newsPingRoleId = await findOrCreateMemberRole(
    guild,
    options.newsPingRoleId || serverConfig.newsPingRoleId,
    'Naujienų ping',
    /naujien.*ping|news.?ping/i,
    report,
  );
  const updatesPingRoleId = await findOrCreateMemberRole(
    guild,
    options.updatesPingRoleId || serverConfig.updatesPingRoleId,
    'Atnaujinimų ping',
    /atnaujin.*ping|updates?.?ping/i,
    report,
  );
  const eventsPingRoleId = await findOrCreateMemberRole(
    guild,
    options.eventsPingRoleId || serverConfig.eventsPingRoleId,
    'Eventų ping',
    /event.*ping|events?.?ping/i,
    report,
  );

  const adminRoleIds = report.adminRoles;
  const categoryMap = {};
  const channelMap = {};

  try {
    // 1) Archyvas + senos struktūros išvalymas
    const archiveDef = SERVER_LAYOUT.categories.archive;
    let archiveCat = guild.channels.cache.find(
      (c) => c.type === ChannelType.GuildCategory && archiveDef.match.test(c.name),
    );
    if (!archiveCat) {
      archiveCat = await createCategory(guild, archiveDef.name, adminViewOverwrites(guild, adminRoleIds));
      report.categoriesCreated.push(archiveCat.name);
    } else {
      await archiveCat.permissionOverwrites.set(adminViewOverwrites(guild, adminRoleIds)).catch(() => null);
    }
    categoryMap.archive = archiveCat.id;

    await wipeIntoArchive(guild, archiveCat, knownLogs, report);

    // 2) Nauja struktūra — VISADA kuriam iš naujo
    const civilRO = civilReadOnlyOverwrites(guild, civilRoleId);
    const publicGate = publicGateOverwrites(guild);

    // PRADŽIA — @everyone mato kategoriją; be Civilis tik welcome + roles
    {
      const def = SERVER_LAYOUT.categories.start;
      const cat = await createCategory(guild, def.name, publicGate);
      categoryMap.start = cat.id;
      report.categoriesCreated.push(cat.name);

      for (const chDef of def.channels) {
        const isPublicGate = chDef.key === 'welcome' || chDef.key === 'roles';
        const overs = isPublicGate ? publicGate : civilRO;
        const ch = await createChannel(guild, chDef, cat, overs);
        channelMap[chDef.key] = ch.id;
        report.channelsCreated.push(ch.name);
      }
    }

    // TAISYKLĖS — tik Civilis
    {
      const def = SERVER_LAYOUT.categories.rules;
      const cat = await createCategory(guild, def.name, civilRO);
      categoryMap.rules = cat.id;
      report.categoriesCreated.push(cat.name);

      for (const chDef of def.channels) {
        const ch = await createChannel(guild, chDef, cat, civilRO);
        channelMap[chDef.key] = ch.id;
        report.channelsCreated.push(ch.name);
        const placeholder = RULE_PLACEHOLDERS[chDef.key];
        if (placeholder) {
          await postOnce(ch, `rules:${chDef.key}`, rulesEmbed(placeholder.title, placeholder.body));
        }
      }
    }

    // BENDRUOMENĖ
    {
      const def = SERVER_LAYOUT.categories.community;
      const overs = communityOverwrites(guild, civilRoleId);
      const cat = await createCategory(guild, def.name, overs);
      categoryMap.community = cat.id;
      report.categoriesCreated.push(cat.name);

      for (const chDef of def.channels) {
        const ch = await createChannel(guild, chDef, cat, overs);
        channelMap[chDef.key] = ch.id;
        report.channelsCreated.push(ch.name);
      }
    }

    // FRAKCIJOS
    {
      const def = SERVER_LAYOUT.categories.factions;
      const cat = await createCategory(guild, def.name, everyoneDenyView(guild));
      categoryMap.factions = cat.id;
      report.categoriesCreated.push(cat.name);

      for (const chDef of def.channels) {
        const roleId = options.factionRoles?.[chDef.faction]
          || factionRoleId(chDef.faction)
          || null;
        report.factionRoles[chDef.faction] = roleId;
        const overs = factionOverwrites(guild, roleId, adminRoleIds);
        const ch = await createChannel(guild, chDef, cat, overs);
        channelMap[chDef.key] = ch.id;
        report.channelsCreated.push(ch.name);

        const labels = {
          police: 'Policija',
          ems: 'Medikai',
          mechanic: 'Mechanikai',
          taxi: 'Taxi',
        };
        await postOnce(
          ch,
          `faction:${chDef.faction}`,
          factionInfoEmbed(labels[chDef.faction] || chDef.name, factionDiscordUrl(chDef.faction)),
        );
      }
    }

    // TICKETAI + ticket-chat panelė
    {
      const def = SERVER_LAYOUT.categories.tickets;
      const panelOvers = ticketPanelOverwrites(guild, civilRoleId, adminRoleIds);
      const cat = await createCategory(guild, def.name, panelOvers);
      categoryMap.tickets = cat.id;
      report.categoriesCreated.push(cat.name);

      for (const chDef of def.channels || []) {
        const ch = await createChannel(guild, chDef, cat, panelOvers);
        channelMap[chDef.key] = ch.id;
        report.channelsCreated.push(ch.name);
      }
    }

    // Pozicijos: PRADŽIA → TAISYKLĖS → BENDRUOMENĖ → FRAKCIJOS → TICKETAI → (logai lieka) → ARCHYVAS apačioje
    const ordered = [
      categoryMap.start,
      categoryMap.rules,
      categoryMap.community,
      categoryMap.factions,
      categoryMap.tickets,
    ].filter(Boolean);

    let pos = 0;
    for (const id of ordered) {
      const cat = guild.channels.cache.get(id);
      if (cat) {
        await cat.setPosition(pos++).catch(() => null);
        await sleep(200);
      }
    }
    const arch = guild.channels.cache.get(categoryMap.archive);
    if (arch) {
      await arch.setPosition(999).catch(() => null);
    }

    // Info + panelės
    const welcome = guild.channels.cache.get(channelMap.welcome);
    if (welcome) {
      await postOnce(welcome, 'welcome', modernEmbed(
        `Sveiki atvykę į ${serverConfig.serverName}`,
        [
          'Čia oficialus Discord serveris.',
          '',
          '1. Perskaityk **TAISYKLĖS**',
          '2. Pasirink **Civilis** rolę',
          '3. Prisijunk prie žaidimo su `/ip` (kanale 🎉・off-topic)',
          '4. Reikia pagalbos? Atidaryk ticketą 🎫・ticket-chat',
        ].join('\n'),
      ));
    }

    const howto = guild.channels.cache.get(channelMap.howto);
    if (howto) {
      await postOnce(howto, 'howto', modernEmbed(
        'Kaip pradėti',
        [
          '• Atsisiųsk FiveM',
          '• Nueik į 🎉・off-topic ir rašyk `/ip`',
          '• Pasirink Civilis rolę',
          '• Perskaityk taisykles',
        ].join('\n'),
      ));
    }

    const faq = guild.channels.cache.get(channelMap.faq);
    if (faq) {
      await postOnce(faq, 'faq', modernEmbed(
        'Dažniausi klausimai',
        [
          '**Kur IP?** Naudok `/ip` off-topic kanale.',
          '**Kaip gauti Civilis?** Pasirink rolę 🎭・pasirink-roles.',
          '**Kaip reportuoti?** Nueik į 🎫・ticket-chat.',
        ].join('\n'),
      ));
    }

    const rolesCh = guild.channels.cache.get(channelMap.roles);
    if (rolesCh) {
      const posted = await postRolePicker(rolesCh, {
        civilRoleId,
        newsPingRoleId,
        updatesPingRoleId,
        eventsPingRoleId,
      });
      if (posted) report.panels.push('Role picker');
    }

    const ticketChat = guild.channels.cache.get(channelMap.ticket_chat);
    if (ticketChat) {
      const posted = await postTicketPanel(ticketChat, {
        categoryId: categoryMap.tickets,
        adminRoleIds,
      });
      if (posted) report.panels.push('Ticket panel');
    }

    report.civilRoleId = civilRoleId;

    // Užtikrinam Civilis gate (be rolės — tik welcome + roles)
    await applyCivilGatePermissions(guild, {
      civilRoleId,
      adminRoleIds,
    });

    setServerSetup(guild.id, {
      categoryMap,
      channelMap,
      adminRoleIds,
      civilRoleId,
      newsPingRoleId,
      updatesPingRoleId,
      eventsPingRoleId,
      appliedAt: new Date().toISOString(),
      backupFile: report.backupFile,
      mode: 'full-rebuild',
    });
  } catch (err) {
    report.errors.push(err.message || String(err));
  }

  return report;
}

export function formatReport(report) {
  return [
    '**Serveris perdarytas iš naujo**',
    '',
    `Backup: \`${report.backupFile || '—'}\``,
    `Į archyvą perkelta: **${report.archived?.length || 0}** kanalų`,
    `Senos kategorijos ištrintos: ${(report.categoriesDeleted || []).join(', ') || '—'}`,
    `Naujos kategorijos: ${report.categoriesCreated.join(', ') || '—'}`,
    `Nauji kanalai: **${report.channelsCreated.length}**`,
    `Rolės sukurtos: ${(report.rolesCreated || []).join(', ') || '—'}`,
    `Civilis: ${report.civilRoleId ? `<@&${report.civilRoleId}>` : '—'}`,
    `Logai / stats nepaliesti: **${report.logsUntouched?.length || 0}**`,
    `Admin rolės: ${report.adminRoles.map((id) => `<@&${id}>`).join(', ') || '—'}`,
    `Frakcijos: ${Object.entries(report.factionRoles || {}).map(([k, v]) => `${k}=${v ? `<@&${v}>` : '—'}`).join(', ')}`,
    `Panelės: ${report.panels.join(', ') || '—'}`,
    `/ip: ${report.ipOk ? 'OK' : 'TRŪKSTA SERVER_CONNECT_ADDRESS'}`,
    report.errors?.length ? `**Klaidos:**\n- ${report.errors.join('\n- ')}` : 'Klaidų nėra.',
  ].join('\n');
}

export { getServerSetup };
