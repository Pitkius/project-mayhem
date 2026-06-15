import 'dotenv/config';
import { REST, Routes } from 'discord.js';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { env, assertEnv } from './src/config.js';

assertEnv();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const commandsPath = path.join(__dirname, 'src', 'commands');
const files = fs.readdirSync(commandsPath).filter((f) => f.endsWith('.js'));

const commands = [];
for (const file of files) {
  const mod = await import(pathToFileURL(path.join(commandsPath, file)).href);
  if (mod.default?.data) commands.push(mod.default.data.toJSON());
}

const rest = new REST({ version: '10' }).setToken(env.token);

try {
  if (env.guildId) {
    await rest.put(Routes.applicationGuildCommands(env.clientId, env.guildId), { body: commands });
    console.log(`Deployed ${commands.length} guild commands.`);
  } else {
    await rest.put(Routes.applicationCommands(env.clientId), { body: commands });
    console.log(`Deployed ${commands.length} global commands.`);
  }
} catch (err) {
  if (env.guildId && err.code === 50001) {
    console.warn('Bot not in guild yet — deploying global commands instead.');
    await rest.put(Routes.applicationCommands(env.clientId), { body: commands });
    console.log(`Deployed ${commands.length} global commands.`);
  } else {
    throw err;
  }
}
