import { DESIGN_W, DESIGN_H } from '@/engine/pixi/stage';
import * as P from '@/engine/pixi/props';
import * as S from '../shared/commonStages';
import type { StationRuntime } from '../shared/createRuntime';

export function heroinStages(rt: StationRuntime, mode: string, qty: number) {
  const t = rt.theme;
  if (mode === 'heroin_fold') {
    return [
      () => stageFold(rt, t.accent),
      () => stageSealFoil(rt, t.accent),
      () => stagePackFoil(rt, qty, t.accent2),
    ];
  }
  return [
    () => stagePrep(rt, t.accent),
    () => stageFilter(rt, t),
    () => stageStabilize(rt, t.accent2),
  ];
}

function stagePrep(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 3, title: 'Paruošk įrangą', hint: 'Aktyvuok komponentus seka' });
  P.drawHeroinTray(rt.layer, DESIGN_W * 0.35, DESIGN_H * 0.28);
  return S.tapSequence(rt, { index: 1, total: 3, title: '', hint: '' }, 3, accent);
}

function stageFilter(rt: StationRuntime, theme: typeof rt.theme): Promise<number> {
  rt.cb.onStage({ index: 2, total: 3, title: 'Filtravimas', hint: 'Laikyk srautą saugioje zonoje' });
  P.drawHeroinTray(rt.layer, DESIGN_W * 0.35, DESIGN_H * 0.28);
  P.animateSteam(rt.layer, DESIGN_W * 0.5, DESIGN_H * 0.35, theme.particle, 4);
  return S.holdGauge(rt, { index: 2, total: 3, title: '', hint: '' }, 4200, theme.accent, { drift: 0.36, zoneW: 0.17 });
}

function stageStabilize(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 3, total: 3, title: 'Stabilizavimas', hint: 'Išlaikyk stabilumą' });
  return S.holdGauge(rt, { index: 3, total: 3, title: '', hint: '' }, 3500, accent, { zoneW: 0.16 });
}

function stageFold(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 3, title: 'Sulankstyk foliją', hint: 'Spausk lankstymui' });
  P.drawFoilPouch(rt.layer, DESIGN_W * 0.45, DESIGN_H * 0.35);
  return S.multiTapSeal(rt, { index: 1, total: 3, title: '', hint: '' }, 4, accent);
}

function stageSealFoil(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 3, title: 'Užlydink maišelį', hint: 'Laikyk temperatūrą' });
  return S.holdGauge(rt, { index: 2, total: 3, title: '', hint: '' }, 2600, accent);
}

function stagePackFoil(rt: StationRuntime, qty: number, accent: number): Promise<number> {
  rt.cb.onStage({ index: 3, total: 3, title: 'Supakuok', hint: '' });
  return S.packIntoBox(rt, { index: 3, total: 3, title: '', hint: '' }, qty, accent);
}
