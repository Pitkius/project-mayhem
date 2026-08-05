import fs from 'node:fs';
import path from 'node:path';
import { env } from '../config.js';

const defaultData = () => ({
  guild_settings: {},
  log_channels: {},
  fivem_webhooks: {},
  whitelist: [],
  warnings: [],
  _nextId: 1,
});

let data = null;
let filePath = null;

function resolvePath() {
  if (filePath) return filePath;
  const dbPath = path.resolve(process.cwd(), env.databasePath);
  filePath = dbPath.endsWith('.json') ? dbPath : dbPath.replace(/\.db$/i, '.json');
  return filePath;
}

function migrateStore(parsed) {
  const base = defaultData();
  return {
    ...base,
    ...parsed,
    guild_settings: { ...base.guild_settings, ...(parsed.guild_settings || {}) },
    log_channels: { ...base.log_channels, ...(parsed.log_channels || {}) },
    fivem_webhooks: { ...base.fivem_webhooks, ...(parsed.fivem_webhooks || {}) },
    whitelist: Array.isArray(parsed.whitelist) ? parsed.whitelist : base.whitelist,
    warnings: Array.isArray(parsed.warnings) ? parsed.warnings : base.warnings,
    _nextId: parsed._nextId || base._nextId,
  };
}

function load() {
  if (data) return data;
  const target = resolvePath();
  fs.mkdirSync(path.dirname(target), { recursive: true });
  if (fs.existsSync(target)) {
    data = migrateStore(JSON.parse(fs.readFileSync(target, 'utf8')));
    save();
  } else {
    data = defaultData();
    save();
  }
  return data;
}

function save() {
  fs.writeFileSync(resolvePath(), JSON.stringify(data, null, 2), 'utf8');
}

export function getDb() {
  return load();
}

export function getGuildSettings(guildId) {
  const row = load().guild_settings[guildId];
  if (!row) return null;
  return {
    guild_id: guildId,
    antinuke_enabled: !!row.antinuke_enabled,
    antinuke: row.antinuke || null,
    verification: row.verification || null,
    invite: row.invite || null,
  };
}

export function getInviteSettings(guildId) {
  return load().guild_settings[guildId]?.invite || null;
}

export function setInviteSettings(guildId, invite) {
  const store = load();
  const existing = store.guild_settings[guildId] || {};
  store.guild_settings[guildId] = {
    ...existing,
    invite,
    created_at: existing.created_at || new Date().toISOString(),
  };
  save();
}

export function listGuildsWithInvite() {
  const store = load();
  return Object.entries(store.guild_settings)
    .filter(([, row]) => row?.invite?.code)
    .map(([guildId, row]) => ({ guildId, invite: row.invite }));
}

export function getVerificationSettings(guildId) {
  return load().guild_settings[guildId]?.verification || null;
}

export function setVerificationSettings(guildId, verification) {
  const store = load();
  const existing = store.guild_settings[guildId] || {};
  store.guild_settings[guildId] = {
    ...existing,
    verification,
    created_at: existing.created_at || new Date().toISOString(),
  };
  save();
}

export function upsertGuildSettings(guildId, settings = {}) {
  const store = load();
  const existing = store.guild_settings[guildId] || {};
  store.guild_settings[guildId] = {
    antinuke_enabled: settings.antinuke_enabled !== undefined
      ? !!settings.antinuke_enabled
      : (existing.antinuke_enabled ?? true),
    antinuke: settings.antinuke !== undefined ? settings.antinuke : (existing.antinuke || null),
    verification: settings.verification !== undefined ? settings.verification : (existing.verification || null),
    invite: settings.invite !== undefined ? settings.invite : (existing.invite || null),
    created_at: existing.created_at || new Date().toISOString(),
  };
  save();
}

export function setLogChannel(guildId, logType, channelId) {
  const store = load();
  if (!store.log_channels[guildId]) store.log_channels[guildId] = {};
  store.log_channels[guildId][logType] = channelId;
  save();
}

export function getLogChannel(guildId, logType) {
  return load().log_channels[guildId]?.[logType] || null;
}

export function getAllLogChannels(guildId) {
  const channels = load().log_channels[guildId] || {};
  return Object.entries(channels).map(([log_type, channel_id]) => ({ log_type, channel_id }));
}

export function setFivemWebhooks(guildId, webhooks) {
  const store = load();
  store.fivem_webhooks[guildId] = { ...(store.fivem_webhooks[guildId] || {}), ...webhooks };
  save();
}

export function getFivemWebhooks(guildId) {
  return load().fivem_webhooks[guildId] || {};
}

export function hasLogChannels(guildId) {
  const discord = load().log_channels[guildId] || {};
  return Object.keys(discord).length > 0;
}

export function addWhitelist(guildId, targetId, targetType, addedBy, note = '') {
  const store = load();
  const exists = store.whitelist.find(
    (w) => w.guild_id === guildId && w.target_id === targetId && w.target_type === targetType,
  );
  if (exists) return;

  store.whitelist.push({
    id: store._nextId++,
    guild_id: guildId,
    target_id: targetId,
    target_type: targetType,
    added_by: addedBy,
    note,
    created_at: new Date().toISOString(),
  });
  save();
}

export function removeWhitelist(guildId, targetId, targetType) {
  const store = load();
  const before = store.whitelist.length;
  store.whitelist = store.whitelist.filter(
    (w) => !(w.guild_id === guildId && w.target_id === targetId && w.target_type === targetType),
  );
  save();
  return before - store.whitelist.length;
}

export function listWhitelist(guildId) {
  return load().whitelist
    .filter((w) => w.guild_id === guildId)
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
}

export function isWhitelisted(guildId, userId, guild) {
  if (guild?.ownerId === userId) return true;

  const rows = listWhitelist(guildId);
  for (const row of rows) {
    if (row.target_type === 'user' && row.target_id === userId) return true;
    if (row.target_type === 'role' && guild?.members?.cache?.get(userId)?.roles?.cache?.has(row.target_id)) {
      return true;
    }
    if (row.target_type === 'bot' && row.target_id === userId) return true;
  }
  return false;
}

export function addWarning(guildId, userId, moderatorId, reason) {
  const store = load();
  const id = store._nextId++;
  store.warnings.push({
    id,
    guild_id: guildId,
    user_id: userId,
    moderator_id: moderatorId,
    reason,
    created_at: new Date().toISOString(),
  });
  save();
  return id;
}

export function getWarnings(guildId, userId) {
  return load().warnings
    .filter((w) => w.guild_id === guildId && w.user_id === userId)
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
}

export function clearWarnings(guildId, userId) {
  const store = load();
  const before = store.warnings.length;
  store.warnings = store.warnings.filter((w) => !(w.guild_id === guildId && w.user_id === userId));
  save();
  return before - store.warnings.length;
}
