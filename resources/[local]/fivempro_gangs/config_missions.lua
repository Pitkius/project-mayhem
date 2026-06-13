--- Turf užėmimas per įtaką (ne per misijas)
Config.TurfCapture = {
    claimThreshold = 100,
    playerCooldownSec = 90,
    turfCooldownSec = 300,
    maxProgressPerMinute = 45,
}

Config.TaskReputation = Config.TaskReputation or {
    drug = 8,
    smuggle = 10,
    theft = 7,
    extortion = 9,
    racing = 6,
    hacking = 12,
    graffiti = 4,
}

--- Tikri paėmimo taškai (serveris renka artimiausią pasirinktam turf).
Config.MissionSites = {
    weapon_run = {
        { coords = vector4(892.22, -3202.58, 5.90, 180.0), label = 'Uosto sandėlis' },
        { coords = vector4(1248.12, -3258.44, 5.80, 270.0), label = 'Konteinerių zona' },
        { coords = vector4(716.48, -962.12, 24.12, 0.0), label = 'La Mesa sandėlis' },
        { coords = vector4(-424.88, -2789.22, 6.00, 45.0), label = 'Uosto rampa' },
    },
    smuggle = {
        { coords = vector4(1248.12, -3258.44, 5.80, 270.0), label = 'Konteinerių zona' },
        { coords = vector4(892.22, -3202.58, 5.90, 180.0), label = 'Uosto sandėlis' },
        { coords = vector4(2554.22, 4672.88, 34.08, 45.0), label = 'Sandy kroviniai' },
        { coords = vector4(-424.88, -2789.22, 6.00, 45.0), label = 'Uosto rampa' },
    },
    drug_run = {
        { coords = vector4(1391.88, 3605.22, 34.98, 200.0), label = 'Sandy sandėlis' },
        { coords = vector4(2434.12, 4968.44, 46.81, 45.0), label = 'Grapeseed' },
        { coords = vector4(-1172.44, -1572.88, 4.66, 125.0), label = 'Vespucci kiemas' },
        { coords = vector4(85.22, -1959.44, 20.75, 320.0), label = 'Grove sandėlis' },
    },
    theft = {
        { coords = vector4(218.52, -768.24, 30.65, 160.0), label = 'Legion aikštelė', vehicle = 'sultan' },
        { coords = vector4(-340.88, -874.22, 31.08, 0.0), label = 'Downtown garažas', vehicle = 'futo' },
        { coords = vector4(1737.22, 3710.44, 34.14, 20.0), label = 'Sandy aikštelė', vehicle = 'bison' },
    },
    extortion = {
        { coords = vector4(24.44, -1347.22, 29.50, 270.0), label = 'Mažmeninė' },
        { coords = vector4(-706.88, -914.44, 19.22, 90.0), label = 'Parduotuvė' },
        { coords = vector4(1163.22, -323.88, 69.21, 100.0), label = 'Mirror Park' },
        { coords = vector4(-1222.44, -908.88, 12.33, 35.0), label = 'Vespucci kiosk' },
    },
    racing = {
        { coords = vector4(-1037.22, -2737.88, 20.17, 330.0), label = 'Oro uosto startas', vehicle = 'sultan2' },
        { coords = vector4(1101.44, -315.22, 67.48, 0.0), label = 'Mirror Park ratas', vehicle = 'elegy2' },
        { coords = vector4(1737.22, 3710.44, 34.14, 20.0), label = 'Sandy trasa', vehicle = 'sultan2' },
    },
    money_launder = {
        { coords = vector4(978.44, 18.22, 81.00, 240.0), label = 'Casino biuras' },
        { coords = vector4(-75.44, -818.88, 326.18, 250.0), label = 'Maze Bank stogas' },
        { coords = vector4(127.22, -1298.44, 29.23, 30.0), label = 'Downtown kiemas' },
        { coords = vector4(-1569.22, -546.88, 34.96, 220.0), label = 'Richman' },
    },
    getaway = {
        { coords = vector4(215.44, -809.88, 30.73, 250.0), label = 'Centro susitikimas', vehicle = 'buffalo2' },
        { coords = vector4(-340.88, -874.22, 31.08, 0.0), label = 'Downtown', vehicle = 'kuruma' },
        { coords = vector4(1248.12, -3258.44, 5.80, 270.0), label = 'Uosto zona', vehicle = 'gburrito2' },
    },
}

Config.MissionVisuals = {
    weapon_run = { prop = 'prop_box_ammo03a' },
    smuggle = { prop = 'prop_cardbordbox_03a' },
    drug_run = { prop = 'prop_mp_drug_package' },
    extortion = { ped = 'g_m_y_lost_01', scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
    money_launder = { prop = 'prop_cash_case_01' },
}

Config.MissionInteractDistance = 4.5
Config.MissionDropDistance = 15.0
Config.MissionMarkerDrawDistance = 90.0

--- Misijos: reputationReward / moneyReward. influenceReward = 0 (numatyta).
Config.MissionTypes = {
  smuggle = {
    label = 'Kontrabandos pristatymas',
    reputationReward = 12,
    moneyReward = 350,
    influenceReward = 0,
    durationMs = 8000,
    gangs = { street = true, cartel = true, mafia = true, biker = true },
    spawnVehicle = 'mule3',
    dropInTurf = true,
  },
  theft = {
    label = 'Transporto vagystė',
    reputationReward = 10,
    moneyReward = 500,
    influenceReward = 0,
    durationMs = 6000,
    gangs = { street = true, biker = true, racing = true },
    requireVehicle = true,
    dropInTurf = true,
    pickupLabel = 'Pavogti transportą',
    dropLabel = 'Pristatyti transportą',
  },
  extortion = {
    label = 'Reketas / NPC spaudimas',
    reputationReward = 14,
    moneyReward = 420,
    influenceReward = 0,
    durationMs = 7000,
    gangs = { street = true, mafia = true, cartel = true },
    dropInTurf = false,
  },
  racing = {
    label = 'Nelegalios lenktynės',
    reputationReward = 9,
    moneyReward = 600,
    influenceReward = 0,
    durationMs = 5000,
    gangs = { racing = true, street = true, biker = true },
    requireVehicle = true,
    dropInTurf = false,
  },
  hacking = {
    label = 'Hacking pagalba',
    reputationReward = 15,
    moneyReward = 250,
    influenceReward = 0,
    gangs = nil,
    requiresHackTier = 'atm',
  },
  drug_run = {
    label = 'Narkotikų siunta',
    reputationReward = 11,
    moneyReward = 380,
    influenceReward = 0,
    durationMs = 7500,
    gangs = { street = true, cartel = true },
    spawnVehicle = 'burrito3',
    dropInTurf = true,
  },
  weapon_run = {
    label = 'Ginklų transportas',
    reputationReward = 13,
    moneyReward = 450,
    influenceReward = 0,
    durationMs = 8000,
    gangs = { biker = true, cartel = true, mafia = true },
    spawnVehicle = 'mule3',
    dropInTurf = true,
  },
  money_launder = {
    label = 'Pinigų plovimo pristatymas',
    reputationReward = 16,
    moneyReward = 800,
    influenceReward = 0,
    durationMs = 9000,
    gangs = { mafia = true },
    spawnVehicle = 'speedo',
    dropInTurf = true,
  },
  getaway = {
    label = 'Pabėgimo vairuotojas',
    reputationReward = 10,
    moneyReward = 550,
    influenceReward = 0,
    durationMs = 6500,
    gangs = { racing = true, street = true },
    requireVehicle = true,
    dropInTurf = false,
  },
}

Config.HackGangRep = {
    atm = 3,
    fleeca = 8,
    store = 2,
}

