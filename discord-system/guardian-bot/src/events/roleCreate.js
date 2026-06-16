import { AuditLogEvent, Events } from 'discord.js';
import { handleAntinuke, getAuditExecutor } from '../antinuke/punish.js';
import { sendGuildLog } from '../logs/dispatcher.js';

export default {
  name: Events.GuildRoleCreate,
  async execute(role) {
    const executor = await getAuditExecutor(role.guild, AuditLogEvent.RoleCreate, role.id);
    if (executor) {
      await handleAntinuke(role.guild, executor.id, 'roleCreate', `Role: ${role.name}`);
    }
    await sendGuildLog(role.guild, 'role', 'Role Created', role.name, [
      { name: 'Executor', value: executor ? `${executor}` : 'Unknown', inline: true },
    ]);
  },
};
