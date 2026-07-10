import type { PixiStage } from '@/engine/pixi/stage';
import type { QualityTier, StationPayload } from '@/types/protocol';

export interface StageInfo {
  index: number;
  total: number;
  title: string;
  hint: string;
}

export interface StationResult {
  success: boolean;
  score: number;
  quality: QualityTier;
  mistakes: number;
}

export interface StationCallbacks {
  onStage: (info: StageInfo) => void;
  onScore: (score: number) => void;
  onFinish: (result: StationResult) => void;
}

export interface StationController {
  /** Player-confirmed cancel: resolve as failed and tear down. */
  cancel: () => void;
  /** Hard teardown (resource restart / close). No result emitted. */
  destroy: () => void;
}

export type StationFactory = (
  stage: PixiStage,
  payload: StationPayload,
  cb: StationCallbacks,
) => StationController;

/** Raised internally to unwind a stage sequence when a session is aborted. */
export class StationAbort extends Error {
  constructor() {
    super('station-abort');
    this.name = 'StationAbort';
  }
}
