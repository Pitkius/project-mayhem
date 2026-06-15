import { PermissionFlagsBits } from 'discord.js';

export function isModerator(member) {
  return member.permissions.has(PermissionFlagsBits.ModerateMembers)
    || member.permissions.has(PermissionFlagsBits.KickMembers)
    || member.permissions.has(PermissionFlagsBits.BanMembers)
    || member.permissions.has(PermissionFlagsBits.Administrator);
}

export function isAdmin(member) {
  return member.permissions.has(PermissionFlagsBits.Administrator)
    || member.guild.ownerId === member.id;
}

export function hasDangerousPermissions(permBitfield, dangerousList) {
  const names = dangerousList || [];
  return names.some((name) => {
    const flag = PermissionFlagsBits[name];
    return flag && permBitfield.has(flag);
  });
}

export function formatPermissions(permBitfield) {
  return permBitfield.toArray().join(', ') || 'None';
}
