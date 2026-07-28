import { REST, Routes } from 'discord.js';
import { env } from './config.js';
import { loadCommandPayloads } from './commands/loadCommandPayloads.js';

export async function registerSlashCommands(client) {
  if (!env.token || !env.clientId) {
    console.warn('[MRP] Slash sync praleistas — nėra DISCORD_TOKEN ar DISCORD_CLIENT_ID.');
    return { ok: false, reason: 'missing_env' };
  }

  const commands = await loadCommandPayloads();
  const rest = new REST({ version: '10' }).setToken(env.token);
  const guildIds = [...new Set([
    env.guildId,
    ...client.guilds.cache.keys(),
  ].filter(Boolean))];

  if (!guildIds.length) {
    console.warn('[MRP] Slash sync praleistas — botas nėra jokiame serveryje.');
    return { ok: false, reason: 'no_guilds' };
  }

  const names = commands.map((c) => c.name).sort();
  for (const guildId of guildIds) {
    try {
      await rest.put(Routes.applicationGuildCommands(env.clientId, guildId), { body: commands });
      console.log(`[MRP] Slash komandos sync (${guildId}): ${commands.length} — ${names.join(', ')}`);
    } catch (err) {
      if (err.code === 50001) {
        console.error(`[MRP] Slash sync klaida (${guildId}): botas nėra serveryje (Missing Access).`);
      } else {
        console.error(`[MRP] Slash sync klaida (${guildId}):`, err.message || err);
      }
      return { ok: false, reason: err.message || String(err) };
    }
  }

  return { ok: true, count: commands.length, names };
}
