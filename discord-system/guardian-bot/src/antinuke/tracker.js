const buckets = new Map();

export function trackAction(guildId, userId, actionType, windowSec) {
  const key = `${guildId}:${userId}:${actionType}`;
  const now = Date.now();
  const windowMs = windowSec * 1000;
  const entries = (buckets.get(key) || []).filter((t) => now - t < windowMs);
  entries.push(now);
  buckets.set(key, entries);
  return entries.length;
}

export function resetAction(guildId, userId, actionType) {
  buckets.delete(`${guildId}:${userId}:${actionType}`);
}
