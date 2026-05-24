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
    bank_main = { card = 'security_card_01', thermite = 'thermite', drill = 'drill' },
    casino = {},
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
        cash = { min = 12000, max = 22000 },
        casinochips = { min = 15, max = 40 },
        markedbills = { min = 2, max = 5, worth = 550 },
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
    bank_main = { 'card', 'hack', 'thermite', 'drill', 'loot' },
    casino = { 'hack', 'loot' },
    vault = { 'card', 'hack', 'thermite', 'drill', 'loot' },
}

Config.Robberies.Locations = {
    store = {
        { id = '247_strawberry', label = '24/7 Strawberry', coords = vector3(28.5, -1345.2, 29.5), radius = 1.6 },
        { id = '247_mirror', label = '24/7 Mirror Park', coords = vector3(1163.5, -323.0, 69.2), radius = 1.6 },
        { id = '247_vinewood', label = '24/7 Vinewood', coords = vector3(374.0, 327.5, 103.6), radius = 1.6 },
        { id = '247_sandy', label = '24/7 Sandy', coords = vector3(1961.0, 3742.0, 32.3), radius = 1.6 },
        { id = '247_paleto', label = '24/7 Paleto', coords = vector3(1729.0, 6415.5, 35.0), radius = 1.6 },
        { id = '247_route68', label = '24/7 Route 68', coords = vector3(547.5, 2670.0, 42.2), radius = 1.6 },
    },
    bank_fleeca = {
        { id = 'fleeca_legion', label = 'Fleeca Legion', coords = vector3(147.05, -1046.05, 29.37), radius = 1.8 },
        { id = 'fleeca_greatocean', label = 'Fleeca Great Ocean', coords = vector3(-2957.85, 481.35, 15.70), radius = 1.8 },
        { id = 'fleeca_hawick', label = 'Fleeca Hawick', coords = vector3(-353.55, -55.45, 49.04), radius = 1.8 },
        { id = 'fleeca_delperro', label = 'Fleeca Del Perro', coords = vector3(-1211.45, -335.85, 37.78), radius = 1.8 },
        { id = 'fleeca_route68', label = 'Fleeca Route 68', coords = vector3(1175.65, 2712.90, 38.09), radius = 1.8 },
    },
    bank_main = {
        { id = 'pacific_main', label = 'Pacific Standard', coords = vector3(253.25, 228.45, 101.68), radius = 2.0 },
    },
    casino = {
        { id = 'casino_main', label = 'Diamond Casino — serverinė', coords = vector3(930.45, 46.35, 81.10), radius = 2.0 },
    },
    vault = {
        { id = 'vault_federal', label = 'Federal Vault', coords = vector3(257.10, 221.45, 106.28), radius = 2.0 },
    },
}

--- Progress bar trukmės (ms)
Config.Robberies.Timings = {
    card = 6500,
    thermite = 12000,
    drill = 20000,
    loot = 9000,
}
