import { Events } from 'discord.js';

export default {
  name: Events.InteractionCreate,
  async execute(interaction, client) {
    if (!interaction.isChatInputCommand()) return;

    const command = client.commands.get(interaction.commandName);
    if (!command) {
      console.warn(`[MRP] Nežinoma komanda: /${interaction.commandName}`);
      if (!interaction.replied && !interaction.deferred) {
        await interaction.reply({
          content: 'Komanda nerasta bote. Administratorius: perkrauk botą (`npm start`) arba paleisk `npm run deploy`.',
          ephemeral: true,
        }).catch(() => null);
      }
      return;
    }

    try {
      await command.execute(interaction);
    } catch (err) {
      console.error(`[Command] ${interaction.commandName}:`, err);
      const msg = { content: 'Komanda nepavyko.', ephemeral: true };
      if (interaction.replied || interaction.deferred) {
        await interaction.followUp(msg).catch(() => null);
      } else {
        await interaction.reply(msg).catch(() => null);
      }
    }
  },
};
