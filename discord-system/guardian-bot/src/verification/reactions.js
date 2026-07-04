import { getVerificationSettings } from '../database/sqlite.js';
import {
  assertBotCanManageRoles,
  emojiMatches,
  getVerifyEmojis,
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

async function applyMemberVerification(member, verification) {
  const roleIds = [verification.verifiedRoleId, verification.unverifiedRoleId].filter(Boolean);
  if (!roleIds.length) return false;

  await assertBotCanManageRoles(member.guild, roleIds);

  if (verification.verifiedRoleId && !member.roles.cache.has(verification.verifiedRoleId)) {
    await member.roles.add(verification.verifiedRoleId, 'Pasitvirtinimas ✅');
  }
  if (verification.unverifiedRoleId && member.roles.cache.has(verification.unverifiedRoleId)) {
    await member.roles.remove(verification.unverifiedRoleId, 'Pasitvirtinimas ✅');
  }
  return true;
}

async function applyPingVerification(member, verification, adding) {
  if (!verification.pingRoleId) return false;

  await assertBotCanManageRoles(member.guild, [verification.pingRoleId]);

  if (adding) {
    if (!member.roles.cache.has(verification.pingRoleId)) {
      await member.roles.add(verification.pingRoleId, 'Ping rolė 🔔');
    }
  } else if (member.roles.cache.has(verification.pingRoleId)) {
    await member.roles.remove(verification.pingRoleId, 'Ping rolė nuimta');
  }
  return true;
}

export async function handleVerificationReaction(reaction, user, mode) {
  if (user.bot) return;

  const ctx = await fetchReactionContext(reaction, user);
  if (!ctx) return;

  const { guild, verification } = ctx;
  const emojis = getVerifyEmojis(verification);
  const member = await guild.members.fetch(user.id).catch(() => null);
  if (!member) return;

  const emoji = reaction.emoji;
  const adding = mode === 'add';

  if (emojiMatches(emojis.member, emoji)) {
    if (!adding) return;
    await applyMemberVerification(member, verification);
    return;
  }

  if (emojiMatches(emojis.ping, emoji)) {
    await applyPingVerification(member, verification, adding);
    return;
  }

  console.warn(
    '[Verification] Neatpažinta reakcija:',
    emoji.identifier || emoji.name || emoji.toString(),
    'config:',
    emojis.member,
    emojis.ping,
  );
}

/** Pritaiko roles visiems, kurie jau paliko reakciją ant pasitvirtinimo žinutės. */
export async function syncVerificationReactions(guild, verification) {
  if (!verification?.verificationChannelId || !verification?.verificationMessageId) {
    throw new Error('Nėra išsaugotos pasitvirtinimo žinutės. Paleisk `/setupverify post`.');
  }

  const channel = guild.channels.cache.get(verification.verificationChannelId)
    || await guild.channels.fetch(verification.verificationChannelId).catch(() => null);
  if (!channel?.isTextBased?.()) {
    throw new Error('Pasitvirtinimo kanalas nerastas.');
  }

  const message = await channel.messages.fetch(verification.verificationMessageId).catch(() => null);
  if (!message) {
    throw new Error('Pasitvirtinimo žinutė nerasta. Paleisk `/setupverify post` iš naujo.');
  }

  const emojis = getVerifyEmojis(verification);
  await message.fetch(); // užtikrina reakcijas

  let memberCount = 0;
  let pingCount = 0;

  for (const reaction of message.reactions.cache.values()) {
    const users = await reaction.users.fetch();
    for (const [, reactUser] of users) {
      if (reactUser.bot) continue;
      const member = await guild.members.fetch(reactUser.id).catch(() => null);
      if (!member) continue;

      if (emojiMatches(emojis.member, reaction.emoji)) {
        await applyMemberVerification(member, verification);
        memberCount += 1;
      } else if (emojiMatches(emojis.ping, reaction.emoji)) {
        await applyPingVerification(member, verification, true);
        pingCount += 1;
      }
    }
  }

  return { memberCount, pingCount };
}
