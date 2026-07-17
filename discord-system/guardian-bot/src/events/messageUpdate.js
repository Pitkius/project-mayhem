import { Events } from 'discord.js';
import { sendGuildLog } from '../logs/dispatcher.js';
import { handleGifMessage } from '../moderation/gifFilter.js';

export default {
  name: Events.MessageUpdate,
  async execute(oldMessage, newMessage) {
    if (!newMessage.guild || newMessage.author?.bot) return;

    // Tenor/Giphy dažnai užkrauna embed vėliau — tikrinam ir update'e
    const msg = newMessage.partial ? await newMessage.fetch().catch(() => null) : newMessage;
    if (msg && await handleGifMessage(msg)) return;

    if (oldMessage.content === newMessage.content) return;

    await sendGuildLog(newMessage.guild, 'message', 'Message Edited', null, [
      { name: 'Author', value: `${newMessage.author}`, inline: true },
      { name: 'Channel', value: `${newMessage.channel}`, inline: true },
      { name: 'Before', value: oldMessage.content?.slice(0, 500) || '—' },
      { name: 'After', value: newMessage.content?.slice(0, 500) || '—' },
    ]);
  },
};
