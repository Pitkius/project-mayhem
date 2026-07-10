import { DESIGN_W, DESIGN_H } from '@/engine/pixi/stage';
import * as P from '@/engine/pixi/props';
import * as S from '../shared/commonStages';
import type { StationRuntime } from '../shared/createRuntime';

export function thcStages(rt: StationRuntime, mode: string, qty: number) {
  const t = rt.theme;
  if (mode === 'thc_cartridge' || mode === 'thc_pack') {
    return [
      () => stageFill(rt, t),
      () => stageSeal(rt, t.accent),
      () => stagePack(rt, qty, t.accent),
    ];
  }
  return [
    () => stageScrape(rt, t),
    () => stageDistill(rt, t),
  ];
}

function stageScrape(rt: StationRuntime, theme: typeof rt.theme): Promise<number> {
  rt.cb.onStage({ index: 1, total: 2, title: 'Trim medžiagos gramdymas', hint: 'Tempk gramdyklę per padėklą' });
  P.drawThcCartridge(rt.layer, DESIGN_W * 0.18, DESIGN_H * 0.28, theme.accent2);
  P.animateSteam(rt.layer, DESIGN_W * 0.42, DESIGN_H * 0.32, theme.particle, 5);
  return S.scrapeGrid(rt, { index: 1, total: 2, title: '', hint: '' }, {
    cols: 14,
    rows: 8,
    cellColor: 0x3b6b2f,
  });
}

function stageDistill(rt: StationRuntime, theme: typeof rt.theme): Promise<number> {
  rt.cb.onStage({ index: 2, total: 2, title: 'Distiliato stabilizavimas', hint: 'Laikyk adatą žalioje zonoje' });
  P.drawGlassJar(rt.layer, DESIGN_W * 0.48, DESIGN_H * 0.2, 150, theme.accent);
  return S.holdGauge(rt, { index: 2, total: 2, title: '', hint: '' }, 5000, theme.accent, {
    drift: 0.28,
    zoneW: 0.22,
  });
}

function stageFill(rt: StationRuntime, theme: typeof rt.theme): Promise<number> {
  rt.cb.onStage({ index: 1, total: 3, title: 'Kasetės užpildymas', hint: 'Sustok žaliame lange — neperpildyk!' });
  P.drawThcCartridge(rt.layer, DESIGN_W * 0.46, DESIGN_H * 0.18, theme.accent);
  return S.fillBand(rt, { index: 1, total: 3, title: '', hint: '' }, { color: theme.accent, bandLo: 0.72, bandHi: 0.9 });
}

function stageSeal(rt: StationRuntime, accent: number): Promise<number> {
  rt.cb.onStage({ index: 2, total: 3, title: 'Kasetės uždarymas', hint: 'Išlaikyk stabilų spaudimą' });
  P.drawThcCartridge(rt.layer, DESIGN_W * 0.46, DESIGN_H * 0.18, accent);
  return S.holdGauge(rt, { index: 2, total: 3, title: '', hint: '' }, 2400, accent, { drift: 0.34, zoneW: 0.2 });
}

function stagePack(rt: StationRuntime, qty: number, accent: number): Promise<number> {
  rt.cb.onStage({ index: 3, total: 3, title: 'Pakavimas', hint: 'Sudėk kasetes į dėžutę' });
  return S.packIntoBox(rt, { index: 3, total: 3, title: '', hint: '' }, qty, accent);
}
