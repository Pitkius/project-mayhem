--[[
  mrp_jobs — VISOS kainos ir atlygio formulės (shared, bet naudoja tik serveris).
  Klientas atlygio niekada neskaičiuoja.
]]

Config = Config or {}
Config.Rewards = Config.Rewards or {}

-- Kokybės koeficientai (naudojami burgeriams / vaisiams).
Config.Rewards.qualityMult = {
    poor = 0.85,
    normal = 1.0,
    good = 1.12,
    perfect = 1.28,
}

-- ── NAFTA ─────────────────────────────────────────────────────────
-- Atlygis TIK pristačius statines į elektrinę.
Config.Rewards.oil = {
    account = 'bank',
    perBarrel = 340,           -- bazinė kaina už statinę
    fullLoadBonus = 500,       -- premija už pilną krovinį (maxLoad statinių)
    safeDeliveryBonus = 250,   -- premija jei transportas nesugadintas
    -- Transporto sugadinimo bauda: procentas nuo (perBarrel*kiekis) pagal engine health.
    damagePenaltyMax = 0.20,   -- iki 20% bauda esant labai sugadintam transportui
    --- Petrocheminė žaliava gumai (inventorius)
    residueItem = 'oil_residue',
    residuePerBarrel = 1,      -- kiek oil_residue už pristatytą statinę
    --- Gamyba: N× oil_residue → 1× rubber (be anglies)
    rubberInput = 1,
    rubberOutput = 1,
    rubberOutputItem = 'rubber',
}

-- ── BURGER: KASININKAS + KEPĖJAS ──────────────────────────────────
-- Atlygis mokamas TIK pilnai įvykdžius užsakymą; dalinamas tarp pozicijų.
Config.Rewards.burger = {
    account = 'cash',
    -- Bazinis atlygis už produktą užsakyme (prieš kokybę / dydį).
    perItem = {
        burger_basic = 120,
        burger_double = 180,
        burger_chicken = 150,
        burger_fries = 70,
        burger_softdrink = 55,
        burger_meal = 260,
    },
    orderBaseBonus = 90,       -- premija už patį įvykdytą užsakymą
    -- Paskirstymas tarp pozicijų (kai dirba abu žaidėjai).
    split = { cashier = 0.35, cook = 0.65 },
    -- Jei trūkstamą poziciją atlieka NPC / solo — visą sumą gauna dirbantis žaidėjas.
    soloKeepsAll = true,
}

-- NPC pirkimas be darbuotojų (kai niekas nedirba) — kainos, už kurias NPC perka.
Config.Rewards.burgerNpcSelfService = {
    enabled = true,            -- ar leisti pirkti maistą iš NPC be darbuotojų
    prices = {                 -- kiek kainuoja žaidėjui nusipirkti (cash)
        burger_basic = 14,
        burger_double = 22,
        burger_chicken = 18,
        burger_fries = 8,
        burger_softdrink = 6,
        burger_meal = 32,
    },
}

-- ── BURGER: VALYTOJAS ─────────────────────────────────────────────
-- Didžioji dalis mokama tik už PILNAI išvalytas abi burgerines.
Config.Rewards.cleaner = {
    account = 'bank',
    perTask = 60,                    -- mažas tarpinis atlygis už atliktą užduotį
    perJointComplete = 5500,         -- premija už pilnai išvalytą vieną burgerinę
    fullRouteBonus = 4000,           -- premija už visą maršrutą (abi burgerinės)
    -- Viso maršruto suma ≈ 60*(~22*2) + 5500*2 + 4000 ≈ 15 000 $
    cooldownSeconds = 2 * 60 * 60,   -- 2 val. po pilno maršruto
    -- Užduočių kiekiai (atsitiktinai generuojama iš intervalų per zoną).
    taskCounts = {
        dining  = { min = 6, max = 9 },   -- salė (stalai, šiukšlės, grindys)
        kitchen = { min = 5, max = 7 },   -- virtuvė
        toilets = { min = 3, max = 5 },   -- tualetai
        other   = { min = 2, max = 3 },   -- langai, sandėlis, drive-through
    },
}

-- ── VAISIAI ───────────────────────────────────────────────────────
Config.Rewards.fruit = {
    account = 'cash',
    -- Kaina už dėžę (pagal vaisiaus rūšį; boxItem -> kaina).
    cratePrice = {
        apple_crate = 480,
        strawberry_crate = 620,
    },
    qualityBonusPerCrate = 60,       -- premija už aukštą kokybę (perfect)
    fullRouteBonus = 300,            -- neprivaloma premija už visą maršrutą
}

-- ── VAPE (vaisinis / paprastas) ───────────────────────────────────
Config.Rewards.vape = {
    account = 'cash',
    simpleBase = 190,                -- paprastas vape skystis (be vaisių) — kaip mrp_drugs
    -- Vaisinio vape kaina = simpleBase * flavor.valueMultiplier (žr. config/vape.lua)
}
