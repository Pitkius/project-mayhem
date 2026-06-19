import { AuditLogEvent, Events } from 'discord.js';
import { handleAntinuke, getAuditExecutor } from '../antinuke/punish.js';
import { sendJoinLog, sendGuildLog } from '../logs/dispatcher.js';
import { getVerificationSettings } from '../database/sqlite.js';
import { assertBotCanManageRoles } from '../verification/helpers.js';
import { sendWelcomeAnnouncement } from '../verification/welcome.js';

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

    const verification = getVerificationSettings(member.guild.id);
    if (verification?.enabled && verification.unverifiedRoleId) {
      try {
        await assertBotCanManageRoles(member.guild, [verification.unverifiedRoleId]);
        if (!member.roles.cache.has(verification.unverifiedRoleId)) {
          await member.roles.add(verification.unverifiedRoleId, 'Naujas narys — laukia pasitvirtinimo');
        }
      } catch (err) {
        console.error('[Verification] guildMemberAdd role:', err.message);
      }
    }

    if (verification?.enabled && verification.welcomeChannelId) {
      await sendWelcomeAnnouncement(member, verification);
    }

    await sendJoinLog(member);
  },
};
