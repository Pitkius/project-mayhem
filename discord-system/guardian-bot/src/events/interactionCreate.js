import { Events } from 'discord.js';
import { handleRolePickerSelect } from '../roles/picker.js';
import { handleTicketSelect, handleTicketButton } from '../tickets/panel.js';
import {
  handleApplicationButton,
  handleApplicationModal,
} from '../applications/panel.js';
import { handleSetupInteraction } from '../commands/setup-server.js';

export default {
  name: Events.InteractionCreate,
  async execute(interaction, client) {
    try {
      if (interaction.isChatInputCommand()) {
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
        await command.execute(interaction);
        return;
      }

      if (interaction.isModalSubmit()) {
        if (await handleApplicationModal(interaction)) return;
        return;
      }

      if (interaction.isStringSelectMenu()) {
        if (await handleSetupInteraction(interaction)) return;
        if (await handleRolePickerSelect(interaction)) return;
        if (await handleTicketSelect(interaction)) return;
        return;
      }

      if (interaction.isButton()) {
        if (await handleSetupInteraction(interaction)) return;
        if (await handleApplicationButton(interaction)) return;
        if (await handleTicketButton(interaction)) return;
      }
    } catch (err) {
      console.error('[Interaction]', err);
      const msg = { content: 'Veiksmas nepavyko.', ephemeral: true };
      if (interaction.replied || interaction.deferred) {
        await interaction.followUp(msg).catch(() => null);
      } else {
        await interaction.reply(msg).catch(() => null);
      }
    }
  },
};
