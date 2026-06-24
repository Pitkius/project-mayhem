/**
 * Discord serverio narių statistika (ne FiveM).
 * Naudoja guild.memberCount ir approximatePresenceCount — nereikia fetch'inti visų narių.
 */

export function formatGuildChannelName(template, stats) {
  const members = Math.max(0, Number(stats.members) || 0);
  const online = Math.max(0, Number(stats.online) || 0);
  const name = String(template || 'Gyventojai: {members}')
    .replaceAll('{members}', String(members))
    .replaceAll('{online}', String(online))
    .replaceAll('{players}', String(members))
    .replaceAll('{max}', String(members))
    .trim();
  return name.slice(0, 100);
}

export async function fetchDiscordGuildStats(guild) {
  const fetched = await guild.fetch(true);
  const members = Number(fetched.memberCount) || 0;
  const online = Number(fetched.approximatePresenceCount);
  return {
    members,
    online: Number.isFinite(online) ? online : null,
    name: fetched.name,
  };
}
