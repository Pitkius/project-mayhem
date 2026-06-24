import { AuditLogEvent, Events } from 'discord.js';
import { handleAntinuke, getAuditExecutor } from '../antinuke/punish.js';
import { sendGuildLog } from '../logs/dispatcher.js';
import { requestMemberStatsRefresh } from '../discord/memberChannel.js';

export default {
  name: Events.GuildMemberRemove,
  async execute(member, client) {
    const executor = await getAuditExecutor(member.guild, AuditLogEvent.MemberKick, member.id);
    if (executor) {
      await handleAntinuke(member.guild, executor.id, 'massKick', `Kicked: ${member.user.tag}`);
      await sendGuildLog(member.guild, 'mod', 'Member Kicked', `${member.user.tag}`, [
        { name: 'Executor', value: `${executor}`, inline: true },
      ]);
      requestMemberStatsRefresh(client, member.guild, 'kick');
      return;
    }
    await sendGuildLog(member.guild, 'member', 'Member Left', `${member.user.tag} (${member.id})`);
    requestMemberStatsRefresh(client, member.guild, 'išejo');
  },
};
