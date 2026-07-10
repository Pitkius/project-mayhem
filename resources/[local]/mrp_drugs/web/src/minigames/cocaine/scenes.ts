import { Graphics } from 'pixi.js';
import { DESIGN_W, DESIGN_H } from '@/engine/pixi/stage';
import * as P from '@/engine/pixi/props';
import * as S from '../shared/commonStages';
import type { StationRuntime } from '../shared/createRuntime';

export function cocaineStages(rt: StationRuntime, mode: string, qty: number) {
  const t = rt.theme;
  if (mode === 'coca_harvest') {
    return [() => stageHarvest(rt, t.accent)];
  }
  if (mode === 'cocaine_brick') {
    return [
      () => stagePress(rt, t),
      () => stageWrap(rt, t.accent2),
      () => stageShip(rt, qty, t.accent),
    ];
  }
  return [
    () => stageWash(rt, t.accent),
    () => stageProcess(rt, t),
  ];
}

function stageHarvest(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 1, title: 'Lapų nuėmimas', hint: 'Surink lapus laiku' });
  for (let i = 0; i < 6; i++) {
    const leaf = new Graphics();
    leaf.ellipse(0, 0, 18, 8).fill({ color: 0x4ade80, alpha: 0.85 });
    leaf.position.set(DESIGN_W * 0.2 + i * 45, DESIGN_H * 0.3);
    rt.layer.addChild(leaf);
  }
  return S.catchFalling(rt, { index: 1, total: 1, title: '', hint: '' }, 6, 0x4ade80);
}

function stageWash(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 1, total: 2, title: 'Cheminis plovimas', hint: 'Atidaryk vožtuvus seka' });
  P.drawValve(rt.layer, DESIGN_W * 0.32, DESIGN_H * 0.38, accent);
  P.drawValve(rt.layer, DESIGN_W * 0.48, DESIGN_H * 0.38, accent);
  P.drawValve(rt.layer, DESIGN_W * 0.64, DESIGN_H * 0.38, accent);
  return S.tapSequence(rt, { index: 1, total: 2, title: '', hint: '' }, 4, accent);
}

function stageProcess(rt: StationRuntime, theme: typeof rt.theme): Promise<number> {
  rt.cb.onStage({ index: 2, total: 2, title: 'Kontroliuok procesą', hint: 'Laikyk parametrus zonoje' });
  P.drawGlassJar(rt.layer, DESIGN_W * 0.5, DESIGN_H * 0.22, 130, theme.accent);
  return S.holdGauge(rt, { index: 2, total: 2, title: '', hint: '' }, 5000, theme.accent, { drift: 0.38 });
}

function stagePress(rt: StationRuntime, theme: typeof rt.theme): Promise<number> {
  rt.cb.onStage({ index: 1, total: 3, title: 'Presuok bloką', hint: 'SPACE ritmu — presas leidžiasi' });
  const press = P.drawCocainePress(rt.layer, DESIGN_W * 0.42, DESIGN_H * 0.2, theme.accent);
  const ram = press.children.find((c) => (c as Graphics).label === 'ram') as Graphics | undefined;
  return new Promise((resolve) => {
    S.rhythmTaps(rt, { index: 1, total: 3, title: '', hint: '' }, 4, theme.accent).then((acc) => {
      if (ram) P.animatePressRam(ram);
      resolve(acc);
    });
  });
}

function stageWrap(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 3, title: 'Apvyniok plėvele', hint: 'Spausk tvirtinimui' });
  return S.multiTapSeal(rt, { index: 2, total: 3, title: '', hint: '' }, 3, accent);
}

function stageShip(rt: StationRuntime, qty: number, accent: number): Promise<number> {
  rt.cb.onStage({ index: 3, total: 3, title: 'Paruošk siuntą', hint: '' });
  return S.packIntoBox(rt, { index: 3, total: 3, title: '', hint: '' }, qty, accent);
}
