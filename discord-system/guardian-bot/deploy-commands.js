import 'dotenv/config';
import { assertEnv } from './src/config.js';
import { loadCommandPayloads } from './src/commands/loadCommandPayloads.js';
import { REST, Routes } from 'discord.js';
import { env } from './src/config.js';

assertEnv();

const commands = await loadCommandPayloads();
const rest = new REST({ version: '10' }).setToken(env.token);

try {
  if (env.guildId) {
    await rest.put(Routes.applicationGuildCommands(env.clientId, env.guildId), { body: commands });
    console.log(`Deployed ${commands.length} guild commands to ${env.guildId}.`);
  } else {
    await rest.put(Routes.applicationCommands(env.clientId), { body: commands });
    console.log(`Deployed ${commands.length} global commands.`);
  }
  console.log(commands.map((c) => c.name).sort().join(', '));
} catch (err) {
  if (env.guildId && err.code === 50001) {
    console.warn('Bot not in guild yet — deploying global commands instead.');
    await rest.put(Routes.applicationCommands(env.clientId), { body: commands });
    console.log(`Deployed ${commands.length} global commands.`);
  } else {
    throw err;
  }
}
