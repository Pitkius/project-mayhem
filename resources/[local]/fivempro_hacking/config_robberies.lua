Config.Robberies = Config.Robberies or {}

--- Bendri cooldown (sek.)
Config.Robberies.PlayerCooldown = {
    store = 600,
    bank_fleeca = 1800,
    bank_main = 3600,
    casino = 2400,
    vault = 5400,
}

Config.Robberies.LocationCooldown = {
    store = 1200,
    bank_fleeca = 3600,
    bank_main = 7200,
    casino = 5400,
    vault = 10800,
}

--- Item reikalavimai pagal fazę (server tikrina / sunaudoja)
Config.Robberies.ItemNeeds = {
    store = {},
    bank_fleeca = { drill = 'drill' },
    bank_main = { drill = 'drill' },
    casino = { thermite = 'thermite', drill = 'drill' },
    vault = { card = 'security_card_02', thermite = 'thermite', drill = 'drill' },
}

--- Loot (server)
Config.Robberies.Loot = {
    store = {
        cash = { min = 450, max = 1400 },
        markedbills = { min = 0, max = 2, worth = 350 },
    },
    bank_fleeca = {
        cash = { min = 8500, max = 16500 },
        markedbills = { min = 3, max = 7, worth = 500 },
        goldbar = { chance = 0.18, min = 1, max = 1 },
    },
    bank_main = {
        cash = { min = 28000, max = 48000 },
        markedbills = { min = 8, max = 16, worth = 650 },
        goldbar = { chance = 0.45, min = 1, max = 3 },
    },
    casino = {
        cash = { min = 18000, max = 32000 },
        casinochips = { min = 25, max = 55 },
        markedbills = { min = 4, max = 9, worth = 600 },
        goldbar = { chance = 0.4, min = 1, max = 2 },
    },
    vault = {
        cash = { min = 45000, max = 75000 },
        markedbills = { min = 10, max = 20, worth = 800 },
        goldbar = { chance = 0.75, min = 2, max = 5 },
    },
}

--- Fazės: hack = tablet minigame, card, thermite, drill, loot = progress + payout
Config.Robberies.Flow = {
    store = { 'hack', 'loot' },
    bank_fleeca = { 'hack', 'drill', 'loot' },
    bank_main = { 'hack', 'drill', 'loot' },
    casino = { 'hack', 'thermite', 'drill', 'loot', 'loot', 'loot' },
    vault = { 'card', 'hack', 'thermite', 'drill', 'loot' },
}

--- Seifo durys pagal lokacijos id (model + coords)
Config.Robberies.BankVaultDoors = {
    fleeca_legion = { model = 'v_ilev_gb_vauldr', coords = vector3(148.03, -1044.36, 29.51), heading = 160.0, openDelta = -90.0 },
    fleeca_greatocean = { model = 'v_ilev_gb_vauldr', coords = vector3(-2958.54, 482.06, 15.84), heading = 267.0, openDelta = -90.0 },
    fleeca_hawick = { model = 'v_ilev_gb_vauldr', coords = vector3(-352.736, -53.572, 49.18), heading = 161.0, openDelta = -90.0 },
    fleeca_delperro = { model = 'v_ilev_gb_vauldr', coords = vector3(-1210.85, -336.68, 37.98), heading = 207.0, openDelta = -90.0 },
    fleeca_route68 = { model = 'v_ilev_gb_vauldr', coords = vector3(1174.48, 2712.72, 38.19), heading = 0.0, openDelta = -90.0 },
    pacific_main = { model = 'v_ilev_bk_vaultdoor', coords = vector3(255.23, 223.98, 102.39), heading = 160.0, openDelta = -90.0 },
}

Config.Robberies.Locations = {
    store = {
        { id = '247_strawberry', label = '24/7 Strawberry', coords = vector3(28.5, -1345.2, 29.5), radius = 1.6, hackProfile = 'store_register' },
        { id = '247_mirror', label = '24/7 Mirror Park', coords = vector3(1163.5, -323.0, 69.2), radius = 1.6, hackProfile = 'store_mirror' },
        { id = '247_vinewood', label = '24/7 Vinewood', coords = vector3(374.0, 327.5, 103.6), radius = 1.6, hackProfile = 'store_vinewood' },
        { id = '247_sandy', label = '24/7 Sandy', coords = vector3(1961.0, 3742.0, 32.3), radius = 1.6, hackProfile = 'store_sandy' },
        { id = '247_paleto', label = '24/7 Paleto', coords = vector3(1729.0, 6415.5, 35.0), radius = 1.6, hackProfile = 'store_paleto' },
        { id = '247_route68', label = '24/7 Route 68', coords = vector3(547.5, 2670.0, 42.2), radius = 1.6, hackProfile = 'store_route68' },
    },
    bank_fleeca = {
        { id = 'fleeca_legion', label = 'Fleeca Legion', coords = vector3(147.05, -1046.05, 29.37), radius = 1.8, hackProfile = 'fleeca_legion' },
        { id = 'fleeca_greatocean', label = 'Fleeca Great Ocean', coords = vector3(-2957.85, 481.35, 15.70), radius = 1.8, hackProfile = 'fleeca_greatocean' },
        { id = 'fleeca_hawick', label = 'Fleeca Hawick', coords = vector3(-353.55, -55.45, 49.04), radius = 1.8, hackProfile = 'fleeca_hawick' },
        { id = 'fleeca_delperro', label = 'Fleeca Del Perro', coords = vector3(-1211.45, -335.85, 37.78), radius = 1.8, hackProfile = 'fleeca_delperro' },
        { id = 'fleeca_route68', label = 'Fleeca Route 68', coords = vector3(1175.65, 2712.90, 38.09), radius = 1.8, hackProfile = 'fleeca_route68' },
    },
    bank_main = {
        { id = 'pacific_main', label = 'Pacific Standard', coords = vector3(253.25, 228.45, 101.68), radius = 2.0, hackProfile = 'pacific_vault' },
    },
    casino = {
        { id = 'casino_main', label = 'Diamond Casino Heist — apsaugos tinklas', coords = vector3(930.45, 46.35, 81.10), radius = 2.0, hackProfile = 'casino_fingerprint' },
    },
    vault = {
        { id = 'vault_federal', label = 'Federal Vault', coords = vector3(257.10, 221.45, 106.28), radius = 2.0, hackProfile = 'federal_core' },
    },
}

--- Progress bar trukmės (ms)
Config.Robberies.Timings = {
    card = 6500,
    thermite = 12000,
    drill = 20000,
    loot = 9000,
}

--- Diamond Casino Heist (GTA Online DLC) — koordinatės kiekvienai fazei
Config.Robberies.CasinoHeist = {
    lootSteps = 3,
    phaseWaitMs = 180000,
    startNotify = 'Diamond Casino Heist — Silent & Sneaky. Įsilauž į apsaugos tinklą.',
    transitionNotify = {
        afterHack = 'Tinklas išjungtas. Eik prie sandėlio vartų — termitas.',
        afterThermite = 'Vartai atidaryti. Eik į seifą — gręžk užraktą.',
        afterDrill = 'Seifas atviras. Grabink visus pinigų vežimėlius.',
    },
    phases = {
        hack = { coords = vector3(930.45, 46.35, 81.10), radius = 2.0, label = '1/6 — Serverinė: įsilaužimas į tinklą' },
        thermite = { coords = vector3(936.98, 28.17, 81.11), radius = 1.8, label = '2/6 — Sandėlio vartai: termitas' },
        drill = { coords = vector3(967.57, 15.54, 81.11), radius = 1.8, label = '3/6 — Seifas: gręžimas' },
        loot_1 = { coords = vector3(988.45, 31.22, 81.11), radius = 1.6, heading = 58.0, label = '4/6 — Pinigų vežimėlis (A)' },
        loot_2 = { coords = vector3(993.12, 36.88, 81.11), radius = 1.6, heading = 145.0, label = '5/6 — Pinigų vežimėlis (B)' },
        loot_3 = { coords = vector3(998.20, 29.50, 81.11), radius = 1.6, heading = 240.0, label = '6/6 — Pinigų vežimėlis (C)' },
    },
}
