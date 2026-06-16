import { AuditLogEvent, Events } from 'discord.js';
import { handleAntinuke, getAuditExecutor } from '../antinuke/punish.js';
import { sendGuildLog } from '../logs/dispatcher.js';

export default {
  name: Events.WebhooksUpdate,
  async execute(channel) {
    const executor = await getAuditExecutor(channel.guild, AuditLogEvent.WebhookCreate);
    if (executor) {
      await handleAntinuke(channel.guild, executor.id, 'webhookCreate', `Channel: ${channel.name}`);
    }
    await sendGuildLog(channel.guild, 'webhook', 'Webhook Update', `Channel: ${channel.name}`, [
      { name: 'Executor', value: executor ? `${executor}` : 'Unknown', inline: true },
    ]);
  },
};
