import { Events } from 'discord.js';
import { sendGuildLog } from '../logs/dispatcher.js';

export default {
  name: Events.GuildBanRemove,
  async execute(ban) {
    await sendGuildLog(ban.guild, 'member', 'Member Unbanned', `${ban.user.tag} (${ban.user.id})`);
  },
};
