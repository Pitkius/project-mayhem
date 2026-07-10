import { Graphics } from 'pixi.js';
import { DESIGN_W, DESIGN_H } from '@/engine/pixi/stage';
import * as P from '@/engine/pixi/props';
import * as S from '../shared/commonStages';
import type { StationRuntime } from '../shared/createRuntime';

export function ampStages(rt: StationRuntime, _mode: string, qty: number) {
  const t = rt.theme;
  return [
    () => stagePrep(rt, t),
    () => stageReact(rt, t),
    () => stagePack(rt, qty, t.accent),
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

function stagePack(rt: StationRuntime, qty: number, accent: number): Promise<number> {
  rt.cb.onStage({ index: 3, total: 3, title: 'Antspaudas ir pakavimas', hint: 'Sudėk maišelius' });
  P.drawAmpReactor(rt.layer, DESIGN_W * 0.35, DESIGN_H * 0.18, accent);
  return S.packIntoBox(rt, { index: 3, total: 3, title: '', hint: '' }, qty, accent);
}
