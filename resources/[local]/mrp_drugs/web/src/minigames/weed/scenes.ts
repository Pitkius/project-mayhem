import { DESIGN_W, DESIGN_H } from '@/engine/pixi/stage';
import * as P from '@/engine/pixi/props';
import * as S from '../shared/commonStages';
import type { StationRuntime } from '../shared/createRuntime';

export function weedStages(rt: StationRuntime, mode: string, qty: number) {
  const t = rt.theme;
  const map: Record<string, Array<() => Promise<number>>> = {
    weed_soil: [
      () => stageSoil(rt, t.accent),
      () => stageLevel(rt, t.accent),
    ],
    weed_seed: [
      () => stageSeed(rt, t.accent),
      () => stageMoisture(rt, t.accent),
      () => stageTamp(rt, t.accent),
    ],
    weed_water: [
      () => stageWater(rt, t.accent),
      () => stageMoistureHold(rt, t.accent),
    ],
    weed_harvest: [
      () => stageHarvest(rt, t.accent),
    ],
    weed_dry: [
      () => stageTrim(rt, t.accent),
      () => stageDry(rt, t.accent),
      () => stageSort(rt, t.accent),
    ],
    weed_pack: [
      () => stageSortPack(rt, t.accent),
      () => stageWeigh(rt, t.accent),
      () => stageSealBag(rt, t.accent),
      () => stageBagPack(rt, qty, t.accent),
    ],
  };
  return map[mode] ?? map.weed_pack;
}

function stageSoil(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 2, title: 'Žemės pylimas', hint: 'Pilk į puodą — sustok laiku' });
  P.drawGrowPot(rt.layer, DESIGN_W * 0.42, DESIGN_H * 0.2);
  return S.fillBand(rt, { index: 1, total: 2, title: '', hint: '' }, { color: 0x5c4033, bandLo: 0.65, bandHi: 0.85 });
}

function stageLevel(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 2, title: 'Sulygink paviršių', hint: 'Paspausk taškus seka' });
  return S.tapSequence(rt, { index: 2, total: 2, title: '', hint: '' }, 2, accent);
}

function stageSeed(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 3, title: 'Sėklų sodinimas', hint: 'Paspausk skylutes seka' });
  P.drawGrowPot(rt.layer, DESIGN_W * 0.42, DESIGN_H * 0.2);
  return S.tapSequence(rt, { index: 1, total: 3, title: '', hint: '' }, 3, accent);
}

function stageMoisture(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 3, title: 'Drėgmės balansas', hint: 'Laikyk indikatorių' });
  return S.holdGauge(rt, { index: 2, total: 3, title: '', hint: '' }, 2500, accent);
}

function stageTamp(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 3, total: 3, title: 'Prispausk žemę', hint: 'Tempk per paviršių' });
  return S.scrapeGrid(rt, { index: 3, total: 3, title: '', hint: '' }, { cols: 10, rows: 5, cellColor: 0x4a6741 });
}

function stageWater(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 2, title: 'Laistymas', hint: 'Neperlaistyk' });
  P.drawGrowPot(rt.layer, DESIGN_W * 0.42, DESIGN_H * 0.2);
  return S.fillBand(rt, { index: 1, total: 2, title: '', hint: '' }, { color: 0x38bdf8, bandLo: 0.7, bandHi: 0.88 });
}

function stageMoistureHold(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 2, title: 'Stabilizuok drėgmę', hint: 'Laikyk zonoje' });
  return S.holdGauge(rt, { index: 2, total: 2, title: '', hint: '' }, 2800, 0x38bdf8);
}

function stageHarvest(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 1, title: 'Derliaus nuėmimas', hint: 'Surink žiedus laiku' });
  P.drawGrowPot(rt.layer, DESIGN_W * 0.42, DESIGN_H * 0.15);
  return S.catchFalling(rt, { index: 1, total: 1, title: '', hint: '' }, 5, accent);
}

function stageTrim(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 3, title: 'Apdorok žaliavą', hint: 'Nuvalyk ant kilimėlio' });
  P.drawDryingRack(rt.layer, DESIGN_W * 0.35, DESIGN_H * 0.25, accent);
  return S.scrapeGrid(rt, { index: 1, total: 3, title: '', hint: '' }, { cellColor: 0x4a7c3f });
}

function stageDry(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 3, title: 'Džiovinimas', hint: 'Išlaikyk temperatūrą' });
  P.drawDryingRack(rt.layer, DESIGN_W * 0.35, DESIGN_H * 0.25, accent);
  return S.holdGauge(rt, { index: 2, total: 3, title: '', hint: '' }, 4000, 0xd97706);
}

function stageSort(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 3, total: 3, title: 'Rūšiuok', hint: 'Pasirink tinkamas dalis' });
  return S.pickGoodSpots(rt, { index: 3, total: 3, title: '', hint: '' }, 5, 2, accent);
}

function stageSortPack(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 4, title: 'Paruošk produktą', hint: 'Pašalink netinkamas dalis' });
  return S.pickGoodSpots(rt, { index: 1, total: 4, title: '', hint: '' }, 4, 3, accent);
}

function stageWeigh(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 4, title: 'Sverk ir dozuok', hint: 'SPACE tikslinėje zonoje' });
  return S.rhythmTaps(rt, { index: 2, total: 4, title: '', hint: '' }, 3, accent);
}

function stageSealBag(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 3, total: 4, title: 'Užsandarink maišelį', hint: 'Spausk sandarinimui' });
  return S.multiTapSeal(rt, { index: 3, total: 4, title: '', hint: '' }, 3, accent);
}

function stageBagPack(rt: StationRuntime, qty: number, accent: number): Promise<number> {
  rt.cb.onStage({ index: 4, total: 4, title: 'Supakuok', hint: '' });
  return S.packIntoBox(rt, { index: 4, total: 4, title: '', hint: '' }, qty, accent);
}
