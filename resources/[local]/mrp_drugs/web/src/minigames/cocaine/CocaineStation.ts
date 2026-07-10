import type { PixiStage } from '@/engine/pixi/stage';
import type { StationPayload } from '@/types/protocol';
import type { StationCallbacks, StationController } from '../types';
import { createStationRuntime, runSequence } from '../shared/createRuntime';
import { cocaineStages } from './scenes';

export function runCocaineStation(
  stage: PixiStage,
  payload: StationPayload,
  cb: StationCallbacks,
): StationController {
  const { rt, controller } = createStationRuntime(stage, 'cocaine', cb);
  void runSequence(rt, cocaineStages(rt, payload.mode, payload.quantity ?? 1));
  return controller();
}
