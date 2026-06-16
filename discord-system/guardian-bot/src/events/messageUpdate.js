import { Events } from 'discord.js';
import { sendGuildLog } from '../logs/dispatcher.js';

export default {
  name: Events.MessageUpdate,
  async execute(oldMessage, newMessage) {
    if (!newMessage.guild || newMessage.author?.bot) return;
    if (oldMessage.content === newMessage.content) return;

    await sendGuildLog(newMessage.guild, 'message', 'Message Edited', null, [
      { name: 'Author', value: `${newMessage.author}`, inline: true },
      { name: 'Channel', value: `${newMessage.channel}`, inline: true },
      { name: 'Before', value: oldMessage.content?.slice(0, 500) || '—' },
      { name: 'After', value: newMessage.content?.slice(0, 500) || '—' },
    ]);
  },
};
