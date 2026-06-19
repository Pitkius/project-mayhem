import {
  ChannelType,
  Colors,
  EmbedBuilder,
  PermissionFlagsBits,
} from 'discord.js';

export const VERIFY_EMOJI_MEMBER = '✅';
export const VERIFY_EMOJI_PING = '🔔';

export function normalizeChannelName(name) {
  return String(name || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^\p{L}\p{N}\-]+/gu, '')
    .trim();
}

const CHANNEL_SLUG_ALIASES = {
  'oro-uostas': ['oro-uostas', 'orouostas', 'uostas'],
  pasitvirtinimas: ['pasitvirtinimas', 'patvirtinimas', 'verify', 'verification'],
  taisykles: ['taisykles', 'taisykle', 'rules', 'server-rules', 'taisykliu'],
};

function channelNameCandidates(name) {
  const base = normalizeChannelName(name);
  const set = new Set([base]);
  for (const aliases of Object.values(CHANNEL_SLUG_ALIASES)) {
    for (const alias of aliases) {
      if (base.includes(alias) || alias.includes(base)) set.add(alias);
    }
  }
  return set;
}

export async function findChannelBySlug(guild, slug) {
  const aliases = CHANNEL_SLUG_ALIASES[slug] || [slug];
  const wants = new Set(aliases.map((a) => normalizeChannelName(a)).filter(Boolean));

  if (guild.channels.cache.size < 3) {
    await guild.channels.fetch().catch(() => null);
  }

  return guild.channels.cache.find((ch) => {
    if (!ch.isTextBased?.()) return false;
    const normalized = normalizeChannelName(ch.name);
    if (wants.has(normalized)) return true;
    for (const want of wants) {
      if (want && (normalized.includes(want) || want.includes(normalized))) return true;
    }
    const candidates = channelNameCandidates(ch.name);
    for (const want of wants) {
      for (const cand of candidates) {
        if (cand === want || cand.includes(want) || want.includes(cand)) return true;
      }
    }
    return false;
  }) || null;
}

export function emojiMatches(configEmoji, reactionEmoji) {
  const cfg = String(configEmoji || '');
  if (!cfg) return false;
  if (reactionEmoji.id) {
    return cfg === reactionEmoji.identifier || cfg === reactionEmoji.id || cfg === `<:${reactionEmoji.name}:${reactionEmoji.id}>`;
  }
  return cfg === reactionEmoji.name || cfg === reactionEmoji.toString();
}

export function buildVerificationEmbed(guild) {
  return new EmbedBuilder()
    .setColor(Colors.Purple)
    .setTitle('Pasitvirtinimas')
    .setDescription(
      [
        `Sveiki atvykę į **${guild.name}**!`,
        '',
        `Reakcija **${VERIFY_EMOJI_MEMBER}** — prisijungi prie serverio ir matai visus kanalus.`,
        `Reakcija **${VERIFY_EMOJI_PING}** — gauni ping pranešimus (galima įjungti/išjungti).`,
        '',
        'Paspausk emoji žemiau šios žinutės.',
      ].join('\n'),
    )
    .setFooter({ text: 'Mayhem RP · Guardian' });
}

export async function applyGuestChannelPermissions(guild, verification) {
  const everyone = guild.roles.everyone;
  const visible = new Set(verification.visibleChannelIds || []);
  if (!visible.size) {
    throw new Error('Nėra matomų kanalų — pirmiausia /setupverify config');
  }

  let changed = 0;

  for (const category of guild.channels.cache.filter((c) => c.type === ChannelType.GuildCategory).values()) {
    await category.permissionOverwrites.edit(everyone, { ViewChannel: false });
    changed += 1;
  }

  for (const channel of guild.channels.cache.values()) {
    const isGuestVisible = visible.has(channel.id);
    const isText = channel.type === ChannelType.GuildText || channel.type === ChannelType.GuildAnnouncement;
    const isVoice = channel.type === ChannelType.GuildVoice || channel.type === ChannelType.GuildStageVoice;
    const isForum = channel.type === ChannelType.GuildForum;

    if (!isText && !isVoice && !isForum) continue;

    if (isGuestVisible) {
      const allow = { ViewChannel: true };
      if (isText && channel.id === verification.verificationChannelId) {
        allow.SendMessages = false;
        allow.AddReactions = true;
        allow.ReadMessageHistory = true;
      } else if (isText) {
        allow.SendMessages = false;
        allow.ReadMessageHistory = true;
      }
      await channel.permissionOverwrites.edit(everyone, allow);
    } else {
      await channel.permissionOverwrites.edit(everyone, { ViewChannel: false });
    }
    changed += 1;
  }

  const verifiedRoleId = verification.verifiedRoleId;
  if (verifiedRoleId) {
    const verifiedRole = guild.roles.cache.get(verifiedRoleId);
    if (!verifiedRole) {
      throw new Error('Verified rolė nerasta serveryje.');
    }
    if (verifiedRole.position >= guild.members.me.roles.highest.position) {
      throw new Error('Boto rolė turi būti aukščiau už verified rolę (Server Settings → Roles).');
    }

    for (const channel of guild.channels.cache.values()) {
      const isText = channel.type === ChannelType.GuildText || channel.type === ChannelType.GuildAnnouncement;
      const isVoice = channel.type === ChannelType.GuildVoice || channel.type === ChannelType.GuildStageVoice;
      const isForum = channel.type === ChannelType.GuildForum;
      if (!isText && !isVoice && !isForum) continue;
      if (visible.has(channel.id)) continue;
      await channel.permissionOverwrites.edit(verifiedRole, {
        ViewChannel: true,
        SendMessages: isText || isForum,
        Connect: isVoice,
        Speak: isVoice,
        ReadMessageHistory: true,
      });
    }
  }

  return changed;
}

export async function assertBotCanManageRoles(guild, roleIds = []) {
  const me = guild.members.me;
  if (!me?.permissions.has(PermissionFlagsBits.ManageRoles)) {
    throw new Error('Botui reikia Manage Roles teisės.');
  }
  for (const roleId of roleIds.filter(Boolean)) {
    const role = guild.roles.cache.get(roleId);
    if (!role) throw new Error(`Rolė nerasta: ${roleId}`);
    if (role.position >= me.roles.highest.position) {
      throw new Error(`Boto rolė turi būti aukščiau už „${role.name}“.`);
    }
  }
}
