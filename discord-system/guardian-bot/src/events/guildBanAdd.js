import { AuditLogEvent, Events } from 'discord.js';
import { handleAntinuke, getAuditExecutor } from '../antinuke/punish.js';
import { sendGuildLog } from '../logs/dispatcher.js';

export default {
  name: Events.GuildBanAdd,
  async execute(ban) {
    const executor = await getAuditExecutor(ban.guild, AuditLogEvent.MemberBanAdd, ban.user.id);
    if (executor) {
      await handleAntinuke(ban.guild, executor.id, 'massBan', `Banned: ${ban.user.tag}`);
    }
    await sendGuildLog(ban.guild, 'member', 'Member Banned', `${ban.user.tag} (${ban.user.id})`, [
      { name: 'Executor', value: executor ? `${executor}` : 'Unknown', inline: true },
      { name: 'Reason', value: ban.reason || 'No reason', inline: false },
    ]);
  },
};
