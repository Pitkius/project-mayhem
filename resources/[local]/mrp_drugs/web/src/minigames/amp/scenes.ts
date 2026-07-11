import { Graphics } from 'pixi.js';
import { DESIGN_W, DESIGN_H } from '@/engine/pixi/stage';
import * as P from '@/engine/pixi/props';
import * as S from '../shared/commonStages';
import type { StationRuntime } from '../shared/createRuntime';

export function ampStages(rt: StationRuntime, mode: string, qty: number) {
  const t = rt.theme;
  if (mode === 'amp_stamp') {
    return [
      () => stageStamp(rt, t.accent),
      () => stagePack(rt, qty, t.accent, 2),
    ];
  }
  return [
    () => stagePrep(rt, t),
    () => stageReact(rt, t),
    () => stagePack(rt, qty, t.accent, 3),
  ];
}

function stagePrep(rt: StationRuntime, theme: typeof rt.theme): Promise<number> {
  rt.cb.onStage({ index: 1, total: 3, title: 'Reaktoriaus paruošimas', hint: 'Aktyvuok modulius seka' });
  const reactor = P.drawAmpReactor(rt.layer, DESIGN_W * 0.35, DESIGN_H * 0.18, theme.accent);
  const screen = reactor.children.find((c) => (c as Graphics).label === 'screen') as Graphics | undefined;
  if (screen) P.animatePulse(screen, theme.accent);
  return S.tapSequence(rt, { index: 1, total: 3, title: '', hint: '' }, 3, theme.accent);
}

function stageReact(rt: StationRuntime, theme: typeof rt.theme): Promise<number> {
  rt.cb.onStage({ index: 2, total: 3, title: 'Reakcijos modulis', hint: 'Laikyk indikatorius — pataisyk nestabilumą' });
  P.drawAmpReactor(rt.layer, DESIGN_W * 0.35, DESIGN_H * 0.18, theme.accent);
  return S.holdGauge(rt, { index: 2, total: 3, title: '', hint: '' }, 4800, theme.accent, { drift: 0.42, zoneW: 0.15 });
}

function stageStamp(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 2, title: 'Partijos antspaudas', hint: 'Tiksliai užspausk pakuotes' });
  return S.multiTapSeal(rt, { index: 1, total: 2, title: '', hint: '' }, 4, accent);
}

function stagePack(rt: StationRuntime, qty: number, accent: number, total: number): Promise<number> {
  const index = total;
  rt.cb.onStage({ index, total, title: 'Pakavimas', hint: 'Sudėk maišelius' });
  return S.packIntoBox(rt, { index, total, title: '', hint: '' }, qty, accent);
}
