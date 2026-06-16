import { getGuildSettings } from '../database/sqlite.js';
import { appConfig } from '../config.js';

export function getAntinukeConfig(guildId) {
  const settings = getGuildSettings(guildId);
  const defaults = appConfig.defaultAntinuke || {};
  return {
    enabled: settings?.antinuke_enabled ?? defaults.enabled ?? true,
    punishment: settings?.antinuke?.punishment || defaults.punishment || 'ban',
    thresholds: {
      ...defaults.thresholds,
      ...(settings?.antinuke?.thresholds || {}),
    },
  };
}

export function getThreshold(config, key) {
  return config.thresholds?.[key] || { limit: 5, windowSec: 10 };
}
