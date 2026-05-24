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

--- Misijos: reputationReward / moneyReward. influenceReward = 0 (numatyta).
Config.MissionTypes = {
  smuggle = {
    label = 'Kontrabandos pristatymas',
    reputationReward = 12,
    moneyReward = 350,
    influenceReward = 0,
    durationMs = 8000,
    gangs = { street = true, cartel = true, mafia = true, biker = true },
    pickupOffset = vector3(45.0, 35.0, 0.0),
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
    dropInTurf = true,
  },
  weapon_run = {
    label = 'Ginklų transportas',
    reputationReward = 13,
    moneyReward = 450,
    influenceReward = 0,
    durationMs = 8000,
    gangs = { biker = true, cartel = true, mafia = true },
    dropInTurf = true,
  },
  money_launder = {
    label = 'Pinigų plovimo pristatymas',
    reputationReward = 16,
    moneyReward = 800,
    influenceReward = 0,
    durationMs = 9000,
    gangs = { mafia = true },
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

Config.HackFailHeat = 5
