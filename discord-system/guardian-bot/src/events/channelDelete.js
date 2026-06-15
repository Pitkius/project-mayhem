import { AuditLogEvent, Events } from 'discord.js';
import { handleAntinuke, getAuditExecutor } from '../antinuke/punish.js';
import { sendGuildLog } from '../logs/dispatcher.js';

export default {
  name: Events.ChannelDelete,
  async execute(channel) {
    if (!channel.guild) return;
    const executor = await getAuditExecutor(channel.guild, AuditLogEvent.ChannelDelete, channel.id);
    if (executor) {
      await handleAntinuke(channel.guild, executor.id, 'channelDelete', `Channel: ${channel.name}`);
    }
    await sendGuildLog(channel.guild, 'channel', 'Channel Deleted', `${channel.name} (${channel.id})`, [
      { name: 'Executor', value: executor ? `${executor}` : 'Unknown', inline: true },
    ]);
  },
};
