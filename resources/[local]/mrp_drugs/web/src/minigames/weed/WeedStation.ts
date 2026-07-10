import type { PixiStage } from '@/engine/pixi/stage';
import type { StationPayload } from '@/types/protocol';
import type { StationCallbacks, StationController } from '../types';
import { createStationRuntime, runSequence } from '../shared/createRuntime';
import { weedStages } from './scenes';

export function runWeedStation(
  stage: PixiStage,
  payload: StationPayload,
  cb: StationCallbacks,
): StationController {
  const { rt, controller } = createStationRuntime(stage, 'weed', cb);
  void runSequence(rt, weedStages(rt, payload.mode, payload.quantity ?? 1));
  return controller();
}
