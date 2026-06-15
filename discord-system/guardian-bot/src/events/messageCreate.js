import { Events } from 'discord.js';
import { sendGuildLog } from '../logs/dispatcher.js';
import { appConfig } from '../config.js';
import { trackAction } from '../antinuke/tracker.js';
import { isWhitelisted } from '../database/sqlite.js';
import { sendSecurityLog } from '../logs/dispatcher.js';

const inviteRegex = /(discord\.gg|discord\.com\/invite|discordapp\.com\/invite)/i;
const urlRegex = /https?:\/\/[^\s]+/gi;

export default {
  name: Events.MessageCreate,
  async execute(message) {
    if (!message.guild || message.author.bot) return;

    const content = message.content || '';
    const spamCfg = appConfig.spam || {};

    // Invite link filter
    if (inviteRegex.test(content) && !isWhitelisted(message.guild.id, message.author.id, message.guild)) {
      await message.delete().catch(() => null);
      await sendSecurityLog(message.guild, 'Invite Link Blocked', content.slice(0, 500), [
        { name: 'Author', value: `${message.author}`, inline: true },
      ]);
      return;
    }

    // @everyone / @here spam
    const everyoneCount = (content.match(/@(everyone|here)/g) || []).length;
    if (everyoneCount > (spamCfg.maxEveryonePings || 2)) {
      await message.delete().catch(() => null);
      await sendSecurityLog(message.guild, 'Everyone/Here Spam', content.slice(0, 500));
      return;
    }

    // Message spam tracker
    const count = trackAction(message.guild.id, message.author.id, 'messageSpam', spamCfg.windowSec || 4);
    if (count > (spamCfg.maxMessages || 6) && !isWhitelisted(message.guild.id, message.author.id, message.guild)) {
      await message.delete().catch(() => null);
      await sendSecurityLog(message.guild, 'Message Spam', `Messages: ${count}`, [
        { name: 'Author', value: `${message.author}`, inline: true },
      ]);
    }

    // Malicious link basic check (suspicious TLDs)
    const urls = content.match(urlRegex) || [];
    const bad = urls.find((u) => /\.(ru|cn|tk|ml|ga)\//i.test(u));
    if (bad) {
      await sendSecurityLog(message.guild, 'Suspicious Link', bad, [
        { name: 'Author', value: `${message.author}`, inline: true },
      ]);
    }
  },
};
