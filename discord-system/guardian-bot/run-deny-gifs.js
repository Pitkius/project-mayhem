/**
 * Pritaiko: civiliai be GIF (Embed Links) visame Discord.
 */
import 'dotenv/config';
import { Client, GatewayIntentBits } from 'discord.js';
import { assertEnv, env } from './src/config.js';
import { getDb, getServerSetup } from './src/database/sqlite.js';
import { applyCivilGatePermissions } from './src/server/apply.js';

assertEnv();
getDb();

const GUILD_ID = env.guildId || '1515783639890137198';
const client = new Client({ intents: [GatewayIntentBits.Guilds] });

client.once('clientReady', async () => {
  const guild = await client.guilds.fetch(GUILD_ID);
  const setup = getServerSetup(guild.id) || {};
  const civilRoleId = setup.civilRoleId;
  if (!civilRoleId) {
    console.error('Nėra civilRoleId setup DB — paleisk /panels gate');
    process.exit(1);
  }
  console.log('[no-gif] Civilis:', civilRoleId);
  const result = await applyCivilGatePermissions(guild, {
    civilRoleId,
    adminRoleIds: setup.adminRoleIds || [],
  });
  console.log('[no-gif] Kanalai:', result.updated.length);
  console.log('[no-gif] Rolės:', result.gifDeny?.roles);
  console.log('[no-gif] Klaidos:', result.gifDeny?.errors);
  process.exit(0);
});

client.login(env.token);
