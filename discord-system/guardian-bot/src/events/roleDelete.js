import { AuditLogEvent, Events } from 'discord.js';
import { handleAntinuke, getAuditExecutor } from '../antinuke/punish.js';
import { sendGuildLog } from '../logs/dispatcher.js';

export default {
  name: Events.GuildRoleDelete,
  async execute(role) {
    const executor = await getAuditExecutor(role.guild, AuditLogEvent.RoleDelete, role.id);
    if (executor) {
      await handleAntinuke(role.guild, executor.id, 'roleDelete', `Role: ${role.name}`);
    }
    await sendGuildLog(role.guild, 'role', 'Role Deleted', role.name, [
      { name: 'Executor', value: executor ? `${executor}` : 'Unknown', inline: true },
    ]);
  },
};
