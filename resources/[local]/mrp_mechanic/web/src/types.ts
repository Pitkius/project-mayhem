export type StatKey = 'acceleration' | 'topSpeed' | 'braking' | 'handling' | 'traction';

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

export type OpenPerformancePayload = {
  action: 'openPerformanceUI';
  vehicle: {
    networkId: number;
    model: string;
    plate: string;
  };
  categories: PerformanceCategory[];
  statLabels: Record<StatKey, string>;
  bayIndex: number;
};

export type InstallState = 'install' | 'installed' | 'missing' | 'incompatible';
