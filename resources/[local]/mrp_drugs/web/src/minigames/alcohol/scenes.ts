import { DESIGN_W, DESIGN_H } from '@/engine/pixi/stage';
import * as P from '@/engine/pixi/props';
import * as S from '../shared/commonStages';
import type { StationRuntime } from '../shared/createRuntime';
import { watchAbort } from '../shared/createRuntime';

export function alcoholStages(rt: StationRuntime, mode: string, qty: number) {
  const t = rt.theme;
  if (mode === 'moonshine_jar') {
    return [
      () => stageJarFill(rt, t.accent),
      () => stageCorkSeal(rt, t.accent),
      () => stageLabelPack(rt, qty, t.accent),
    ];
  }
  return [
    () => stageStillHeat(rt, t),
    () => stageCollectSpirit(rt, t.accent),
  ];
}

function stageStillHeat(rt: StationRuntime, theme: typeof rt.theme): Promise<number> {
  rt.cb.onStage({ index: 1, total: 2, title: 'Varinis distiliatorius', hint: 'Kaitink — laikyk temperatūrą žalioje zonoje' });
  const still = P.drawCopperStill(rt.layer, DESIGN_W * 0.38, DESIGN_H * 0.18, 1.1);
  P.animateSteam(rt.layer, DESIGN_W * 0.42, DESIGN_H * 0.22, theme.particle, 8);
  P.drawValve(rt.layer, DESIGN_W * 0.58, DESIGN_H * 0.35, theme.accent);
  P.drawValve(rt.layer, DESIGN_W * 0.68, DESIGN_H * 0.42, theme.accent2);
  return S.holdGauge(rt, { index: 1, total: 2, title: '', hint: '' }, 4500, theme.accent, { drift: 0.3, zoneW: 0.22 });
}

function stageCollectSpirit(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 2, title: 'Surink distiliatą', hint: 'Supilk į indą — sustok žaliame lange' });
  const jar = P.drawGlassJar(rt.layer, DESIGN_W * 0.55, DESIGN_H * 0.2, 140, accent);
  P.drawCopperStill(rt.layer, DESIGN_W * 0.22, DESIGN_H * 0.2, 0.7);
  return new Promise((resolve, reject) => {
    S.fillBand(rt, { index: 2, total: 2, title: '', hint: '' }, { color: accent, bandLo: 0.68, bandHi: 0.88 }).then((acc) => {
      P.setLiquidLevel(jar, 0.85, accent);
      resolve(acc);
    });
    watchAbort(rt, reject);
  });
}

function stageJarFill(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 3, title: 'Supilk į stiklainį', hint: 'Laikyk ir sustok žaliame lange' });
  const jar = P.drawGlassJar(rt.layer, DESIGN_W * 0.45, DESIGN_H * 0.18, 150, accent);
  return S.fillBand(rt, { index: 1, total: 3, title: '', hint: '' }, { color: accent });
}

function stageCorkSeal(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 3, title: 'Užkorkuok', hint: 'Paspausk kamščius teisinga seka' });
  P.drawGlassJar(rt.layer, DESIGN_W * 0.45, DESIGN_H * 0.18, 150, accent);
  return S.tapSequence(rt, { index: 2, total: 3, title: '', hint: '' }, 3, accent);
}

function stageLabelPack(rt: StationRuntime, qty: number, accent: number): Promise<number> {
  rt.cb.onStage({ index: 3, total: 3, title: 'Užlydink ir supakuok', hint: 'Išlaikyk sandarinimo slėgį' });
  return S.holdGauge(rt, { index: 3, total: 3, title: '', hint: '' }, 2200, accent).then((acc1) =>
    S.packIntoBox(rt, { index: 3, total: 3, title: 'Sudėk į dėžę', hint: '' }, qty, accent).then(
      (acc2) => (acc1 + acc2) / 2,
    ),
  );
}
