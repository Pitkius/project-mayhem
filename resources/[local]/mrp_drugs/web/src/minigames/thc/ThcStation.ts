import type { PixiStage } from '@/engine/pixi/stage';
import type { StationPayload } from '@/types/protocol';
import type { StationCallbacks, StationController } from '../types';
import { createStationRuntime, runSequence } from '../shared/createRuntime';
import { thcStages } from './scenes';

export function runThcStation(
  stage: PixiStage,
  payload: StationPayload,
  cb: StationCallbacks,
): StationController {
  const { rt, controller } = createStationRuntime(stage, 'thc', cb);
  void runSequence(rt, thcStages(rt, payload.mode, payload.quantity ?? 1));
  return controller();
}
