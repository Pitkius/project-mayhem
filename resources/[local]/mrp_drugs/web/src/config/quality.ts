import type { QualityTier } from '@/types/protocol';

// Single source of truth for score -> quality mapping on the CLIENT side.
// NOTE: the server re-derives quality from the reported score independently,
// so this mapping is only for UI feedback. Keep thresholds in sync with the
// Lua side (server/main.lua qualityFromScore).
export const QUALITY_THRESHOLDS: { tier: QualityTier; min: number }[] = [
  { tier: 'excellent', min: 85 },
  { tier: 'good', min: 65 },
  { tier: 'medium', min: 40 },
  { tier: 'poor', min: 0 },
];

export function qualityFromScore(score: number): QualityTier {
  const s = Math.max(0, Math.min(100, Math.round(score)));
  for (const t of QUALITY_THRESHOLDS) {
    if (s >= t.min) return t.tier;
  }
  return 'poor';
}

export const QUALITY_LABEL: Record<QualityTier, string> = {
  poor: 'Prasta',
  medium: 'Vidutinė',
  good: 'Gera',
  excellent: 'Puiki',
};

export const QUALITY_COLOR: Record<QualityTier, number> = {
  poor: 0xef4444,
  medium: 0xf59e0b,
  good: 0x84cc16,
  excellent: 0x22d3ee,
};

/** Accumulates per-stage accuracy (0..1) into a final 0..100 score. */
export class ScoreTracker {
  private samples: number[] = [];
  public mistakes = 0;

  addStage(accuracy: number) {
    this.samples.push(Math.max(0, Math.min(1, accuracy)));
  }

  addMistake(n = 1) {
    this.mistakes += n;
  }

  score(): number {
    if (this.samples.length === 0) return 0;
    const avg = this.samples.reduce((a, b) => a + b, 0) / this.samples.length;
    const penalty = Math.min(0.35, this.mistakes * 0.05);
    return Math.round(Math.max(0, Math.min(1, avg - penalty)) * 100);
  }

  quality(): QualityTier {
    return qualityFromScore(this.score());
  }
}
