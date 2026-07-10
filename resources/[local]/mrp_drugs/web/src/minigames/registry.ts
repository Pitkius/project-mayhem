import type { DrugId } from '@/types/protocol';
import type { StationFactory } from './types';
import { runThcStation } from './thc/ThcStation';
import { runAlcoholStation } from './alcohol/AlcoholStation';
import { runVapeStation } from './vape/VapeStation';
import { runWeedStation } from './weed/WeedStation';
import { runHeroinStation } from './heroin/HeroinStation';
import { runCocaineStation } from './cocaine/CocaineStation';
import { runAmpStation } from './amp/AmpStation';
import { runMethStation } from './meth/MethStation';
import { runPillsStation } from './pills/PillsStation';
import { runMushroomStation } from './mushroom/MushroomStation';

export const STATIONS: Partial<Record<DrugId, StationFactory>> = {
  thc: runThcStation,
  alcohol: runAlcoholStation,
  vape: runVapeStation,
  weed: runWeedStation,
  heroin: runHeroinStation,
  cocaine: runCocaineStation,
  amp: runAmpStation,
  meth: runMethStation,
  pills: runPillsStation,
  mushroom: runMushroomStation,
};

export function getStation(drug: DrugId): StationFactory | null {
  return STATIONS[drug] ?? null;
}
