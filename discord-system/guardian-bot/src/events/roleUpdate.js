import { AuditLogEvent, Events } from 'discord.js';
import { handleAntinuke, getAuditExecutor } from '../antinuke/punish.js';
import { sendGuildLog, sendSecurityLog } from '../logs/dispatcher.js';
import { hasDangerousPermissions, formatPermissions } from '../utils/permissions.js';
import { appConfig } from '../config.js';

export default {
  name: Events.GuildRoleUpdate,
  async execute(oldRole, newRole) {
    const executor = await getAuditExecutor(newRole.guild, AuditLogEvent.RoleUpdate, newRole.id);
    const added = newRole.permissions.remove(oldRole.permissions);

    if (hasDangerousPermissions(added, appConfig.dangerousPermissions)) {
      if (executor) {
        await handleAntinuke(newRole.guild, executor.id, 'roleUpdate', `Dangerous perms on ${newRole.name}`);
      }
      await sendSecurityLog(newRole.guild, 'Dangerous Role Update', `Role: ${newRole.name}`, [
        { name: 'Added', value: formatPermissions(added).slice(0, 1024) },
        { name: 'Executor', value: executor ? `${executor}` : 'Unknown', inline: true },
      ]);
    }

    await sendGuildLog(newRole.guild, 'role', 'Role Updated', newRole.name, [
      { name: 'Executor', value: executor ? `${executor}` : 'Unknown', inline: true },
    ]);
  },
};
