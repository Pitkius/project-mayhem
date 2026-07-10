import { DESIGN_W, DESIGN_H } from '@/engine/pixi/stage';
import * as P from '@/engine/pixi/props';
import * as S from '../shared/commonStages';
import type { StationRuntime } from '../shared/createRuntime';

export function vapeStages(rt: StationRuntime, mode: string, qty: number) {
  const t = rt.theme;
  if (mode === 'vape_dropper') {
    return [
      () => stageDropper(rt, t.accent),
      () => stageBottleFill(rt, t.accent),
      () => stageVapePack(rt, qty, t.accent),
    ];
  }
  return [
    () => stageBlend(rt, t),
    () => stageStabilize(rt, t.accent),
  ];
}

function stageBlend(rt: StationRuntime, theme: typeof rt.theme): Promise<number> {
  rt.cb.onStage({ index: 1, total: 2, title: 'Skysčių mišinys', hint: 'Sustabdyk kiekvieną komponentą tikslioje zonoje' });
  const mixer = P.drawVapeMixer(rt.layer, DESIGN_W * 0.4, DESIGN_H * 0.22, theme.accent);
  const spinner = mixer.children.find((c) => (c as { label?: string }).label === 'spinner');
  if (spinner) P.animateSpin(spinner);
  return S.blendComponents(rt, { index: 1, total: 2, title: '', hint: '' }, 3, [theme.accent, 0xa855f7, 0x4ade80]);
}

function stageStabilize(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 2, title: 'Stabilizuok mišinį', hint: 'Laikyk maišyklę stabilioje zonoje' });
  P.drawVapeMixer(rt.layer, DESIGN_W * 0.4, DESIGN_H * 0.22, accent);
  return S.holdGauge(rt, { index: 2, total: 2, title: '', hint: '' }, 3800, accent, { zoneW: 0.18 });
}

function stageDropper(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 3, title: 'Lašinimas', hint: 'SPACE tikslinėje zonoje' });
  P.drawGlassJar(rt.layer, DESIGN_W * 0.48, DESIGN_H * 0.2, 120, accent);
  return S.rhythmTaps(rt, { index: 1, total: 3, title: '', hint: '' }, 4, accent);
}

function stageBottleFill(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 3, title: 'Užpildyk buteliuką', hint: 'Sustok žaliame lange' });
  return S.fillBand(rt, { index: 2, total: 3, title: '', hint: '' }, { color: accent });
}

function stageVapePack(rt: StationRuntime, qty: number, accent: number): Promise<number> {
  rt.cb.onStage({ index: 3, total: 3, title: 'Etiketė ir pakavimas', hint: 'Sudėk buteliukus' });
  return S.packIntoBox(rt, { index: 3, total: 3, title: '', hint: '' }, qty, accent);
}
