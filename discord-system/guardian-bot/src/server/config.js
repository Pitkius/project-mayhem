import { Colors } from 'discord.js';
import { env, appConfig } from '../config.js';

const serverCfg = appConfig.server || {};

/** Viena vieta visiems setup / panel / /ip nustatymams. */
export const serverConfig = {
  guildId: env.guildId || serverCfg.guildId || null,
  embedColor: Number(serverCfg.embedColor ?? Colors.Blurple) || Colors.Blurple,
  civilRoleId: serverCfg.civilRoleId || null,
  adminRoleIds: Array.isArray(serverCfg.adminRoleIds) ? serverCfg.adminRoleIds.map(String) : [],
  policeRoleId: serverCfg.policeRoleId || null,
  emsRoleId: serverCfg.emsRoleId || null,
  mechanicRoleId: serverCfg.mechanicRoleId || null,
  taxiRoleId: serverCfg.taxiRoleId || null,
  newsPingRoleId: serverCfg.newsPingRoleId || null,
  updatesPingRoleId: serverCfg.updatesPingRoleId || null,
  eventsPingRoleId: serverCfg.eventsPingRoleId || null,
  serverName: serverCfg.serverName || 'MAYHEM RP',
  serverConnectAddress: process.env.SERVER_CONNECT_ADDRESS || serverCfg.serverConnectAddress || '',
  policeDiscordUrl: serverCfg.policeDiscordUrl || '',
  emsDiscordUrl: serverCfg.emsDiscordUrl || '',
  mechanicDiscordUrl: serverCfg.mechanicDiscordUrl || '',
  taxiDiscordUrl: serverCfg.taxiDiscordUrl || '',
  maxTicketsPerUser: Number(serverCfg.maxTicketsPerUser || 2),
  setupArchiveCategoryName: serverCfg.setupArchiveCategoryName || '📦・SENAS SERVERIO ARCHYVAS',
  offTopicChannelMatch: /off.?topic/i,
};

export function factionRoleId(key) {
  return {
    police: serverConfig.policeRoleId,
    ems: serverConfig.emsRoleId,
    mechanic: serverConfig.mechanicRoleId,
    taxi: serverConfig.taxiRoleId,
  }[key] || null;
}

export function factionDiscordUrl(key) {
  return {
    police: serverConfig.policeDiscordUrl,
    ems: serverConfig.emsDiscordUrl,
    mechanic: serverConfig.mechanicDiscordUrl,
    taxi: serverConfig.taxiDiscordUrl,
  }[key] || '';
}

export function mergeServerConfig(partial = {}) {
  Object.assign(serverConfig, partial);
}
