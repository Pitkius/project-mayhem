import type { PixiStage } from '@/engine/pixi/stage';
import type { StationPayload } from '@/types/protocol';
import type { StationCallbacks, StationController } from '../types';
import { createStationRuntime, runSequence } from '../shared/createRuntime';
import { mushroomStages } from './scenes';

export function runMushroomStation(
  stage: PixiStage,
  payload: StationPayload,
  cb: StationCallbacks,
): StationController {
  const { rt, controller } = createStationRuntime(stage, 'mushroom', cb);
  void runSequence(rt, mushroomStages(rt, payload.mode, payload.quantity ?? 1));
  return controller();
}
