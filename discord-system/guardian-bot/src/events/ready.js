import { Events, ActivityType } from 'discord.js';
import { applyBotBranding, BOT_BRAND } from '../utils/branding.js';

export default {
  name: Events.ClientReady,
  once: true,
  async execute(client) {
    try {
      await applyBotBranding(client);
    } catch (err) {
      console.warn('[MRP] Branding error:', err.message);
    }

    client.user.setPresence({
      activities: [{ name: 'MAYHEM RP', type: ActivityType.Watching }],
      status: 'online',
    });

    console.log(`[MRP] Prisijungta kaip ${client.user.tag}`);
    console.log(`[MRP] Serveriu: ${client.guilds.cache.size}`);
  },
};
