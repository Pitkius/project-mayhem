import type { PerformanceCategory, PerformancePart, StatKey } from './types';

export function scoreForLevel(level: number, maxLevel: number): number {
  if (level < 0) return 38;
  const m = Math.max(1, maxLevel);
  return Math.round(38 + ((level + 1) / m) * 62);
}

export function statsForPart(cat: PerformanceCategory, part: PerformancePart): Partial<Record<StatKey, number>> {
  const score = scoreForLevel(part.idx, cat.maxLevel);
  const out: Partial<Record<StatKey, number>> = {};
  for (const k of cat.statKeys) out[k] = score;
  return out;
}

export function mergeStatKeys(categories: PerformanceCategory[]): StatKey[] {
  const set = new Set<StatKey>();
  categories.forEach((c) => c.statKeys.forEach((k) => set.add(k)));
  return Array.from(set);
}
