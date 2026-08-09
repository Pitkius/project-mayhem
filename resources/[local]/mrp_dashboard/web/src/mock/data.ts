import type { DashboardData, ItemRarity, LootItem } from '@/types/dashboard';

function rarityForLevel(level: number, track: 'free' | 'premium'): ItemRarity {
  if (track === 'premium') {
    if (level >= 90) return 'legendary';
    if (level >= 70) return 'epic';
    if (level >= 40) return 'rare';
    if (level >= 20) return 'uncommon';
    return 'common';
  }
  if (level >= 80) return 'epic';
  if (level >= 50) return 'rare';
  if (level >= 25) return 'uncommon';
  return 'common';
}

function rpRewards() {
  const rewards = [];
  for (let level = 1; level <= 100; level++) {
    const locked = level > 37;
    const claimed = level < 35;
    if (level % 5 === 0) {
      rewards.push({
        level,
        track: 'free' as const,
        label: level % 10 === 0 ? `${level * 50} CR` : `${level * 100} $`,
        rarity: rarityForLevel(level, 'free'),
        claimed: claimed && level % 5 === 0,
        locked,
      });
    }
    rewards.push({
      level,
      track: 'premium' as const,
      label: level % 10 === 0 ? 'VIP 1d' : `${100 + level * 10} CR`,
      rarity: rarityForLevel(level, 'premium'),
      claimed: claimed,
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
  { id: 'l5', name: 'Lockpick', rarity: 'uncommon', itemName: 'lockpick', amount: 2, icon: '🔓' },
  { id: 'l6', name: 'Radio', rarity: 'uncommon', itemName: 'radio', amount: 1, icon: '📻' },
  { id: 'l7', name: '250 Credits', rarity: 'uncommon', itemName: 'credits', amount: 250, icon: '💎' },
  { id: 'l8', name: 'Kuro bakelis', rarity: 'rare', itemName: 'jerrycan', amount: 1, icon: '⛽' },
  { id: 'l9', name: 'Telefonų case', rarity: 'rare', itemName: 'phone_case', amount: 1, icon: '📱' },
  { id: 'l10', name: '500 Credits', rarity: 'rare', itemName: 'credits', amount: 500, icon: '💎' },
  { id: 'l11', name: 'VIP 1 diena', rarity: 'epic', itemName: 'vip_day', amount: 1, icon: '👑' },
  { id: 'l12', name: 'Importų kuponas A', rarity: 'epic', itemName: 'import_coupon_a', amount: 1, icon: '🎟️' },
  { id: 'l13', name: 'Exclusive plate', rarity: 'legendary', itemName: 'plate_exclusive', amount: 1, icon: '🔤' },
  { id: 'l14', name: '1,500 Credits', rarity: 'legendary', itemName: 'credits', amount: 1500, icon: '💎' },
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
    rewards: rpRewards(),
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
      { rank: 1, name: 'Dzonas Brownas', value: '482 H', isSelf: true },
      { rank: 2, name: 'Player2', value: '461 H' },
      { rank: 3, name: 'Player3', value: '433 H' },
      { rank: 4, name: 'Player4', value: '401 H' },
      { rank: 5, name: 'Player5', value: '388 H' },
    ],
    money: [
      { rank: 1, name: 'RichGuy', value: '$12.4M' },
      { rank: 2, name: 'Dzonas Brownas', value: '$1.26M', isSelf: true },
      { rank: 3, name: 'Player3', value: '$980K' },
    ],
    missions: [
      { rank: 1, name: 'Grinder', value: '842' },
      { rank: 2, name: 'Dzonas Brownas', value: '610', isSelf: true },
      { rank: 3, name: 'Player3', value: '540' },
    ],
    rppass: [
      { rank: 1, name: 'Passer', value: 'LVL 88' },
      { rank: 2, name: 'Dzonas Brownas', value: 'LVL 37', isSelf: true },
      { rank: 3, name: 'Player3', value: 'LVL 31' },
    ],
    events: [
      { rank: 1, name: 'Racer', value: '52 wins' },
      { rank: 2, name: 'Player2', value: '41 wins' },
      { rank: 3, name: 'Dzonas Brownas', value: '28 wins', isSelf: true },
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
