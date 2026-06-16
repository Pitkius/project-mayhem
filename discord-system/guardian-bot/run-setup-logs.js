/**
 * Vienkartinis logų kanalų sukūrimas (be rankinio /setup Discord'e).
 * Naudojimas: npm run setup:logs
 */
import 'dotenv/config';
import { Client, GatewayIntentBits, Events } from 'discord.js';
import { assertEnv, env } from './src/config.js';
import { getDb } from './src/database/sqlite.js';
import { provisionLogChannels, formatProvisionSummary } from './src/logs/provision.js';

assertEnv();
getDb();

const client = new Client({
  intents: [GatewayIntentBits.Guilds],
});

client.once(Events.ClientReady, async () => {
  const guildId = env.guildId;
  const guild = guildId
    ? client.guilds.cache.get(guildId) || await client.guilds.fetch(guildId).catch(() => null)
    : client.guilds.cache.first();

  if (!guild) {
    console.error('[MRP] Serveris nerastas. Nustatyk DISCORD_GUILD_ID .env faile.');
    process.exit(1);
  }

  console.log(`[MRP] Kuriu logų kanalus serveryje: ${guild.name} (${guild.id})`);

  try {
    const results = await provisionLogChannels(guild, client);
    console.log(formatProvisionSummary(results).replace(/\*\*/g, ''));
    if (results.exportPath) {
      console.log(`[MRP] FiveM webhook failas: ${results.exportPath}`);
    }
    console.log('[MRP] Baigta.');
  } catch (err) {
    console.error('[MRP] Klaida:', err.message);
    console.error(err);
    process.exit(1);
  }

  client.destroy();
  process.exit(0);
});

await client.login(env.token);
