export type PageId =
  | 'home'
  | 'map'
  | 'rppass'
  | 'missions'
  | 'daily'
  | 'premium'
  | 'imports'
  | 'vip'
  | 'rewards'
  | 'events'
  | 'ranking'
  | 'profile'
  | 'settings';

export type NavId = PageId;

export type VipTier = 'NONE' | 'SILVER' | 'GOLD' | 'DIAMOND';

/** Shared rarity for loot / rewards (no weapons in daily pool) */
export type ItemRarity = 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary';

export interface PlayerData {
  steamName: string;
  characterName: string;
  id: number;
  credits: number;
  cash: number;
  bank: number;
  job: string;
  vip: VipTier;
  vipDays: number;
  playtimeHours: number;
  playtimeMinutes: number;
  memberSince: string;
  avatarUrl?: string;
}

export interface ServerStatus {
  online: boolean;
  players: number;
  maxPlayers: number;
  police: number;
  ems: number;
  uptime: string;
}

export interface NewsItem {
  id: string;
  tag: string;
  title: string;
  body: string;
  date: string;
}

export interface RpPassReward {
  level: number;
  track: 'free' | 'premium';
  label: string;
  /** QBCore item spawn name */
  itemName: string;
  amount: number;
  /** Emoji / short icon for NUI */
  icon: string;
  rarity: ItemRarity;
  claimed: boolean;
  locked: boolean;
  /** Placeholder slot — shown in the track grid, not claimable */
  empty?: boolean;
}

export interface RpPassData {
  level: number;
  xp: number;
  xpRequired: number;
  maxLevel: number;
  premium: boolean;
  rewards: RpPassReward[];
}

export type MissionPeriod = 'daily' | 'weekly' | 'monthly';
export type MissionStatus = 'active' | 'completed' | 'claimed' | 'locked';

export interface Mission {
  id: string;
  period: MissionPeriod;
  title: string;
  progress: number;
  goal: number;
  unit: string;
  rewardXp: number;
  rewardMoney: number;
  status: MissionStatus;
}

export interface LootItem {
  id: string;
  name: string;
  rarity: ItemRarity;
  /** Item spawn name / id for server — never weapons in daily */
  itemName: string;
  amount: number;
  icon?: string;
  iconUrl?: string;
}

export type CrateKind = 'legal' | 'xp' | 'illegal' | 'daily' | 'weekly';

export interface CrateDef {
  id: string;
  kind: CrateKind;
  label: string;
  description: string;
  icon: string;
  /** Local / inventory image */
  image: string;
  accent: string;
  /** Premium shop price in credits (optional) */
  priceCredits?: number;
  lootPool: LootItem[];
}

export interface WeeklyCrateProgress {
  requiredMinutes: number;
  playedMinutes: number;
  requiredMissions: number;
  missionsCompleted: number;
  missionDone: boolean;
  canClaim: boolean;
  claimed: boolean;
  crateItem: string;
  crateLabel: string;
}

export interface DailyData {
  day: number;
  maxDays: number;
  streak: number;
  requiredMinutes: number;
  playedMinutes: number;
  requiredMissions: number;
  missionsCompleted: number;
  /** Can claim the physical crate item into inventory */
  canClaim: boolean;
  claimedToday: boolean;
  /** QBCore item name given to inventory */
  crateItem: string;
  crateLabel: string;
  /** Possible contents (opened via inventory spin) */
  lootPool: LootItem[];
  /** All crate variants catalog */
  crates: CrateDef[];
  weekly?: WeeklyCrateProgress;
  requirements?: {
    dailyPlay: boolean;
    dailyMission: boolean;
    weeklyPlay: boolean;
    weeklyMission: boolean;
  };
  days: {
    day: number;
    label: string;
    claimed: boolean;
    current: boolean;
    rarityHint?: ItemRarity;
  }[];
}

/** Import salon tiers: A entry / S mid / X top */
export type ImportClass = 'A' | 'S' | 'X';

export interface ImportVehicle {
  id: string;
  name: string;
  class: ImportClass;
  price: number;
  topSpeed: number;
  acceleration: number;
  handling: number;
  seats: number;
  /** Preview image URL (nui:// or https) */
  image: string;
  featured?: boolean;
  limitedEndsIn?: string;
}

export interface VipPlan {
  id: VipTier;
  name: string;
  price: number;
  days: number;
  perks: string[];
}

export interface RewardInboxItem {
  id: string;
  title: string;
  source: string;
  rarity: ItemRarity;
  claimed: boolean;
}

export interface ServerEvent {
  id: string;
  title: string;
  description: string;
  startsIn: string;
  prize: string;
  participants: number;
}

export interface LeaderboardEntry {
  rank: number;
  name: string;
  value: string;
  isSelf?: boolean;
}

export type RankingCategory = 'playtime' | 'money' | 'missions' | 'rppass' | 'events';

export interface Achievement {
  id: string;
  title: string;
  description: string;
  unlocked: boolean;
}

export interface SettingsState {
  hudEnabled: boolean;
  hudOpacity: number;
  hudScale: number;
  notifications: boolean;
  sound: boolean;
  fpsCounter: boolean;
  cinematic: boolean;
  language: 'lt' | 'en';
}

export interface NotificationItem {
  id: string;
  icon: string;
  title: string;
  description: string;
  timestamp: string;
}

export interface DashboardData {
  player: PlayerData;
  server: ServerStatus;
  news: NewsItem[];
  rpPass: RpPassData;
  missions: Mission[];
  daily: DailyData;
  imports: ImportVehicle[];
  vipPlans: VipPlan[];
  rewards: RewardInboxItem[];
  events: ServerEvent[];
  rankings: Record<RankingCategory, LeaderboardEntry[]>;
  achievements: Achievement[];
  settings: SettingsState;
}

export const RARITY_LABEL: Record<ItemRarity, string> = {
  common: 'COMMON',
  uncommon: 'UNCOMMON',
  rare: 'RARE',
  epic: 'EPIC',
  legendary: 'LEGENDARY',
};
