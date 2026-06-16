import { Events } from 'discord.js';
import { sendGuildLog } from '../logs/dispatcher.js';

export default {
  name: Events.VoiceStateUpdate,
  async execute(oldState, newState) {
    const guild = newState.guild || oldState.guild;
    const member = newState.member || oldState.member;
    if (!guild || !member || member.user.bot) return;

    if (!oldState.channelId && newState.channelId) {
      await sendGuildLog(guild, 'voice', 'Voice Join', `${member}`, [
        { name: 'Channel', value: `<#${newState.channelId}>`, inline: true },
      ]);
    } else if (oldState.channelId && !newState.channelId) {
      await sendGuildLog(guild, 'voice', 'Voice Leave', `${member}`, [
        { name: 'Channel', value: `<#${oldState.channelId}>`, inline: true },
      ]);
    } else if (oldState.channelId !== newState.channelId) {
      await sendGuildLog(guild, 'voice', 'Voice Move', `${member}`, [
        { name: 'From', value: `<#${oldState.channelId}>`, inline: true },
        { name: 'To', value: `<#${newState.channelId}>`, inline: true },
      ]);
    }
  },
};
