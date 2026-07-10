import type { DrugId } from '@/types/protocol';

/** Aligns with html/minigame-ui.js THEMES — Mayhem underground workstation palette. */
export interface DrugTheme {
  id: DrugId;
  label: string;
  accent: number;
  accent2: number;
  glow: number;
  bgTop: number;
  bgBottom: number;
  table: number;
  tableEdge: number;
  light: number;
  particle: number;
  /** Atmosphere flavour key */
  mood: 'neon_lab' | 'copper_still' | 'clean_cyan' | 'organic' | 'dirty_warm' | 'cold_lux' | 'electric' | 'crystal' | 'pharma' | 'forest';
  ambient: 'hum' | 'bubble' | 'organic' | 'drip' | 'static' | 'fan' | 'crackle';
}

function hex(h: string): number {
  return parseInt(h.replace('#', ''), 16);
}

export const DRUG_THEMES: Record<DrugId, DrugTheme> = {
  thc: {
    id: 'thc', label: 'THC', accent: hex('#a78bfa'), accent2: hex('#7c3aed'), glow: hex('#a78bfa'),
    bgTop: 0x1a1030, bgBottom: 0x0a0614, table: 0x2a2240, tableEdge: 0x1a1430,
    light: hex('#a78bfa'), particle: hex('#c4b5fd'), mood: 'neon_lab', ambient: 'hum',
  },
  alcohol: {
    id: 'alcohol', label: 'Samagonas', accent: hex('#fbbf24'), accent2: hex('#d97706'), glow: hex('#fbbf24'),
    bgTop: 0x1f1408, bgBottom: 0x0c0804, table: 0x3d2e1a, tableEdge: 0x2a1f10,
    light: hex('#fbbf24'), particle: hex('#fcd34d'), mood: 'copper_still', ambient: 'bubble',
  },
  vape: {
    id: 'vape', label: 'Vape', accent: hex('#67e8f9'), accent2: hex('#0891b2'), glow: hex('#67e8f9'),
    bgTop: 0x0c1a22, bgBottom: 0x040a10, table: 0x1a2a32, tableEdge: 0x0f1a20,
    light: hex('#67e8f9'), particle: hex('#a5f3fc'), mood: 'clean_cyan', ambient: 'bubble',
  },
  weed: {
    id: 'weed', label: 'Kanapės', accent: hex('#4ade80'), accent2: hex('#16a34a'), glow: hex('#4ade80'),
    bgTop: 0x0f1a12, bgBottom: 0x060c08, table: 0x2a3d28, tableEdge: 0x1a2818,
    light: hex('#4ade80'), particle: hex('#86efac'), mood: 'organic', ambient: 'organic',
  },
  heroin: {
    id: 'heroin', label: 'Heroinas', accent: hex('#f87171'), accent2: hex('#dc2626'), glow: hex('#f87171'),
    bgTop: 0x1a0c0c, bgBottom: 0x0a0404, table: 0x3a2820, tableEdge: 0x281810,
    light: hex('#f87171'), particle: hex('#fca5a5'), mood: 'dirty_warm', ambient: 'drip',
  },
  cocaine: {
    id: 'cocaine', label: 'Kokainas', accent: hex('#e2e8f0'), accent2: hex('#64748b'), glow: hex('#cbd5e1'),
    bgTop: 0x141820, bgBottom: 0x080a10, table: 0x2a3038, tableEdge: 0x1a2028,
    light: hex('#e2e8f0'), particle: hex('#f1f5f9'), mood: 'cold_lux', ambient: 'static',
  },
  amp: {
    id: 'amp', label: 'Amfetaminas', accent: hex('#fde047'), accent2: hex('#ca8a04'), glow: hex('#fde047'),
    bgTop: 0x1a1808, bgBottom: 0x0a0804, table: 0x2a2818, tableEdge: 0x1a1810,
    light: hex('#fde047'), particle: hex('#fef08a'), mood: 'electric', ambient: 'crackle',
  },
  meth: {
    id: 'meth', label: 'Metas', accent: hex('#38bdf8'), accent2: hex('#0284c7'), glow: hex('#38bdf8'),
    bgTop: 0x0a1420, bgBottom: 0x040810, table: 0x1a2838, tableEdge: 0x101820,
    light: hex('#38bdf8'), particle: hex('#7dd3fc'), mood: 'crystal', ambient: 'fan',
  },
  pills: {
    id: 'pills', label: 'Tabletės', accent: hex('#fb923c'), accent2: hex('#ea580c'), glow: hex('#fb923c'),
    bgTop: 0x1a1008, bgBottom: 0x0a0804, table: 0xeee8e0, tableEdge: 0xc8c0b8,
    light: hex('#fb923c'), particle: hex('#fdba74'), mood: 'pharma', ambient: 'hum',
  },
  mushroom: {
    id: 'mushroom', label: 'Grybai', accent: hex('#c084fc'), accent2: hex('#9333ea'), glow: hex('#c084fc'),
    bgTop: 0x140c1a, bgBottom: 0x08040c, table: 0x2a2030, tableEdge: 0x1a1020,
    light: hex('#c084fc'), particle: hex('#d8b4fe'), mood: 'forest', ambient: 'organic',
  },
};

export function themeFor(drug: DrugId): DrugTheme {
  return DRUG_THEMES[drug] ?? DRUG_THEMES.thc;
}
