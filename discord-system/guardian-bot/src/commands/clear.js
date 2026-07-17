import { SlashCommandBuilder, PermissionFlagsBits, ChannelType } from 'discord.js';
import { sendModLog } from '../logs/dispatcher.js';
import { isAdmin } from '../utils/permissions.js';

const MAX_PER_BULK = 100;
const MAX_FULL_CLEAR_LOOPS = 50; // iki ~5000 žinučių (14 d. limito)

async function deleteMessages(channel, targetAmount) {
  let deletedTotal = 0;
  let remaining = targetAmount;
  let loops = 0;

  while (remaining > 0 && loops < MAX_FULL_CLEAR_LOOPS) {
    loops += 1;
    const batch = Math.min(MAX_PER_BULK, remaining);
    const deleted = await channel.bulkDelete(batch, true).catch(() => null);
    const count = deleted?.size || 0;
    deletedTotal += count;
    remaining -= count;
    if (count === 0) break;
    // Trumpa pauzė tarp batch'ų, kad Discord rate limit'as neuzsirakintų
    if (remaining > 0) await new Promise((r) => setTimeout(r, 800));
  }

  return deletedTotal;
}

export default {
  data: new SlashCommandBuilder()
    .setName('clear')
    .setDescription('Išvalo chatą (tik adminams). Be kiekio — visas kanalas, su kiekiu — tiek žinučių.')
    .addIntegerOption((o) =>
      o
        .setName('kiekis')
        .setDescription('Kiek žinučių ištrinti (pvz. 1). Jei nenurodyta — valoma viskas.')
        .setRequired(false)
        .setMinValue(1)
        .setMaxValue(5000),
    )
    .setDefaultMemberPermissions(PermissionFlagsBits.Administrator)
    .setDMPermission(false),

  async execute(interaction) {
    if (!isAdmin(interaction.member)) {
      return interaction.reply({ content: 'Šią komandą gali naudoti tik administratoriai.', ephemeral: true });
    }

    const channel = interaction.channel;
    if (!channel || !channel.isTextBased?.() || channel.type === ChannelType.DM) {
      return interaction.reply({ content: 'Šioje vietoje chat išvalyti negalima.', ephemeral: true });
    }
    if (!channel.bulkDelete) {
      return interaction.reply({ content: 'Šiame kanale bulk delete nepalaikomas.', ephemeral: true });
    }

    const amount = interaction.options.getInteger('kiekis');
    const fullClear = amount == null;

    await interaction.deferReply({ ephemeral: true });

    const target = fullClear ? MAX_PER_BULK * MAX_FULL_CLEAR_LOOPS : amount;
    const deletedTotal = await deleteMessages(channel, target);

    await sendModLog(
      interaction.guild,
      'Clear',
      fullClear
        ? `Pilnas clear: ${deletedTotal} žinučių kanale ${channel}`
        : `${deletedTotal}/${amount} žinučių kanale ${channel}`,
      [{ name: 'Admin', value: `${interaction.user}`, inline: true }],
    );

    const note = deletedTotal === 0
      ? ' Nieko neištrinta (senesnės nei 14 d. žinutės Discord API neleidžia trinti masiškai).'
      : '';

    await interaction.editReply({
      content: fullClear
        ? `Chato clear baigtas. Ištrinta: **${deletedTotal}**.${note}`
        : `Ištrinta: **${deletedTotal}** žinučių.${note}`,
    });
  },
};
