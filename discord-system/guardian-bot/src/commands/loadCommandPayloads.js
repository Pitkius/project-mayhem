import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export async function loadCommandPayloads() {
  const commandsPath = path.join(__dirname);
  const files = fs.readdirSync(commandsPath).filter((f) => f.endsWith('.js') && f !== 'loadCommandPayloads.js');

  const commands = [];
  for (const file of files) {
    const mod = await import(pathToFileURL(path.join(commandsPath, file)).href);
    if (mod.default?.data) {
      commands.push(mod.default.data.toJSON());
    }
  }
  return commands;
}
