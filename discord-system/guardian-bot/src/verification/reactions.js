import { getVerificationSettings } from '../database/sqlite.js';
import {
  VERIFY_EMOJI_MEMBER,
  VERIFY_EMOJI_PING,
  assertBotCanManageRoles,
  emojiMatches,
} from './helpers.js';

async function fetchReactionContext(reaction, user) {
  if (reaction.partial) await reaction.fetch();
  if (reaction.message.partial) await reaction.message.fetch();
  if (user.partial) await user.fetch();

  const message = reaction.message;
  if (!message.guild) return null;

  const verification = getVerificationSettings(message.guild.id);
  if (!verification?.enabled) return null;
  if (!verification.verificationMessageId || message.id !== verification.verificationMessageId) return null;
  if (message.channel.id !== verification.verificationChannelId) return null;

  return { message, verification, guild: message.guild };
}

export async function handleVerificationReaction(reaction, user, mode) {
  if (user.bot) return;

  const ctx = await fetchReactionContext(reaction, user);
  if (!ctx) return;

  const { guild, verification } = ctx;
  const member = await guild.members.fetch(user.id).catch(() => null);
  if (!member) return;

  await assertBotCanManageRoles(guild, [
    verification.verifiedRoleId,
    verification.pingRoleId,
    verification.unverifiedRoleId,
  ]);

  const emoji = reaction.emoji;
  const adding = mode === 'add';

  if (emojiMatches(VERIFY_EMOJI_MEMBER, emoji)) {
    if (!adding) return;
    if (verification.verifiedRoleId) {
      await member.roles.add(verification.verifiedRoleId, 'Pasitvirtinimas ✅');
    }
    if (verification.unverifiedRoleId && member.roles.cache.has(verification.unverifiedRoleId)) {
      await member.roles.remove(verification.unverifiedRoleId, 'Pasitvirtinimas ✅');
    }
    return;
  }

  if (emojiMatches(VERIFY_EMOJI_PING, emoji)) {
    if (!verification.pingRoleId) return;
    if (adding) {
      await member.roles.add(verification.pingRoleId, 'Ping rolė 🔔');
    } else {
      await member.roles.remove(verification.pingRoleId, 'Ping rolė nuimta');
    }
  }
}
