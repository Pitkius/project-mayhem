import { Events } from 'discord.js';
import { sendGuildLog } from '../logs/dispatcher.js';

export default {
  name: Events.MessageDelete,
  async execute(message) {
    if (!message.guild || message.author?.bot) return;
    await sendGuildLog(message.guild, 'message', 'Message Deleted',
      message.content?.slice(0, 1000) || '*No text content*', [
        { name: 'Author', value: message.author ? `${message.author}` : 'Unknown', inline: true },
        { name: 'Channel', value: `${message.channel}`, inline: true },
      ]);
  },
};
