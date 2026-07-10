import { Container } from 'pixi.js';
import gsap from 'gsap';
import { PixiStage } from '@/engine/pixi/stage';
import { buildDrugAtmosphere } from '@/engine/pixi/atmosphere';
import { themeFor, type DrugTheme } from '@/config/drugThemes';
import type { DrugId } from '@/types/protocol';
import { ScoreTracker } from '@/config/quality';
import { Audio } from '@/engine/audio/audio';
import type { Disposer } from '@/engine/input/input';
import { StationAbort, type StationCallbacks, type StationController } from '../types';

export interface StationRuntime {
  layer: Container;
  stage: PixiStage;
  tracker: ScoreTracker;
  theme: DrugTheme;
  cb: StationCallbacks;
  aborted: boolean;
  finished: boolean;
  addDisposer: (d: Disposer) => void;
  cleanup: () => void;
  abortGuard: () => void;
  finish: (success: boolean) => void;
}

export function createStationRuntime(
  stage: PixiStage,
  drug: DrugId,
  cb: StationCallbacks,
): { rt: StationRuntime; controller: () => StationController } {
  const theme = themeFor(drug);
  const disposers: Disposer[] = [];
  let aborted = false;
  let finished = false;
  const tracker = new ScoreTracker();

  const atmo = buildDrugAtmosphere(stage.world, theme);
  const offAtmo = stage.onTick((dt) => atmo.tick(dt));
  disposers.push(offAtmo);
  disposers.push(() => atmo.destroy());

  Audio.startAmbient(theme.ambient);

  const addDisposer = (d: Disposer) => disposers.push(d);

  const cleanup = () => {
    disposers.splice(0).forEach((d) => {
      try { d(); } catch { /* ignore */ }
    });
    Audio.stopAmbient();
    gsap.globalTimeline.getChildren().forEach((t) => t.kill());
  };

  const abortGuard = () => {
    if (aborted) throw new StationAbort();
  };

  const finish = (success: boolean) => {
    if (finished) return;
    finished = true;
    const score = success ? tracker.score() : Math.min(tracker.score(), 35);
    cleanup();
    cb.onFinish({
      success,
      score,
      quality: tracker.quality(),
      mistakes: tracker.mistakes,
    });
  };

  const rt: StationRuntime = {
    layer: atmo.layer,
    stage,
    tracker,
    theme,
    cb,
    get aborted() { return aborted; },
    set aborted(v: boolean) { aborted = v; },
    get finished() { return finished; },
    set finished(v: boolean) { finished = v; },
    addDisposer,
    cleanup,
    abortGuard,
    finish,
  };

  const controller = (): StationController => ({
    cancel: () => {
      if (finished) return;
      finished = true;
      aborted = true;
      cleanup();
      cb.onFinish({ success: false, score: 0, quality: 'poor', mistakes: tracker.mistakes });
    },
    destroy: () => {
      aborted = true;
      finished = true;
      cleanup();
    },
  });

  return { rt, controller };
}

export function watchAbort(rt: StationRuntime, reject: (e: StationAbort) => void) {
  const iv = window.setInterval(() => {
    if (rt.aborted) {
      window.clearInterval(iv);
      reject(new StationAbort());
    }
  }, 200);
  rt.addDisposer(() => window.clearInterval(iv));
}

export async function runSequence(
  rt: StationRuntime,
  steps: Array<() => Promise<number>>,
) {
  try {
    rt.abortGuard();
    for (const step of steps) {
      rt.tracker.addStage(await step());
      rt.cb.onScore(rt.tracker.score());
      rt.abortGuard();
    }
    rt.finish(true);
  } catch (err) {
    if (err instanceof StationAbort) return;
    console.error('[Station] error', err);
    rt.finish(false);
  }
}
