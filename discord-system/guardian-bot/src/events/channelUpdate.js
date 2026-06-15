import { AuditLogEvent, Events } from 'discord.js';
import { sendGuildLog } from '../logs/dispatcher.js';

export default {
  name: Events.ChannelUpdate,
  async execute(oldChannel, newChannel) {
    if (!newChannel.guild) return;
    const executor = await getAuditExecutor(newChannel.guild, AuditLogEvent.ChannelUpdate, newChannel.id);
    const changes = [];
    if (oldChannel.name !== newChannel.name) changes.push(`Name: ${oldChannel.name} → ${newChannel.name}`);
    if (oldChannel.topic !== newChannel.topic) changes.push('Topic changed');
    if (!changes.length) return;

    await sendGuildLog(newChannel.guild, 'channel', 'Channel Updated', changes.join('\n'), [
      { name: 'Channel', value: `${newChannel}`, inline: true },
      { name: 'Executor', value: executor ? `${executor}` : 'Unknown', inline: true },
    ]);
  },
};
