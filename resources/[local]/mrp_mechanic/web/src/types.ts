export type StatKey = 'acceleration' | 'topSpeed' | 'braking' | 'handling' | 'traction';

export type WorkshopSection = 'performance' | 'paint' | 'tint' | 'body';

export type PerformancePart = {
  idx: number;
  level: number;
  itemName: string | null;
  label: string;
  image: string;
  inventoryCount: number;
  installed: boolean;
};

export type PerformanceCategory = {
  id: string;
  modType: number;
  label: string;
  isToggle?: boolean;
  installedLevel: number;
  maxLevel: number;
  statKeys: StatKey[];
  hasInventory: boolean;
  parts: PerformancePart[];
  currentStats: Partial<Record<StatKey, number>>;
};

export type PaintType = { paintType: number; label: string; txt: string };
export type WindowTint = { idx: number; label: string };
export type BodyModCategory = { id: number; label: string; count: number };
export type BodyVariant = { idx: number; label: string };

export type OpenWorkshopPayload = {
  action: 'openWorkshop';
  vehicle: { networkId: number; model: string; plate: string };
  bayIndex: number;
  categories: PerformanceCategory[];
  statLabels: Record<StatKey, string>;
  paintTypes: PaintType[];
  windowTints: WindowTint[];
  bodyMods: BodyModCategory[];
  turboOn: boolean;
};

export type InstallState = 'install' | 'installed' | 'missing' | 'incompatible';

export const SECTIONS: { id: WorkshopSection; icon: string; label: string; cam: string }[] = [
  { id: 'performance', icon: '⚡', label: 'Performance', cam: 'body' },
  { id: 'paint', icon: '🎨', label: 'Dažymas', cam: 'paint' },
  { id: 'tint', icon: '🪟', label: 'Langai', cam: 'tint' },
  { id: 'body', icon: '🔧', label: 'Kėbulas', cam: 'body' },
];
