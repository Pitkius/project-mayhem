import { SlashCommandBuilder, PermissionFlagsBits } from 'discord.js';
import { addWhitelist, removeWhitelist, listWhitelist } from '../database/sqlite.js';
import { isAdmin } from '../utils/permissions.js';

export default {
  data: new SlashCommandBuilder()
    .setName('whitelist')
    .setDescription('Valdo anti-nuke whitelist')
    .addSubcommand((sub) => sub.setName('add').setDescription('Pridėti')
      .addStringOption((o) => o.setName('target_id').setDescription('User/Role ID').setRequired(true))
      .addStringOption((o) => o.setName('type').setDescription('Tipas').setRequired(true)
        .addChoices({ name: 'user', value: 'user' }, { name: 'role', value: 'role' }, { name: 'bot', value: 'bot' }))
      .addStringOption((o) => o.setName('note').setDescription('Pastaba')))
    .addSubcommand((sub) => sub.setName('remove').setDescription('Pašalinti')
      .addStringOption((o) => o.setName('target_id').setDescription('ID').setRequired(true))
      .addStringOption((o) => o.setName('type').setDescription('Tipas').setRequired(true)
        .addChoices({ name: 'user', value: 'user' }, { name: 'role', value: 'role' }, { name: 'bot', value: 'bot' })))
    .addSubcommand((sub) => sub.setName('list').setDescription('Sąrašas'))
    .setDefaultMemberPermissions(PermissionFlagsBits.Administrator),
  async execute(interaction) {
    if (!isAdmin(interaction.member)) {
      return interaction.reply({ content: 'Neturi teisių.', ephemeral: true });
    }

    const sub = interaction.options.getSubcommand();

    if (sub === 'add') {
      const id = interaction.options.getString('target_id', true);
      const type = interaction.options.getString('type', true);
      const note = interaction.options.getString('note') || '';
      addWhitelist(interaction.guildId, id, type, interaction.user.id, note);
      return interaction.reply({ content: `Whitelist: ${type} \`${id}\` pridėtas.`, ephemeral: true });
    }

    if (sub === 'remove') {
      const id = interaction.options.getString('target_id', true);
      const type = interaction.options.getString('type', true);
      removeWhitelist(interaction.guildId, id, type);
      return interaction.reply({ content: `Whitelist: ${type} \`${id}\` pašalintas.`, ephemeral: true });
    }

    const rows = listWhitelist(interaction.guildId);
    if (!rows.length) {
      return interaction.reply({ content: 'Whitelist tuščias.', ephemeral: true });
    }
    const text = rows.map((r) => `• ${r.target_type} \`${r.target_id}\` — ${r.note || '—'}`).join('\n');
    return interaction.reply({ content: text.slice(0, 1900), ephemeral: true });
  },
};
