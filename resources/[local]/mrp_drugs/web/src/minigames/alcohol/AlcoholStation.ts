import type { PixiStage } from '@/engine/pixi/stage';
import type { StationPayload } from '@/types/protocol';
import type { StationCallbacks, StationController } from '../types';
import { createStationRuntime, runSequence } from '../shared/createRuntime';
import { alcoholStages } from './scenes';

export function runAlcoholStation(
  stage: PixiStage,
  payload: StationPayload,
  cb: StationCallbacks,
): StationController {
  const { rt, controller } = createStationRuntime(stage, 'alcohol', cb);
  void runSequence(rt, alcoholStages(rt, payload.mode, payload.quantity ?? 1));
  return controller();
}
