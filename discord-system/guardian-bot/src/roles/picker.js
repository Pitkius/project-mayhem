import {
  ActionRowBuilder,
  StringSelectMenuBuilder,
  PermissionFlagsBits,
} from 'discord.js';
import { getRolePicker, setRolePicker } from '../database/sqlite.js';
import { rolePickerEmbed } from '../server/embeds.js';
import { serverConfig } from '../server/config.js';

export const ROLE_PICKER_CUSTOM_ID = 'mrp:roles:pick';

const COOLDOWN_MS = 2500;
const lastPick = new Map();

function buildOptions(ids) {
  const options = [];
  if (ids.civilRoleId) {
    options.push({
      label: 'Civilis',
      description: 'Pagrindinė nario rolė — matai bendruomenę',
      value: `civil:${ids.civilRoleId}`,
      emoji: '👤',
    });
  }
  if (ids.newsPingRoleId) {
    options.push({
      label: 'Naujienų ping',
      description: 'Pranešimai apie naujienas',
      value: `news:${ids.newsPingRoleId}`,
      emoji: '📢',
    });
  }
  if (ids.updatesPingRoleId) {
    options.push({
      label: 'Atnaujinimų ping',
      description: 'Serverio atnaujinimai',
      value: `updates:${ids.updatesPingRoleId}`,
      emoji: '🛠️',
    });
  }
  if (ids.eventsPingRoleId) {
    options.push({
      label: 'Eventų ping',
      description: 'Eventai ir renginiai',
      value: `events:${ids.eventsPingRoleId}`,
      emoji: '🎉',
    });
  }
  return options;
}

export async function postRolePicker(channel, ids = {}) {
  const resolved = {
    civilRoleId: ids.civilRoleId || serverConfig.civilRoleId,
    newsPingRoleId: ids.newsPingRoleId || serverConfig.newsPingRoleId,
    updatesPingRoleId: ids.updatesPingRoleId || serverConfig.updatesPingRoleId,
    eventsPingRoleId: ids.eventsPingRoleId || serverConfig.eventsPingRoleId,
  };

  const options = buildOptions(resolved);
  if (!options.length) {
    await channel.send({
      content: '⚠️ Role picker: nėra sukonfigūruotų rolių (Civilis / ping). Nustatyk `config.json` arba `/setup-server`.',
    }).catch(() => null);
    return false;
  }

  const existing = getRolePicker(channel.guild.id);
  if (existing?.messageId && existing?.channelId === channel.id) {
    const msg = await channel.messages.fetch(existing.messageId).catch(() => null);
    if (msg) {
      await msg.edit({
        embeds: [rolePickerEmbed()],
        components: [
          new ActionRowBuilder().addComponents(
            new StringSelectMenuBuilder()
              .setCustomId(ROLE_PICKER_CUSTOM_ID)
              .setPlaceholder('Pasirink rolę…')
              .setMinValues(1)
              .setMaxValues(1)
              .addOptions(options),
          ),
        ],
      }).catch(() => null);
      setRolePicker(channel.guild.id, { ...existing, ...resolved, options: options.map((o) => o.value) });
      return true;
    }
  }

  const message = await channel.send({
    embeds: [rolePickerEmbed()],
    components: [
      new ActionRowBuilder().addComponents(
        new StringSelectMenuBuilder()
          .setCustomId(ROLE_PICKER_CUSTOM_ID)
          .setPlaceholder('Pasirink rolę…')
          .setMinValues(1)
          .setMaxValues(1)
          .addOptions(options),
      ),
    ],
  });

  setRolePicker(channel.guild.id, {
    channelId: channel.id,
    messageId: message.id,
    ...resolved,
    options: options.map((o) => o.value),
  });
  return true;
}

export async function handleRolePickerSelect(interaction) {
  if (interaction.customId !== ROLE_PICKER_CUSTOM_ID) return false;

  const now = Date.now();
  const key = `${interaction.guildId}:${interaction.user.id}`;
  if (lastPick.has(key) && now - lastPick.get(key) < COOLDOWN_MS) {
    await interaction.reply({ content: 'Palauk sekundę…', ephemeral: true });
    return true;
  }
  lastPick.set(key, now);

  const value = interaction.values?.[0];
  if (!value || !value.includes(':')) {
    await interaction.reply({ content: 'Netinkamas pasirinkimas.', ephemeral: true });
    return true;
  }

  const [kind, roleId] = value.split(':');
  const allowedKinds = new Set(['civil', 'news', 'updates', 'events']);
  if (!allowedKinds.has(kind)) {
    await interaction.reply({ content: 'Šios rolės pasirinkti negalima.', ephemeral: true });
    return true;
  }

  const role = interaction.guild.roles.cache.get(roleId)
    || await interaction.guild.roles.fetch(roleId).catch(() => null);
  if (!role) {
    await interaction.reply({ content: 'Rolė nerasta. Administratorius turi perkonfigūruoti pickerį.', ephemeral: true });
    return true;
  }

  if (role.managed || role.permissions.has(PermissionFlagsBits.Administrator)) {
    await interaction.reply({ content: 'Ši rolė blokuota saugumo sumetimais.', ephemeral: true });
    return true;
  }

  const me = interaction.guild.members.me;
  if (!me?.permissions.has(PermissionFlagsBits.ManageRoles) || role.position >= me.roles.highest.position) {
    await interaction.reply({
      content: 'Botas negali valdyti šios rolės (pakelk boto rolę aukščiau).',
      ephemeral: true,
    });
    return true;
  }

  const member = interaction.member;
  const has = member.roles.cache.has(role.id);
  try {
    if (has) {
      await member.roles.remove(role.id, 'Role picker toggle');
      await interaction.reply({ content: `Nuimta: **${role.name}**`, ephemeral: true });
    } else {
      await member.roles.add(role.id, 'Role picker toggle');
      await interaction.reply({ content: `Pridėta: **${role.name}**`, ephemeral: true });
    }
  } catch (err) {
    await interaction.reply({
      content: `Nepavyko pakeisti rolės: ${err.message}`,
      ephemeral: true,
    });
  }
  return true;
}
