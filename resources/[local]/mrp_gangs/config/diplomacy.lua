Config = Config or {}

Config.TreatyTypes = {
    alliance = {
        label = 'Alliance',
        mutual = true,
        defaultDurationHours = 168,
        blocksWar = true,
        friendlyFirePenalty = 2.0,
        missionSupport = true,
    },
    neutral = {
        label = 'Neutral',
        mutual = false,
        defaultDurationHours = 0,
        blocksWar = false,
        friendlyFirePenalty = 1.0,
    },
    enemy = {
        label = 'Enemy',
        mutual = false,
        defaultDurationHours = 0,
        blocksWar = false,
        enablesWarDeclaration = true,
    },
    ceasefire = {
        label = 'Ceasefire',
        mutual = true,
        defaultDurationHours = 24,
        blocksWar = true,
        blocksHostileActions = true,
        breakPenaltyReputation = 150,
    },
    pact = {
        label = 'Pact',
        mutual = true,
        defaultDurationHours = 72,
        blocksWar = true,
        missionSupport = true,
    },
    protection = {
        label = 'Protection',
        mutual = true,
        defaultDurationHours = 168,
        blocksWar = true,
        requiresTerms = true,
    },
    tribute = {
        label = 'Tribute',
        mutual = true,
        defaultDurationHours = 168,
        blocksWar = true,
        requiresTerms = true,
    },
    temporary_peace = {
        label = 'Temporary Peace',
        mutual = true,
        defaultDurationHours = 48,
        blocksWar = true,
        blocksHostileActions = true,
        breakPenaltyReputation = 100,
    },
}

Config.DiplomacyRules = {
    proposalCooldownSec = 300,
    minDurationHours = 1,
    maxDurationHours = 720,
    maxTributePerHour = 5000,
}

Config.WarRules = {
    preparationSec = 24 * 60 * 60,
    activeSec = 60 * 60,
    settlementSec = 10 * 60,
    cooldownSec = 7 * 24 * 60 * 60,
    maxRosterPerGang = 12,
    minOnlinePerGang = 2,
    maxConcurrentWarsPerGang = 1,
    defenderScoreMultiplier = 1.10,
    underdogMultiplierMax = 1.25,
    scoreToWin = 500,
    objectives = {
        domination = { label = 'Domination', attackerPoints = 120, defenderPoints = 120, durationSec = 600 },
        escort = { label = 'Cargo Escort', attackerPoints = 150, defenderPoints = 100, durationSec = 900 },
        intercept = { label = 'Cargo Intercept', attackerPoints = 130, defenderPoints = 130, durationSec = 720 },
        plant = { label = 'Plant Objective', attackerPoints = 160, defenderPoints = 110, durationSec = 600 },
        cash_transport = { label = 'Cash Transport', attackerPoints = 140, defenderPoints = 120, durationSec = 780 },
    },
}
