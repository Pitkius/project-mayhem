Config.Robberies = Config.Robberies or {}

--[[
  Apiplėšimų srautai (be OS):
    L1 ATM/store — soft be planšetės (PD alert); L1 hack = stealth
    L1 store: soft (kasininkas → tikra kasa) + Perlas (pati lauži) + seifas (drill 2 min)
    L2 Fleeca — soft (kasininkas); L2 hack = seifas + silent
    L3 Pacific/Casino — reikia L3 planšetės
]]

Config.Robberies.PlayerCooldown = {
    store = 600,
    bank_fleeca = 1800,
    bank_main = 3600,
    casino = 2400,
    atm = 900,
}

Config.Robberies.LocationCooldown = {
    store = 1200,
    bank_fleeca = 3600,
    bank_main = 7200,
    casino = 5400,
    atm = 1800,
}

Config.Robberies.ItemNeeds = {
    store = {},
    bank_fleeca = { drill = 'drill' }, --- full vault
    bank_main = { thermite = 'thermite', drill = 'drill' },
    casino = { thermite = 'thermite', drill = 'drill' },
}

Config.Robberies.Loot = {
    --- Soft / stealth: tikra kasa (kasininkas arba grab po L1 hack)
    store = {
        cash = { min = 450, max = 1400 },
        markedbills = { min = 0, max = 2, worth = 350 },
    },
    --- Perlas terminalas — žaidėjas laužia pats
    store_perlas = {
        cash = { min = 180, max = 520 },
        markedbills = { min = 0, max = 1, worth = 250 },
    },
    --- Galinis seifas (drill + 2 min)
    store_safe = {
        cash = { min = 2200, max = 4800 },
        markedbills = { min = 1, max = 4, worth = 400 },
    },
    bank_fleeca = {
        cash = { min = 8500, max = 16500 },
        markedbills = { min = 3, max = 7, worth = 500 },
        goldbar = { chance = 0.18, min = 1, max = 1 },
    },
    bank_fleeca_soft = {
        cash = { min = 2200, max = 4800 },
        markedbills = { min = 1, max = 3, worth = 400 },
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
    deposit_box = {
        cash = { min = 800, max = 2200 },
        markedbills = { min = 0, max = 2, worth = 450 },
        goldbar = { chance = 0.08, min = 1, max = 1 },
    },
}

--- Full (su planšete) fazės
Config.Robberies.Flow = {
    store = { 'hack' }, --- L1 stealth: atrakinamos kasa / Perlas / seifas (be PD)
    bank_fleeca = { 'hack', 'drill', 'loot' },
    bank_main = { 'hack', 'thermite', 'drill', 'loot' },
    casino = { 'hack', 'thermite', 'drill', 'loot', 'loot', 'loot' },
}

--- Soft Fleeca / store teller
Config.Robberies.Teller = {
    aimSeconds = 12, --- kiek laikyti taikiklį kol krauna
    bagProp = 'prop_money_bag_01',
    bagThrowForce = 2.5,
    lootKey = 'bank_fleeca_soft',
    storeLootKey = 'store',
    --- Kai nustoja taikytis po pinigų — PD alert
    alertOnStopAim = true,
}

--- Parduotuvės šoninis grobis (Perlas + seifas). Atrakinama po soft maišo arba L1 hack.
Config.Robberies.StoreSide = {
    unlockMinutes = 12,
    perlasProgressMs = 9000,
    perlasMinigame = { mode = 'sequence', label = 'Perlas terminalas — įsilaužimas', data = { length = 4 } },
    safeMinigame = { mode = 'drill', label = 'Parduotuvės seifas — W/S galia, A/D kryptis', data = { depthTarget = 100, stages = 5, timeMs = 45000 } },
    safeDrillMs = 120000, --- 2 minutės gręžimo
    safeItem = 'drill',
    alertSafeNoHack = '24/7 — kas nors gręžia seifą',
    alertPerlasNoHack = '24/7 — Perlas terminalo apiplėšimas',
}

--- Kasininkai Fleeca (spawn jei nėra)
Config.Robberies.BankTellers = {
    fleeca_legion = { model = 'ig_bankman', coords = vector4(149.41, -1042.15, 29.37, 340.0) },
    fleeca_greatocean = { model = 'ig_bankman', coords = vector4(-2961.12, 482.95, 15.70, 88.0) },
    fleeca_hawick = { model = 'ig_bankman', coords = vector4(-351.25, -51.35, 49.04, 340.0) },
    fleeca_delperro = { model = 'ig_bankman', coords = vector4(-1211.95, -331.95, 37.78, 27.0) },
    fleeca_route68 = { model = 'ig_bankman', coords = vector4(1174.85, 2708.35, 38.09, 180.0) },
}

--- Booth durys (atrakinamos po soft pinigų)
Config.Robberies.BoothDoors = {
    fleeca_legion = { model = 'v_ilev_gb_teldr', coords = vector3(149.62, -1047.15, 29.50), radius = 2.0 },
    fleeca_greatocean = { model = 'v_ilev_gb_teldr', coords = vector3(-2956.15, 484.15, 15.85), radius = 2.0 },
    fleeca_hawick = { model = 'v_ilev_gb_teldr', coords = vector3(-351.35, -56.25, 49.15), radius = 2.0 },
    fleeca_delperro = { model = 'v_ilev_gb_teldr', coords = vector3(-1214.85, -334.85, 37.90), radius = 2.0 },
    fleeca_route68 = { model = 'v_ilev_gb_teldr', coords = vector3(1172.25, 2713.15, 38.20), radius = 2.0 },
}

--- Deposit dėžutės (po vault hack / atidaryto seifo)
Config.Robberies.DepositBoxes = {
    fleeca_legion = {
        { coords = vector3(148.55, -1049.85, 29.35), heading = 160.0 },
        { coords = vector3(146.95, -1049.25, 29.35), heading = 160.0 },
        { coords = vector3(145.35, -1048.65, 29.35), heading = 160.0 },
    },
    fleeca_greatocean = {
        { coords = vector3(-2954.25, 484.55, 15.68), heading = 267.0 },
        { coords = vector3(-2954.45, 482.85, 15.68), heading = 267.0 },
    },
    fleeca_hawick = {
        { coords = vector3(-350.15, -58.85, 49.02), heading = 161.0 },
        { coords = vector3(-351.55, -59.35, 49.02), heading = 161.0 },
    },
    fleeca_delperro = {
        { coords = vector3(-1208.55, -338.25, 37.76), heading = 207.0 },
        { coords = vector3(-1209.85, -339.15, 37.76), heading = 207.0 },
    },
    fleeca_route68 = {
        { coords = vector3(1171.55, 2715.85, 38.07), heading = 0.0 },
        { coords = vector3(1173.15, 2715.85, 38.07), heading = 0.0 },
    },
    pacific_main = {
        { coords = vector3(259.85, 217.55, 101.68), heading = 160.0 },
        { coords = vector3(261.25, 218.15, 101.68), heading = 160.0 },
        { coords = vector3(258.45, 216.95, 101.68), heading = 160.0 },
        { coords = vector3(257.05, 216.35, 101.68), heading = 160.0 },
    },
}

Config.Robberies.BankVaultDoors = {
    fleeca_legion = { model = 'v_ilev_gb_vauldr', coords = vector3(148.03, -1044.36, 29.51), heading = 160.0, openDelta = -90.0 },
    fleeca_greatocean = { model = 'v_ilev_gb_vauldr', coords = vector3(-2958.54, 482.06, 15.84), heading = 267.0, openDelta = -90.0 },
    fleeca_hawick = { model = 'v_ilev_gb_vauldr', coords = vector3(-352.736, -53.572, 49.18), heading = 161.0, openDelta = -90.0 },
    fleeca_delperro = { model = 'v_ilev_gb_vauldr', coords = vector3(-1210.85, -336.68, 37.98), heading = 207.0, openDelta = -90.0 },
    fleeca_route68 = { model = 'v_ilev_gb_vauldr', coords = vector3(1174.48, 2712.72, 38.19), heading = 0.0, openDelta = -90.0 },
    pacific_main = { model = 'v_ilev_bk_vaultdoor', coords = vector3(255.23, 223.98, 102.39), heading = 160.0, openDelta = -90.0 },
}

Config.Robberies.HeistDoors = {
    fleeca_legion = {
        { unlockAfter = 'hack', doors = {
            { model = 'v_ilev_gb_vaubar', coords = vector3(148.03, -1044.36, 29.51), heading = 160.0, radius = 2.5 },
        }},
    },
    fleeca_greatocean = {
        { unlockAfter = 'hack', doors = {
            { model = 'v_ilev_gb_vaubar', coords = vector3(-2958.54, 482.06, 15.84), heading = 267.0, radius = 2.5 },
        }},
    },
    fleeca_hawick = {
        { unlockAfter = 'hack', doors = {
            { model = 'v_ilev_gb_vaubar', coords = vector3(-352.736, -53.572, 49.18), heading = 161.0, radius = 2.5 },
        }},
    },
    fleeca_delperro = {
        { unlockAfter = 'hack', doors = {
            { model = 'v_ilev_gb_vaubar', coords = vector3(-1210.85, -336.68, 37.98), heading = 207.0, radius = 2.5 },
        }},
    },
    fleeca_route68 = {
        { unlockAfter = 'hack', doors = {
            { model = 'v_ilev_gb_vaubar', coords = vector3(1174.48, 2712.72, 38.19), heading = 0.0, radius = 2.5 },
        }},
    },
    pacific_main = {
        { unlockAfter = 'hack', doors = {
            { model = 'v_ilev_genbankdoor2', coords = vector3(232.61, 216.20, 106.28), heading = 340.0, radius = 2.5 },
            { model = 'v_ilev_genbankdoor2', coords = vector3(231.62, 216.56, 106.28), heading = 340.0, radius = 2.5 },
            { model = 'v_ilev_bk_door', coords = vector3(256.88, 220.13, 106.28), heading = 160.0, radius = 2.5 },
        }},
        { unlockAfter = 'thermite', doors = {
            { model = 'v_ilev_bk_vaultdoor', coords = vector3(255.23, 223.98, 102.39), heading = 160.0, radius = 4.0, openDelta = -90.0 },
        }},
    },
}

Config.Robberies.Locations = {
    --- cashRegister = tikra kasa (soft = kasininkas; stealth = grab po L1)
    --- perlas = optional Perlas terminalas (pati lauži)
    --- safe = galinis seifas (drill + 2 min)
    store = {
        {
            id = '247_strawberry',
            label = '24/7 Strawberry',
            coords = vector3(28.5, -1345.2, 29.5),
            radius = 1.6,
            hackProfile = 'store_register',
            tellerCoords = vector4(24.47, -1346.62, 29.50, 271.66),
            cashRegister = { coords = vector3(25.11, -1347.28, 29.50), radius = 0.65 },
            perlas = { coords = vector3(24.55, -1344.95, 29.50), radius = 0.65 },
            safe = { coords = vector3(28.21, -1339.14, 29.50), radius = 0.9 },
        },
        {
            id = '247_mirror',
            label = '24/7 Mirror Park',
            coords = vector3(1163.5, -323.0, 69.2),
            radius = 1.6,
            hackProfile = 'store_mirror',
            tellerCoords = vector4(1164.71, -322.94, 69.21, 101.72),
            cashRegister = { coords = vector3(1164.20, -322.50, 69.21), radius = 0.65 },
            perlas = { coords = vector3(1165.55, -324.10, 69.21), radius = 0.65 },
            safe = { coords = vector3(1169.25, -313.85, 69.20), radius = 0.9 },
        },
        {
            id = '247_vinewood',
            label = '24/7 Vinewood',
            coords = vector3(374.0, 327.5, 103.6),
            radius = 1.6,
            hackProfile = 'store_vinewood',
            tellerCoords = vector4(372.66, 326.98, 103.57, 253.73),
            cashRegister = { coords = vector3(373.15, 326.40, 103.57), radius = 0.65 },
            perlas = { coords = vector3(373.85, 328.55, 103.57), radius = 0.65 },
            safe = { coords = vector3(378.15, 333.35, 103.57), radius = 0.9 },
        },
        {
            id = '247_sandy',
            label = '24/7 Sandy',
            coords = vector3(1961.0, 3742.0, 32.3),
            radius = 1.6,
            hackProfile = 'store_sandy',
            tellerCoords = vector4(1959.90, 3739.88, 32.34, 316.0),
            cashRegister = { coords = vector3(1960.25, 3740.35, 32.34), radius = 0.65 },
            --- be Perlas (viena kasa)
            safe = { coords = vector3(1959.25, 3748.85, 32.34), radius = 0.9 },
        },
        {
            id = '247_paleto',
            label = '24/7 Paleto',
            coords = vector3(1729.0, 6415.5, 35.0),
            radius = 1.6,
            hackProfile = 'store_paleto',
            tellerCoords = vector4(1728.07, 6415.63, 35.04, 242.95),
            cashRegister = { coords = vector3(1728.55, 6415.15, 35.04), radius = 0.65 },
            --- be Perlas (viena kasa)
            safe = { coords = vector3(1734.75, 6420.75, 35.04), radius = 0.9 },
        },
        {
            id = '247_route68',
            label = '24/7 Route 68',
            coords = vector3(547.5, 2670.0, 42.2),
            radius = 1.6,
            hackProfile = 'store_route68',
            tellerCoords = vector4(549.13, 2670.85, 42.16, 99.39),
            cashRegister = { coords = vector3(548.65, 2670.40, 42.16), radius = 0.65 },
            perlas = { coords = vector3(549.85, 2669.15, 42.16), radius = 0.65 },
            safe = { coords = vector3(546.40, 2662.80, 42.16), radius = 0.9 },
        },
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
        { id = 'casino_main', label = 'Diamond Casino Heist', coords = vector3(924.77, 46.85, 81.11), radius = 2.0, hackProfile = 'casino_fingerprint' },
    },
}

Config.Robberies.Timings = {
    card = 6500,
    thermite = 12000,
    drill = 20000,
    loot = 9000,
    deposit = 14000,
    tellerFill = 12000,
    storeCashGrab = 4500,
    storePerlas = 9000,
    storeSafe = 120000,
}

Config.Robberies.CasinoHeist = {
    lootSteps = 3,
    phaseWaitMs = 180000,
    startNotify = 'Diamond Casino Heist (L3). Eik prie aptarnavimo įėjimo.',
    transitionNotify = {
        afterHack = 'Tinklas išjungtas. Eik prie sandėlio zonos — termitas.',
        afterThermite = 'Vartai atidaryti. Eik prie seifo zonos — gręžk.',
        afterDrill = 'Seifas atviras. Grabink pinigų kratas.',
    },
    phases = {
        hack = { coords = vector3(924.77, 46.85, 81.11), radius = 2.0, label = '1/6 — Aptarnavimo įėjimas: hack' },
        thermite = { coords = vector3(936.52, 55.08, 81.11), radius = 2.0, label = '2/6 — Sandėlio zona: termitas' },
        drill = { coords = vector3(948.32, 33.44, 81.11), radius = 2.0, label = '3/6 — Seifo zona: gręžimas' },
        loot_1 = { coords = vector3(923.50, 48.20, 81.11), radius = 1.8, heading = 58.0, label = '4/6 — Grobis (A)' },
        loot_2 = { coords = vector3(926.80, 44.50, 81.11), radius = 1.8, heading = 145.0, label = '5/6 — Grobis (B)' },
        loot_3 = { coords = vector3(920.20, 44.80, 81.11), radius = 1.8, heading = 240.0, label = '6/6 — Grobis (C)' },
    },
}
