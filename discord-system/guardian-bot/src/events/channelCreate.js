import { AuditLogEvent, Events } from 'discord.js';
import { handleAntinuke, getAuditExecutor } from '../antinuke/punish.js';
import { sendGuildLog } from '../logs/dispatcher.js';

export default {
  name: Events.ChannelCreate,
  async execute(channel) {
    if (!channel.guild) return;
    const executor = await getAuditExecutor(channel.guild, AuditLogEvent.ChannelCreate, channel.id);
    if (executor) {
      await handleAntinuke(channel.guild, executor.id, 'channelCreate', `Channel: ${channel.name}`);
    }
    await sendGuildLog(channel.guild, 'channel', 'Channel Created', `${channel} (${channel.id})`, [
      { name: 'Type', value: channel.type.toString(), inline: true },
      { name: 'Executor', value: executor ? `${executor}` : 'Unknown', inline: true },
    ]);
  },
};
