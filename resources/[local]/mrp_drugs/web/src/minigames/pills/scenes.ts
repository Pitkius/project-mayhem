import { Graphics } from 'pixi.js';
import { DESIGN_W, DESIGN_H } from '@/engine/pixi/stage';
import * as P from '@/engine/pixi/props';
import * as S from '../shared/commonStages';
import type { StationRuntime } from '../shared/createRuntime';

export function pillsStages(rt: StationRuntime, mode: string, difficulty?: number) {
  const t = rt.theme;
  if (mode === 'pills_blister') {
    return [
      () => stageBlister(rt, t.accent, difficulty),
      () => stageSealBlister(rt, t.accent),
    ];
  }
  return [
    () => stagePress(rt, t),
    () => stageQC(rt, t.accent),
  ];
}

function stagePress(rt: StationRuntime, theme: typeof rt.theme): Promise<number> {
  rt.cb.onStage({ index: 1, total: 2, title: 'Tablečių presas', hint: 'SPACE ritmu — presas leidžiasi' });
  const press = P.drawPillPress(rt.layer, DESIGN_W * 0.4, DESIGN_H * 0.2, theme.accent);
  const head = press.children.find((c) => (c as Graphics).label === 'head') as Graphics | undefined;
  return new Promise((resolve) => {
    S.rhythmTaps(rt, { index: 1, total: 2, title: '', hint: '' }, 4, theme.accent).then((acc) => {
      if (head) P.animatePressRam(head);
      resolve(acc);
    });
  });
}

function stageQC(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 2, title: 'Kontrolė', hint: 'Patikrink tabletes' });
  return S.tapSequence(rt, { index: 2, total: 2, title: '', hint: '' }, 2, accent);
}

function stageBlister(rt: StationRuntime, accent: number, difficulty?: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 2, title: 'Blisteris', hint: 'Paspausk lizdus seka' });
  P.drawPillPress(rt.layer, DESIGN_W * 0.38, DESIGN_H * 0.22, accent);
  const taps = difficulty === 1 ? 3 : 4;
  return S.tapSequence(rt, { index: 1, total: 2, title: '', hint: '' }, taps, accent);
}

function stageSealBlister(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 2, title: 'Užlenk plėvelę', hint: 'Sandarinimas' });
  return S.multiTapSeal(rt, { index: 2, total: 2, title: '', hint: '' }, 3, accent);
}
