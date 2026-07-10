import { Graphics } from 'pixi.js';
import * as P from '@/engine/pixi/props';
import * as S from '../shared/commonStages';
import type { StationRuntime } from '../shared/createRuntime';
import { DESIGN_W, DESIGN_H } from '@/engine/pixi/stage';

export function methStages(rt: StationRuntime, mode: string, qty: number) {
  const t = rt.theme;
  if (mode === 'meth_crush_pack') {
    return [
      () => stageCrush(rt, t.accent),
      () => stageDose(rt, t.accent),
      () => stagePack(rt, qty, t.accent),
    ];
  }
  return [
    () => stageCrystal1(rt, t),
    () => stageCrystal2(rt, t),
    () => stageFinish(rt, t.accent),
  ];
}

function stageCrystal1(rt: StationRuntime, theme: typeof rt.theme): Promise<number> {
  rt.cb.onStage({ index: 1, total: 3, title: 'Kristalizacija I', hint: 'Laikyk temperatūrą' });
  P.drawMethFlask(rt.layer, DESIGN_W * 0.42, DESIGN_H * 0.2, theme.accent);
  return S.holdGauge(rt, { index: 1, total: 3, title: '', hint: '' }, 3500, theme.accent);
}

function stageCrystal2(rt: StationRuntime, theme: typeof rt.theme): Promise<number> {
  rt.cb.onStage({ index: 2, total: 3, title: 'Kristalizacija II', hint: 'Laikyk slėgį' });
  const flask = P.drawMethFlask(rt.layer, DESIGN_W * 0.42, DESIGN_H * 0.2, theme.accent);
  const crystals = flask.children.find((c) => (c as Graphics).label === 'crystals');
  if (crystals) P.animateSpin(crystals, 4);
  return S.holdGauge(rt, { index: 2, total: 3, title: '', hint: '' }, 3500, theme.accent2, { drift: 0.35 });
}

function stageFinish(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 3, total: 3, title: 'Užbaik procesą', hint: 'Kontrolės taškai' });
  return S.tapSequence(rt, { index: 3, total: 3, title: '', hint: '' }, 3, accent);
}

function stageCrush(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 3, title: 'Sutraišk kristalus', hint: 'SPACE ritmu' });
  P.drawMethFlask(rt.layer, DESIGN_W * 0.42, DESIGN_H * 0.22, accent);
  return S.rhythmTaps(rt, { index: 1, total: 3, title: '', hint: '' }, 4, accent);
}

function stageDose(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 3, title: 'Sverk ir dozuok', hint: 'Sustok žaliame lange' });
  return S.fillBand(rt, { index: 2, total: 3, title: '', hint: '' }, { color: accent });
}

function stagePack(rt: StationRuntime, qty: number, accent: number): Promise<number> {
  rt.cb.onStage({ index: 3, total: 3, title: 'Supakuok', hint: '' });
  return S.packIntoBox(rt, { index: 3, total: 3, title: '', hint: '' }, qty, accent);
}
