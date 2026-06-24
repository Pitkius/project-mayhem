import { Events, ActivityType } from 'discord.js';
import { applyBotBranding } from '../utils/branding.js';
import { hasLogChannels } from '../database/sqlite.js';
import { provisionLogChannels } from '../logs/provision.js';
import { registerSlashCommands } from '../registerSlashCommands.js';
import { startMemberChannelTracker } from '../discord/memberChannel.js';

export default {
  name: Events.ClientReady,
  once: true,
  async execute(client) {
    try {
      await applyBotBranding(client);
    } catch (err) {
      console.warn('[MRP] Branding error:', err.message);
    }

    if (process.env.SYNC_COMMANDS_ON_START !== 'false') {
      const sync = await registerSlashCommands(client);
      if (!sync.ok) {
        console.warn('[MRP] Paleisk rankiniu būdu: npm run deploy');
      }
    }

    client.user.setPresence({
      activities: [{ name: 'MAYHEM RP', type: ActivityType.Watching }],
      status: 'online',
    });

    startMemberChannelTracker(client);

    console.log(`[MRP] Prisijungta kaip ${client.user.tag}`);
    console.log(`[MRP] Serveriu: ${client.guilds.cache.size}`);

    if (process.env.AUTO_PROVISION_LOGS === 'true') {
      for (const guild of client.guilds.cache.values()) {
        if (hasLogChannels(guild.id)) continue;
        try {
          const results = await provisionLogChannels(guild, client);
          console.log(`[MRP] Auto-provision ${guild.name}: ${results.created.length} sukurta`);
        } catch (err) {
          console.warn(`[MRP] Auto-provision klaida (${guild.name}):`, err.message);
        }
      }
    }
  },
};
