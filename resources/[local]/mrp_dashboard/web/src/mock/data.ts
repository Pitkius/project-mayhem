import type { DashboardData, ItemRarity, LootItem, RpPassReward, CrateDef } from '@/types/dashboard';

type PassItemDef = {
  itemName: string;
  label: string;
  icon: string;
  amount: number;
  rarity: ItemRarity;
};

/** Legal / useful market-style rewards (no weapons, no drugs) */
const FREE_POOL: PassItemDef[] = [
  { itemName: 'water_bottle', label: 'Vanduo', icon: '💧', amount: 5, rarity: 'common' },
  { itemName: 'coffee', label: 'Kava', icon: '☕', amount: 3, rarity: 'common' },
  { itemName: 'bandage', label: 'Tvarstis', icon: '🩹', amount: 5, rarity: 'common' },
  { itemName: 'painkillers', label: 'Nuskausminamieji', icon: '💊', amount: 3, rarity: 'common' },
  { itemName: 'cleaningkit', label: 'Valymo rinkinys', icon: '🧽', amount: 2, rarity: 'common' },
  { itemName: 'lighter', label: 'Žiebtuvėlis', icon: '🔥', amount: 1, rarity: 'common' },
  { itemName: 'repairkit', label: 'Remonto rinkinys', icon: '🔧', amount: 1, rarity: 'uncommon' },
  { itemName: 'tirerepairkit', label: 'Padangų rinkinys', icon: '🛞', amount: 1, rarity: 'uncommon' },
  { itemName: 'firstaid', label: 'Pirmosios pagalbos', icon: '⛑️', amount: 2, rarity: 'uncommon' },
  { itemName: 'ifaks', label: 'IFAK', icon: '🩺', amount: 2, rarity: 'uncommon' },
  { itemName: 'binoculars', label: 'Žiūronai', icon: '🔭', amount: 1, rarity: 'uncommon' },
  { itemName: 'jerry_can', label: 'Kanistras 20 l', icon: '⛽', amount: 1, rarity: 'rare' },
  { itemName: 'advancedrepairkit', label: 'Pažangus remontas', icon: '🛠️', amount: 1, rarity: 'rare' },
  { itemName: 'armor_light', label: 'Lengva liemenė', icon: '🦺', amount: 1, rarity: 'rare' },
  { itemName: 'radio', label: 'Radijas', icon: '📻', amount: 1, rarity: 'rare' },
  { itemName: 'fitbit', label: 'Fitbit', icon: '⌚', amount: 1, rarity: 'epic' },
  { itemName: 'armor_standard', label: 'Standartinė liemenė', icon: '🛡️', amount: 1, rarity: 'epic' },
  { itemName: 'parachute', label: 'Parašiutas', icon: '🪂', amount: 1, rarity: 'epic' },
  { itemName: 'diving_gear', label: 'Nardymo įranga', icon: '🤿', amount: 1, rarity: 'legendary' },
  { itemName: 'phone', label: 'Telefonas', icon: '📱', amount: 1, rarity: 'legendary' },
];

const PREMIUM_POOL: PassItemDef[] = [
  { itemName: 'water_bottle', label: 'Vanduo', icon: '💧', amount: 8, rarity: 'common' },
  { itemName: 'coffee', label: 'Kava', icon: '☕', amount: 5, rarity: 'common' },
  { itemName: 'bandage', label: 'Tvarstis', icon: '🩹', amount: 8, rarity: 'common' },
  { itemName: 'painkillers', label: 'Nuskausminamieji', icon: '💊', amount: 5, rarity: 'common' },
  { itemName: 'cleaningkit', label: 'Valymo rinkinys', icon: '🧽', amount: 3, rarity: 'common' },
  { itemName: 'repairkit', label: 'Remonto rinkinys', icon: '🔧', amount: 2, rarity: 'uncommon' },
  { itemName: 'tirerepairkit', label: 'Padangų rinkinys', icon: '🛞', amount: 2, rarity: 'uncommon' },
  { itemName: 'firstaid', label: 'Pirmosios pagalbos', icon: '⛑️', amount: 3, rarity: 'uncommon' },
  { itemName: 'ifaks', label: 'IFAK', icon: '🩺', amount: 3, rarity: 'uncommon' },
  { itemName: 'binoculars', label: 'Žiūronai', icon: '🔭', amount: 1, rarity: 'uncommon' },
  { itemName: 'jerry_can', label: 'Kanistras 20 l', icon: '⛽', amount: 1, rarity: 'rare' },
  { itemName: 'advancedrepairkit', label: 'Pažangus remontas', icon: '🛠️', amount: 1, rarity: 'rare' },
  { itemName: 'armor_light', label: 'Lengva liemenė', icon: '🦺', amount: 1, rarity: 'rare' },
  { itemName: 'armor_standard', label: 'Standartinė liemenė', icon: '🛡️', amount: 1, rarity: 'rare' },
  { itemName: 'radio', label: 'Radijas', icon: '📻', amount: 1, rarity: 'rare' },
  { itemName: 'fitbit', label: 'Fitbit', icon: '⌚', amount: 1, rarity: 'epic' },
  { itemName: 'armor', label: 'Sunki liemenė', icon: '🛡️', amount: 1, rarity: 'epic' },
  { itemName: 'parachute', label: 'Parašiutas', icon: '🪂', amount: 1, rarity: 'epic' },
  { itemName: 'diving_fill', label: 'Nardymo balionas', icon: '🫧', amount: 1, rarity: 'epic' },
  { itemName: 'heavyarmor', label: 'Super sunki liemenė', icon: '🛡️', amount: 1, rarity: 'legendary' },
  { itemName: 'diving_gear', label: 'Nardymo įranga', icon: '🤿', amount: 1, rarity: 'legendary' },
  { itemName: 'phone', label: 'Telefonas', icon: '📱', amount: 1, rarity: 'legendary' },
  { itemName: 'cash', label: 'Pinigai', icon: '💵', amount: 2500, rarity: 'legendary' },
];

function pickPassItem(pool: PassItemDef[], level: number, salt: number): PassItemDef {
  const idx = (level * 17 + salt * 31) % pool.length;
  const base = pool[idx];
  // Scale amount a bit with level for consumables
  const scale =
    base.amount > 1
      ? Math.min(base.amount + Math.floor(level / 25), base.amount + 5)
      : base.amount;
  return { ...base, amount: scale };
}

function rarityBump(base: ItemRarity, level: number): ItemRarity {
  if (level >= 90) return 'legendary';
  if (level >= 70) return base === 'common' ? 'rare' : base === 'uncommon' ? 'epic' : base;
  if (level >= 40) return base === 'common' ? 'uncommon' : base;
  return base;
}

/** Free: 1, 5, 10, 15 … 100. Premium: every level. */
function rpRewards(playerLevel = 37): RpPassReward[] {
  const rewards: RpPassReward[] = [];
  for (let level = 1; level <= 100; level++) {
    const locked = level > playerLevel;
    const claimed = level < playerLevel - 2;
    const isFreeTier = level === 1 || level % 5 === 0;

    if (isFreeTier) {
      const item = pickPassItem(FREE_POOL, level, 1);
      rewards.push({
        level,
        track: 'free',
        label: item.label,
        itemName: item.itemName,
        amount: item.amount,
        icon: item.icon,
        rarity: rarityBump(item.rarity, level),
        claimed: claimed && isFreeTier,
        locked,
      });
    }

    const prem = pickPassItem(PREMIUM_POOL, level, 7);
    rewards.push({
      level,
      track: 'premium',
      label: prem.label,
      itemName: prem.itemName,
      amount: prem.amount + (level % 10 === 0 ? 1 : 0),
      icon: prem.icon,
      rarity: rarityBump(prem.rarity, level),
      claimed,
      locked,
    });
  }
  return rewards;
}

/** Daily loot — server items only, NEVER weapons */
export const mockLootPool: LootItem[] = [
  { id: 'l1', name: 'Remonto rinkinys', rarity: 'common', itemName: 'repairkit', amount: 1, icon: '🔧' },
  { id: 'l2', name: 'Pirmos pagalbos', rarity: 'common', itemName: 'firstaid', amount: 2, icon: '🩹' },
  { id: 'l3', name: 'Vanduo', rarity: 'common', itemName: 'water_bottle', amount: 5, icon: '💧' },
  { id: 'l4', name: 'Kava', rarity: 'common', itemName: 'coffee', amount: 3, icon: '☕' },
  { id: 'l5', name: 'Valymo rinkinys', rarity: 'uncommon', itemName: 'cleaningkit', amount: 2, icon: '🧽' },
  { id: 'l6', name: 'Radio', rarity: 'uncommon', itemName: 'radio', amount: 1, icon: '📻' },
  { id: 'l7', name: 'Tvarstis', rarity: 'uncommon', itemName: 'bandage', amount: 5, icon: '🩹' },
  { id: 'l8', name: 'Kanistras', rarity: 'rare', itemName: 'jerry_can', amount: 1, icon: '⛽' },
  { id: 'l9', name: 'Lengva liemenė', rarity: 'rare', itemName: 'armor_light', amount: 1, icon: '🦺' },
  { id: 'l10', name: 'Pažangus remontas', rarity: 'rare', itemName: 'advancedrepairkit', amount: 1, icon: '🛠️' },
  { id: 'l11', name: 'Parašiutas', rarity: 'epic', itemName: 'parachute', amount: 1, icon: '🪂' },
  { id: 'l12', name: 'Standartinė liemenė', rarity: 'epic', itemName: 'armor_standard', amount: 1, icon: '🛡️' },
  { id: 'l13', name: 'Nardymo įranga', rarity: 'legendary', itemName: 'diving_gear', amount: 1, icon: '🤿' },
  { id: 'l14', name: 'Sunki liemenė', rarity: 'legendary', itemName: 'armor', amount: 1, icon: '🛡️' },
];

export const mockCrates: CrateDef[] = [
  {
    id: 'deze_legali',
    kind: 'legal',
    label: 'Legalių daiktų dėžė',
    description: 'Repair, medic, rinkos įrankiai.',
    icon: '🧰',
    image: 'deze_legali.png',
    accent: '#38bdf8',
    priceCredits: 350,
    lootPool: [
      { id: 'lg1', name: 'Vanduo', rarity: 'common', itemName: 'water_bottle', amount: 8, icon: '💧' },
      { id: 'lg2', name: 'Remonto rinkinys', rarity: 'uncommon', itemName: 'repairkit', amount: 1, icon: '🔧' },
      { id: 'lg3', name: 'Kanistras', rarity: 'rare', itemName: 'jerry_can', amount: 1, icon: '⛽' },
      { id: 'lg4', name: 'Pažangus remontas', rarity: 'epic', itemName: 'advancedrepairkit', amount: 1, icon: '🛠️' },
      { id: 'lg5', name: 'Telefonas', rarity: 'legendary', itemName: 'phone', amount: 1, icon: '📱' },
    ],
  },
  {
    id: 'deze_exp',
    kind: 'xp',
    label: 'EXP dėžė',
    description: 'RP Pass XP paketai.',
    icon: '✨',
    image: 'deze_exp.png',
    accent: '#a78bfa',
    priceCredits: 400,
    lootPool: [
      { id: 'xp1', name: '100 XP', rarity: 'common', itemName: 'xp', amount: 100, icon: '✨' },
      { id: 'xp2', name: '350 XP', rarity: 'uncommon', itemName: 'xp', amount: 350, icon: '⭐' },
      { id: 'xp3', name: '750 XP', rarity: 'epic', itemName: 'xp', amount: 750, icon: '💫' },
      { id: 'xp4', name: '1200 XP', rarity: 'legendary', itemName: 'xp', amount: 1200, icon: '👑' },
    ],
  },
  {
    id: 'deze_nelegali',
    kind: 'illegal',
    label: 'Nelegalių daiktų dėžė',
    description: 'Kontrabanda (be ginklų).',
    icon: '☠️',
    image: 'deze_nelegali.png',
    accent: '#f87171',
    priceCredits: 550,
    lootPool: [
      { id: 'il1', name: 'Visraktis', rarity: 'common', itemName: 'lockpick', amount: 3, icon: '🔓' },
      { id: 'il2', name: 'Suktinė', rarity: 'common', itemName: 'joint', amount: 4, icon: '🚬' },
      { id: 'il3', name: 'Kokaino maišelis', rarity: 'rare', itemName: 'cokebaggy', amount: 1, icon: '❄️' },
      { id: 'il4', name: 'Trojos USB', rarity: 'epic', itemName: 'trojan_usb', amount: 1, icon: '💾' },
      { id: 'il5', name: 'Rolex', rarity: 'legendary', itemName: 'rolex', amount: 1, icon: '⌚' },
    ],
  },
  {
    id: 'dienos_deze',
    kind: 'daily',
    label: 'Dienos dėžė',
    description: 'Nemokama: 2h playtime + dienos misija.',
    icon: '📦',
    image: 'dienos_deze.png',
    accent: '#fbbf24',
    lootPool: mockLootPool.slice(0, 8),
  },
  {
    id: 'savaites_deze',
    kind: 'weekly',
    label: 'Savaitės dėžė',
    description: 'Nemokama: 10h playtime + savaitės misija.',
    icon: '🏆',
    image: 'savaites_deze.png',
    accent: '#67e8f9',
    priceCredits: 1200,
    lootPool: [
      { id: 'w1', name: 'Pažangus remontas', rarity: 'uncommon', itemName: 'advancedrepairkit', amount: 1, icon: '🛠️' },
      { id: 'w2', name: '500 XP', rarity: 'rare', itemName: 'xp', amount: 500, icon: '🌟' },
      { id: 'w3', name: 'Parašiutas', rarity: 'epic', itemName: 'parachute', amount: 1, icon: '🪂' },
      { id: 'w4', name: 'Nardymo įranga', rarity: 'legendary', itemName: 'diving_gear', amount: 1, icon: '🤿' },
      { id: 'w5', name: 'Pinigai', rarity: 'legendary', itemName: 'cash', amount: 3500, icon: '💵' },
    ],
  },
];

function carImg(label: string, bg = '141625') {
  return `https://placehold.co/640x360/${bg}/c4b5fd/png?text=${encodeURIComponent(label)}`;
}

export const mockDashboard: DashboardData = {
  player: {
    steamName: 'Dzonas Brownas',
    characterName: 'Dzonas Brownas',
    id: 123,
    credits: 2450,
    cash: 18726,
    bank: 1245890,
    job: 'Policijos pareigūnas',
    vip: 'GOLD',
    vipDays: 24,
    playtimeHours: 482,
    playtimeMinutes: 15,
    memberSince: '2025-03-12',
  },
  server: {
    online: true,
    players: 128,
    maxPlayers: 256,
    police: 12,
    ems: 7,
    uptime: '14h 32m',
  },
  news: [
    {
      id: '1',
      tag: 'UPDATE',
      title: 'Nauji importai',
      body: '5 nauji automobiliai jau pasiekiami Imports skyriuje.',
      date: '2026-08-08',
    },
    {
      id: '2',
      tag: 'ANNOUNCEMENT',
      title: 'PD atranka',
      body: 'Lietuvos policija ieško naujų pareigūnų. Kreipkis į HR.',
      date: '2026-08-07',
    },
    {
      id: '3',
      tag: 'EVENT',
      title: 'Mayhem Car Meet',
      body: 'Šį vakarą 20:00 — car meet prie Legion Square.',
      date: '2026-08-06',
    },
  ],
  rpPass: {
    level: 37,
    xp: 720,
    xpRequired: 1000,
    maxLevel: 100,
    premium: true,
    rewards: rpRewards(37),
  },
  missions: [
    {
      id: 'm1',
      period: 'daily',
      title: 'Nuvažiuok 50 km',
      progress: 34,
      goal: 50,
      unit: 'KM',
      rewardXp: 250,
      rewardMoney: 500,
      status: 'active',
    },
    {
      id: 'm2',
      period: 'daily',
      title: 'Dirbk 2 valandas',
      progress: 2,
      goal: 2,
      unit: 'H',
      rewardXp: 300,
      rewardMoney: 750,
      status: 'completed',
    },
    {
      id: 'm3',
      period: 'weekly',
      title: 'Uždirbk $50,000',
      progress: 28500,
      goal: 50000,
      unit: '$',
      rewardXp: 800,
      rewardMoney: 2500,
      status: 'active',
    },
    {
      id: 'm4',
      period: 'weekly',
      title: 'Atlik 10 misijų',
      progress: 10,
      goal: 10,
      unit: '',
      rewardXp: 600,
      rewardMoney: 1500,
      status: 'claimed',
    },
    {
      id: 'm5',
      period: 'monthly',
      title: 'Pasiek RP Pass 50',
      progress: 37,
      goal: 50,
      unit: 'LVL',
      rewardXp: 2000,
      rewardMoney: 10000,
      status: 'active',
    },
    {
      id: 'm6',
      period: 'monthly',
      title: 'Laimėk 5 eventus',
      progress: 0,
      goal: 5,
      unit: '',
      rewardXp: 1500,
      rewardMoney: 5000,
      status: 'locked',
    },
  ],
  daily: {
    day: 4,
    maxDays: 7,
    streak: 4,
    requiredMinutes: 120,
    playedMinutes: 120,
    canClaim: true,
    claimedToday: false,
    crateItem: 'dienos_deze',
    crateLabel: 'Dienos dėžė',
    lootPool: mockLootPool,
    crates: mockCrates,
    weekly: {
      requiredMinutes: 600,
      playedMinutes: 420,
      missionDone: false,
      canClaim: false,
      claimed: false,
      crateItem: 'savaites_deze',
      crateLabel: 'Savaitės dėžė',
    },
    requirements: {
      dailyPlay: true,
      dailyMission: true,
      weeklyPlay: false,
      weeklyMission: false,
    },
    days: [
      { day: 1, label: 'DĖŽĖ', claimed: true, current: false, rarityHint: 'common' },
      { day: 2, label: 'DĖŽĖ', claimed: true, current: false, rarityHint: 'uncommon' },
      { day: 3, label: 'DĖŽĖ', claimed: true, current: false, rarityHint: 'common' },
      { day: 4, label: 'DĖŽĖ', claimed: false, current: true, rarityHint: 'rare' },
      { day: 5, label: 'DĖŽĖ', claimed: false, current: false, rarityHint: 'uncommon' },
      { day: 6, label: 'DĖŽĖ', claimed: false, current: false, rarityHint: 'rare' },
      { day: 7, label: 'MEGA', claimed: false, current: false, rarityHint: 'legendary' },
    ],
  },
  imports: [
    {
      id: 'a1',
      name: 'VW Golf R',
      class: 'A',
      price: 450,
      topSpeed: 78,
      acceleration: 74,
      handling: 80,
      seats: 5,
      image: carImg('VW Golf R', '1a2332'),
    },
    {
      id: 'a2',
      name: 'Audi S3',
      class: 'A',
      price: 520,
      topSpeed: 80,
      acceleration: 76,
      handling: 81,
      seats: 5,
      image: carImg('Audi S3', '1a2332'),
    },
    {
      id: 'a3',
      name: 'BMW 340i',
      class: 'A',
      price: 580,
      topSpeed: 82,
      acceleration: 77,
      handling: 79,
      seats: 5,
      featured: true,
      image: carImg('BMW 340i', '1a2332'),
    },
    {
      id: 's1',
      name: 'BMW M4 Competition',
      class: 'S',
      price: 1800,
      topSpeed: 90,
      acceleration: 86,
      handling: 84,
      seats: 4,
      featured: true,
      image: carImg('BMW M4', '1e1530'),
    },
    {
      id: 's2',
      name: 'Audi RS6 Avant',
      class: 'S',
      price: 2100,
      topSpeed: 91,
      acceleration: 85,
      handling: 83,
      seats: 5,
      image: carImg('Audi RS6', '1e1530'),
    },
    {
      id: 's3',
      name: 'Mercedes AMG C63',
      class: 'S',
      price: 1950,
      topSpeed: 89,
      acceleration: 87,
      handling: 82,
      seats: 4,
      image: carImg('AMG C63', '1e1530'),
    },
    {
      id: 'x1',
      name: 'Porsche 911 Turbo S',
      class: 'X',
      price: 4200,
      topSpeed: 97,
      acceleration: 95,
      handling: 92,
      seats: 2,
      featured: true,
      limitedEndsIn: '2D 14H',
      image: carImg('911 Turbo S', '2a2110'),
    },
    {
      id: 'x2',
      name: 'McLaren 720S',
      class: 'X',
      price: 5500,
      topSpeed: 98,
      acceleration: 97,
      handling: 94,
      seats: 2,
      image: carImg('McLaren 720S', '2a2110'),
    },
    {
      id: 'x3',
      name: 'Bugatti Chiron',
      class: 'X',
      price: 9000,
      topSpeed: 100,
      acceleration: 99,
      handling: 88,
      seats: 2,
      image: carImg('Chiron', '2a2110'),
    },
  ],
  vipPlans: [
    {
      id: 'SILVER',
      name: 'SILVER',
      price: 500,
      days: 30,
      perks: ['VIP žyma', 'Dieninis bonusas', 'Maža importų nuolaida'],
    },
    {
      id: 'GOLD',
      name: 'GOLD',
      price: 1200,
      days: 30,
      perks: [
        'Visi Silver privalumai',
        'Geresni daily rewardai',
        'Importų nuolaida',
        'Exclusive kosmetika',
      ],
    },
    {
      id: 'DIAMOND',
      name: 'DIAMOND',
      price: 2500,
      days: 30,
      perks: [
        'Visi Gold privalumai',
        'Didesnės nuolaidos',
        'Exclusive transportas',
        'Extra rewardai',
        'Priority queue',
      ],
    },
  ],
  rewards: [
    {
      id: 'r1',
      title: '500 CREDITS',
      source: 'RP PASS LEVEL 35',
      rarity: 'rare',
      claimed: false,
    },
    {
      id: 'r2',
      title: 'Remonto rinkinys x3',
      source: 'DIENINIS LOOT',
      rarity: 'common',
      claimed: false,
    },
    {
      id: 'r3',
      title: 'VIP 1 diena',
      source: 'EVENT — Street Race',
      rarity: 'epic',
      claimed: true,
    },
  ],
  events: [
    {
      id: 'e1',
      title: 'STREET RACE',
      description: 'Trumpos gatvės lenktynės per Vinewood.',
      startsIn: '32 MIN',
      prize: '5,000 $',
      participants: 18,
    },
    {
      id: 'e2',
      title: 'AIR DROP',
      description: 'Kovos dėl oro siuntos Sandy Shores.',
      startsIn: '1H 10M',
      prize: '2,000 CR',
      participants: 42,
    },
  ],
  rankings: {
    playtime: [
      { rank: 1, name: 'Dzonas Brownas · ABC12345', value: '482 H', isSelf: true },
      { rank: 2, name: 'Player2 · DEF67890', value: '461 H' },
      { rank: 3, name: 'Player3 · GHI11111', value: '433 H' },
      { rank: 4, name: 'Player4 · JKL22222', value: '401 H' },
      { rank: 5, name: 'Player5 · MNO33333', value: '388 H' },
      { rank: 6, name: 'Player6 · PQR44444', value: '360 H' },
      { rank: 7, name: 'Player7 · STU55555', value: '341 H' },
      { rank: 8, name: 'Player8 · VWX66666', value: '320 H' },
      { rank: 9, name: 'Player9 · YZA77777', value: '301 H' },
      { rank: 10, name: 'Player10 · BCD88888', value: '280 H' },
    ],
    money: [
      { rank: 1, name: 'RichGuy · RIC11111', value: '$12.4M' },
      { rank: 2, name: 'Dzonas Brownas · ABC12345', value: '$1.26M', isSelf: true },
      { rank: 3, name: 'Player3 · GHI11111', value: '$980K' },
      { rank: 4, name: 'Player4 · JKL22222', value: '$870K' },
      { rank: 5, name: 'Player5 · MNO33333', value: '$760K' },
      { rank: 6, name: 'Player6 · PQR44444', value: '$650K' },
      { rank: 7, name: 'Player7 · STU55555', value: '$540K' },
      { rank: 8, name: 'Player8 · VWX66666', value: '$430K' },
      { rank: 9, name: 'Player9 · YZA77777', value: '$320K' },
      { rank: 10, name: 'Player10 · BCD88888', value: '$210K' },
    ],
    missions: [
      { rank: 1, name: 'Grinder · GRD11111', value: '842' },
      { rank: 2, name: 'Dzonas Brownas · ABC12345', value: '610', isSelf: true },
      { rank: 3, name: 'Player3 · GHI11111', value: '540' },
      { rank: 4, name: 'Player4 · JKL22222', value: '480' },
      { rank: 5, name: 'Player5 · MNO33333', value: '420' },
      { rank: 6, name: 'Player6 · PQR44444', value: '360' },
      { rank: 7, name: 'Player7 · STU55555', value: '300' },
      { rank: 8, name: 'Player8 · VWX66666', value: '240' },
      { rank: 9, name: 'Player9 · YZA77777', value: '180' },
      { rank: 10, name: 'Player10 · BCD88888', value: '120' },
    ],
    rppass: [
      { rank: 1, name: 'Passer · PAS11111', value: 'LVL 88' },
      { rank: 2, name: 'Dzonas Brownas · ABC12345', value: 'LVL 37', isSelf: true },
      { rank: 3, name: 'Player3 · GHI11111', value: 'LVL 31' },
      { rank: 4, name: 'Player4 · JKL22222', value: 'LVL 28' },
      { rank: 5, name: 'Player5 · MNO33333', value: 'LVL 24' },
      { rank: 6, name: 'Player6 · PQR44444', value: 'LVL 20' },
      { rank: 7, name: 'Player7 · STU55555', value: 'LVL 16' },
      { rank: 8, name: 'Player8 · VWX66666', value: 'LVL 12' },
      { rank: 9, name: 'Player9 · YZA77777', value: 'LVL 8' },
      { rank: 10, name: 'Player10 · BCD88888', value: 'LVL 4' },
    ],
    events: [
      { rank: 1, name: 'Racer · RAC11111', value: '52 wins' },
      { rank: 2, name: 'Player2 · DEF67890', value: '41 wins' },
      { rank: 3, name: 'Dzonas Brownas · ABC12345', value: '28 wins', isSelf: true },
      { rank: 4, name: 'Player4 · JKL22222', value: '22 wins' },
      { rank: 5, name: 'Player5 · MNO33333', value: '18 wins' },
      { rank: 6, name: 'Player6 · PQR44444', value: '14 wins' },
      { rank: 7, name: 'Player7 · STU55555', value: '11 wins' },
      { rank: 8, name: 'Player8 · VWX66666', value: '8 wins' },
      { rank: 9, name: 'Player9 · YZA77777', value: '5 wins' },
      { rank: 10, name: 'Player10 · BCD88888', value: '2 wins' },
    ],
  },
  achievements: [
    {
      id: 'a1',
      title: 'FIRST MILLION',
      description: 'Uždirbk $1,000,000',
      unlocked: true,
    },
    {
      id: 'a2',
      title: 'VETERAN',
      description: 'Žaisk 500 valandų',
      unlocked: false,
    },
    {
      id: 'a3',
      title: 'CAR COLLECTOR',
      description: 'Turėk 10 automobilių',
      unlocked: true,
    },
    {
      id: 'a4',
      title: 'STREET KING',
      description: 'Laimėk 50 lenktynių',
      unlocked: false,
    },
  ],
  settings: {
    hudEnabled: true,
    hudOpacity: 85,
    hudScale: 100,
    notifications: true,
    sound: true,
    fpsCounter: false,
    cinematic: false,
    language: 'lt',
  },
};
