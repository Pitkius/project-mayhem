import { EmbedBuilder } from 'discord.js';
import { BOT_BRAND } from '../utils/branding.js';
import { serverConfig } from './config.js';

export function modernEmbed(title, description, extra = {}) {
  const embed = new EmbedBuilder()
    .setColor(serverConfig.embedColor)
    .setTitle(title)
    .setDescription(description || '—')
    .setTimestamp()
    .setFooter({ text: BOT_BRAND.footer });

  if (extra.fields?.length) embed.addFields(extra.fields);
  if (extra.thumbnail) embed.setThumbnail(extra.thumbnail);
  if (extra.image) embed.setImage(extra.image);
  return embed;
}

export function sectionEmbed(title, lines = []) {
  return modernEmbed(title, lines.filter(Boolean).join('\n'));
}

export function rulesEmbed(title, body) {
  return modernEmbed(
    title,
    [
      body,
      '',
      '_Šis tekstas — placeholder. Administratorius gali jį redaguoti._',
    ].join('\n'),
  );
}

export function ipEmbed() {
  const addr = serverConfig.serverConnectAddress || 'SERVERIO_ADRESAS';
  const connect = `connect ${addr}`;
  return modernEmbed(
    `${serverConfig.serverName} · Prisijungimas`,
    [
      '**Kaip prisijungti**',
      '1. Atidaryk FiveM',
      '2. Spausk `F8`',
      '3. Įklijuok komandą žemiau ir Enter',
      '',
      `**Serveris:** ${serverConfig.serverName}`,
      `**Adresas:** \`${addr}\``,
      `**Komanda:**`,
      `\`\`\`\n${connect}\n\`\`\``,
    ].join('\n'),
  );
}

export function rolePickerEmbed() {
  return modernEmbed(
    'Pasirink savo roles',
    [
      'Pasirink roles žemiau esančiame meniu.',
      '',
      '**Civilis** — pagrindinė nario rolė (mato bendruomenę).',
      '**Naujienų ping** — pranešimai apie naujienas.',
      '**Atnaujinimų ping** — serverio atnaujinimai.',
      '**Eventų ping** — eventai ir renginiai.',
      '',
      'Pasirinkimas vėl — rolė įjungiama / išjungiama.',
      'Administracijos ir frakcijų rolių čia pasirinkti negalima.',
    ].join('\n'),
  );
}

export function ticketPanelEmbed() {
  return modernEmbed(
    'Pagalba · Ticketai',
    [
      'Pasirink kategoriją ir sukursime privatų ticket kanalą.',
      '',
      'Ticketą matys **tik tu**, administracija ir botas.',
      'Nenaudok ticketų be reikalo — turime limitą aktyvių ticketų vienam nariui.',
    ].join('\n'),
  );
}

export function factionInfoEmbed(label, url) {
  const link = url
    ? `[Atidaryti frakcijos Discord](${url})`
    : '_Frakcijos Discord nuoroda dar nenustatyta (konfigūracija)._';
  return modernEmbed(
    `${label}`,
    [
      `Privatus **${label}** kanalas tarnybos nariams.`,
      '',
      '**Kas čia:**',
      '• Trumpa informacija',
      '• Nedidelis vidinis pokalbis',
      '• Nuoroda į atskirą frakcijos Discord',
      '',
      link,
    ].join('\n'),
  );
}
