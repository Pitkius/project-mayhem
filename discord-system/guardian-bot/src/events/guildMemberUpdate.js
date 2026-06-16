import { Events } from 'discord.js';
import { sendGuildLog } from '../logs/dispatcher.js';

export default {
  name: Events.GuildMemberUpdate,
  async execute(oldMember, newMember) {
    if (oldMember.nickname !== newMember.nickname) {
      await sendGuildLog(newMember.guild, 'member', 'Nickname Changed',
        `${newMember.user.tag}`, [
          { name: 'Before', value: oldMember.nickname || 'None', inline: true },
          { name: 'After', value: newMember.nickname || 'None', inline: true },
        ]);
    }
    if (oldMember.user.username !== newMember.user.username) {
      await sendGuildLog(newMember.guild, 'member', 'Username Changed',
        `${oldMember.user.username} → ${newMember.user.username}`);
    }
    if (oldMember.user.avatar !== newMember.user.avatar) {
      await sendGuildLog(newMember.guild, 'member', 'Avatar Changed', `${newMember.user.tag}`);
    }
  },
};
