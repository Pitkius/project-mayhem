import { DESIGN_W, DESIGN_H } from '@/engine/pixi/stage';
import * as P from '@/engine/pixi/props';
import * as S from '../shared/commonStages';
import type { StationRuntime } from '../shared/createRuntime';

export function mushroomStages(rt: StationRuntime, mode: string, qty: number) {
  const t = rt.theme;
  if (mode === 'mushroom_harvest') {
    return [() => stageHarvest(rt, t.accent)];
  }
  if (mode === 'mushroom_jar') {
    return [
      () => stageFillJar(rt, t.accent),
      () => stageCap(rt, t.accent),
      () => stageSealJar(rt, t.accent),
    ];
  }
  return [
    () => stageBrush(rt, t.accent),
    () => stageDryPrep(rt, t.accent),
  ];
}

function stageHarvest(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 1, title: 'Grybų rinkimas', hint: 'Surink grybus laiku' });
  P.drawMushroomJar(rt.layer, DESIGN_W * 0.4, DESIGN_H * 0.25, accent);
  return S.catchFalling(rt, { index: 1, total: 1, title: '', hint: '' }, 5, 0xc084fc);
}

function stageBrush(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 2, title: 'Nuvalyk grybus', hint: 'Šepečiu per grybus' });
  P.drawMushroomJar(rt.layer, DESIGN_W * 0.38, DESIGN_H * 0.24, accent);
  return S.scrapeGrid(rt, { index: 1, total: 2, title: '', hint: '' }, { cols: 11, rows: 6, cellColor: 0x6b5344 });
}

function stageDryPrep(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 2, title: 'Paruošk džiovinimui', hint: 'Laikyk oro srautą' });
  return S.holdGauge(rt, { index: 2, total: 2, title: '', hint: '' }, 3200, 0xd4a574);
}

function stageFillJar(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 3, title: 'Supilk į stiklainį', hint: 'Sustok žaliame lange' });
  P.drawMushroomJar(rt.layer, DESIGN_W * 0.42, DESIGN_H * 0.2, accent);
  return S.fillBand(rt, { index: 1, total: 3, title: '', hint: '' }, { color: 0x8b7355 });
}

function stageCap(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 3, title: 'Užsukuvok dangtelį', hint: 'Paspausk seka' });
  return S.tapSequence(rt, { index: 2, total: 3, title: '', hint: '' }, 3, accent);
}

function stageSealJar(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 3, total: 3, title: 'Užsandarink', hint: 'Laikyk slėgį' });
  return S.holdGauge(rt, { index: 3, total: 3, title: '', hint: '' }, 2200, accent);
}
