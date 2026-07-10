import { create } from 'zustand';
import type { QualityTier, StationPayload } from '@/types/protocol';

// Explicit UI states as required by the design brief.
export type UiState =
  | 'CLOSED'
  | 'LOADING'
  | 'READY'
  | 'INTRO'
  | 'PLAYING'
  | 'PAUSED'
  | 'SUCCESS'
  | 'PARTIAL_SUCCESS'
  | 'FAILED'
  | 'CANCEL_CONFIRMATION'
  | 'CLOSING'
  | 'ERROR';

export interface StageInfo {
  index: number;
  total: number;
  title: string;
  hint: string;
}

interface MachineState {
  ui: UiState;
  payload: StationPayload | null;
  stage: StageInfo;
  score: number;
  quality: QualityTier | null;
  mistakes: number;
  errorMessage: string | null;

  setUi: (ui: UiState) => void;
  startSession: (payload: StationPayload) => void;
  setStage: (stage: Partial<StageInfo>) => void;
  setScore: (score: number) => void;
  setOutcome: (o: { score: number; quality: QualityTier; mistakes: number }) => void;
  setError: (msg: string) => void;
  reset: () => void;
}

const DEFAULT_STAGE: StageInfo = { index: 1, total: 1, title: '', hint: '' };

export const useMachine = create<MachineState>((set) => ({
  ui: 'CLOSED',
  payload: null,
  stage: DEFAULT_STAGE,
  score: 0,
  quality: null,
  mistakes: 0,
  errorMessage: null,

  setUi: (ui) => set({ ui }),
  startSession: (payload) =>
    set({
      payload,
      ui: 'LOADING',
      stage: DEFAULT_STAGE,
      score: 0,
      quality: null,
      mistakes: 0,
      errorMessage: null,
    }),
  setStage: (stage) => set((s) => ({ stage: { ...s.stage, ...stage } })),
  setScore: (score) => set({ score }),
  setOutcome: (o) => set({ score: o.score, quality: o.quality, mistakes: o.mistakes }),
  setError: (msg) => set({ ui: 'ERROR', errorMessage: msg }),
  reset: () =>
    set({
      ui: 'CLOSED',
      payload: null,
      stage: DEFAULT_STAGE,
      score: 0,
      quality: null,
      mistakes: 0,
      errorMessage: null,
    }),
}));
