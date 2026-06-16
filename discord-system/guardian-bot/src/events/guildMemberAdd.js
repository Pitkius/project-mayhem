import { AuditLogEvent, Events } from 'discord.js';
import { handleAntinuke, getAuditExecutor } from '../antinuke/punish.js';
import { sendJoinLog, sendGuildLog } from '../logs/dispatcher.js';

export default {
  name: Events.GuildMemberAdd,
  async execute(member) {
    if (member.user.bot) {
      const executor = await getAuditExecutor(member.guild, AuditLogEvent.BotAdd, member.id);
      if (executor) {
        await handleAntinuke(member.guild, executor.id, 'botAdd', `Bot: ${member.user.tag}`);
      }
      await sendGuildLog(member.guild, 'security', 'Bot Added', `${member.user.tag} (${member.id})`, [
        { name: 'Added By', value: executor ? `${executor}` : 'Unknown', inline: true },
      ]);
      return;
    }

    await sendJoinLog(member);
  },
};
