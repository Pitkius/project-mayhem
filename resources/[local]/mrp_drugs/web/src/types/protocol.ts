// Message protocol between the vanilla parent layer (html/index.html) and this
// React/Pixi app running inside an <iframe>. Kept intentionally small and
// versioned so both sides stay in sync.

export const PARENT_SOURCE = 'mrp_drugs';
export const WEB_SOURCE = 'mrp_drugs_web';

export type DrugId =
  | 'thc'
  | 'alcohol'
  | 'vape'
  | 'weed'
  | 'heroin'
  | 'cocaine'
  | 'amp'
  | 'meth'
  | 'pills'
  | 'mushroom';

export type QualityTier = 'poor' | 'medium' | 'good' | 'excellent';

/** Parent -> iframe: start an interactive workstation session. */
export interface StartStationMessage {
  source: typeof PARENT_SOURCE;
  action: 'startStation';
  data: StationPayload;
}

export interface StationPayload {
  /** Correlates this UI instance with the active Lua minigame callback. */
  sessionId: string;
  drug: DrugId;
  /** Registry mode id, e.g. 'thc_scrape' / 'thc_cartridge'. */
  mode: string;
  productId?: string;
  label?: string;
  level?: number;
  /** How many packaged units the player can currently produce. */
  quantity?: number;
  /** Difficulty 1..3 from the minigame registry. */
  difficulty?: number;
  /** Whether the player may cancel this process mid-way. */
  cancelable?: boolean;
}

/** Parent -> iframe: force-close (resource restart, ESC upstream, etc.). */
export interface CloseMessage {
  source: typeof PARENT_SOURCE;
  action: 'close';
}

export interface PlayerTheme {
  primary?: string;
  primaryHover?: string;
  primaryActive?: string;
  primarySoft?: string;
  primaryBorder?: string;
  primaryGlow?: string;
  primaryText?: string;
  background?: string;
  surface?: string;
  surfaceActive?: string;
  text?: string;
  mutedText?: string;
}

/** Parent -> iframe: sync HUD player accent colors. */
export interface ApplyThemeMessage {
  source: typeof PARENT_SOURCE;
  action: 'applyTheme';
  theme: PlayerTheme;
}

export type ParentMessage = StartStationMessage | CloseMessage | ApplyThemeMessage;

/** iframe -> parent: session finished (relayed to Lua scheduleResult). */
export interface ResultMessage {
  source: typeof WEB_SOURCE;
  action: 'result';
  data: {
    sessionId?: string;
    success: boolean;
    score: number; // 0..100
    quality: QualityTier;
    mistakes: number;
  };
}

/** iframe -> parent: player requested cancel and confirmed. */
export interface CancelMessage {
  source: typeof WEB_SOURCE;
  action: 'cancel';
}

/** iframe -> parent: signal ready so parent can hide its own loaders. */
export interface ReadyMessage {
  source: typeof WEB_SOURCE;
  action: 'ready';
}

export type WebMessage = ResultMessage | CancelMessage | ReadyMessage;
