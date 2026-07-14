export interface CraftMaterial {
  item: string;
  need: number;
}

export interface CraftRecipe {
  key: string;
  label: string;
  output: string;
  categoryId: string;
  level?: number | null;
  isKit?: boolean;
  materials: CraftMaterial[];
  maxAmount: number;
  description?: string;
  image: string;
}

export interface CraftCategory {
  id: string;
  label: string;
  desc: string;
}

export interface CraftLabelInfo {
  label: string;
  image: string;
  description?: string;
}

export interface CraftPayload {
  ok?: boolean;
  craftKind?: string;
  title?: string;
  subtitle?: string;
  maxBatch?: number;
  categories?: CraftCategory[];
  recipes?: CraftRecipe[];
  inventory?: Record<string, number>;
  labels?: Record<string, CraftLabelInfo>;
  message?: string;
}

export interface CraftStartResult {
  ok: boolean;
  message?: string;
  inventory?: Record<string, number>;
  labels?: Record<string, CraftLabelInfo>;
  maxAmount?: number;
  recipeKey?: string;
}
