Config = {}

--[[
  Planšetės — lygiai (be OS):
    L1 basic_tablet  → ATM + parduotuvės (optional stealth hack)
    L2 advanced_tablet → Fleeca seifas / deposit
    L3 military_tablet → Pacific + Casino
]]
Config.TabletLevel = {
    basic_tablet = 1,
    advanced_tablet = 2,
    military_tablet = 3,
}

Config.Tablets = {
    basic_tablet = {
        label = 'L1 įsilaužimo planšetė',
        level = 1,
        hackSpeed = 1.0,
        desc = 'Bankomatai ir parduotuvės — stealth hack be PD iškvietimo.',
    },
    advanced_tablet = {
        label = 'L2 įsilaužimo planšetė',
        level = 2,
        hackSpeed = 1.2,
        desc = 'Fleeca banko seifas ir deposit dėžutės.',
    },
    military_tablet = {
        label = 'L3 įsilaužimo planšetė',
        level = 3,
        hackSpeed = 1.4,
        desc = 'Pacific Standard ir Diamond Casino.',
    },
}

--- Senasis OS/USB paliktas tik debug/legacy UI; apiplėšimai OS nereikalauja.
Config.OperatingSystems = {}
Config.Flashdrives = {
    basic_flashdrive = { label = 'Paprastas USB', capacity = 1 },
    encrypted_flashdrive = { label = 'Šifruotas USB', capacity = 2 },
    military_flashdrive = { label = 'Karinis USB', capacity = 3 },
}
Config.Exploits = {}

--- Robbery tier'ai
Config.RobberyTiers = {
    atm = {
        label = 'Bankomatas',
        level = 1,
        minTabletLevel = 0, --- soft be planšetės
        stealthTabletLevel = 1,
        hackProfile = 'atm_security',
    },
    store = {
        label = 'Parduotuvė',
        level = 1,
        minTabletLevel = 0,
        stealthTabletLevel = 1,
        hackProfile = 'store_register',
    },
    bank_fleeca = {
        label = 'Fleeca bankas',
        level = 2,
        minTabletLevel = 0, --- soft (kasininkas) be planšetės
        stealthTabletLevel = 2, --- full vault reikia L2
        hackProfile = 'fleeca_vault',
    },
    bank_main = {
        label = 'Pacific Standard',
        level = 3,
        minTabletLevel = 3,
        stealthTabletLevel = 3,
        hackProfile = 'pacific_vault',
    },
    casino = {
        label = 'Diamond Casino',
        level = 3,
        minTabletLevel = 3,
        stealthTabletLevel = 3,
        hackProfile = 'casino_fingerprint',
    },
}

Config.HackProfiles = {
    atm_security = { mode = 'sequence', steps = 5, timeMs = 14000, grid = 4, flashMs = 400 },
    store_register = { mode = 'reverse', steps = 4, timeMs = 13000, grid = 4, flashMs = 380 },
    store_mirror = { mode = 'sequence', steps = 5, timeMs = 12500, grid = 4, flashMs = 360 },
    store_vinewood = { mode = 'pairs', steps = 4, timeMs = 12000, grid = 4, flashMs = 350 },
    store_sandy = { mode = 'reverse', steps = 5, timeMs = 11500, grid = 4, flashMs = 340 },
    store_paleto = { mode = 'code', steps = 4, timeMs = 13000, grid = 4, flashMs = 370 },
    store_route68 = { mode = 'sequence', steps = 5, timeMs = 12000, grid = 4, flashMs = 360 },
    fleeca_vault = { mode = 'wire', steps = 5, timeMs = 16000, flashMs = 500 },
    fleeca_legion = { mode = 'wire', steps = 4, timeMs = 15000, flashMs = 480 },
    fleeca_greatocean = { mode = 'wire', steps = 5, timeMs = 15500, flashMs = 460 },
    fleeca_hawick = { mode = 'wire', steps = 5, timeMs = 14500, flashMs = 440 },
    fleeca_delperro = { mode = 'wire', steps = 5, timeMs = 14000, flashMs = 420 },
    fleeca_route68 = { mode = 'wire', steps = 6, timeMs = 13500, flashMs = 400 },
    pacific_vault = { mode = 'wire', steps = 7, timeMs = 13000, flashMs = 380 },
    casino_network = { mode = 'sequence', steps = 6, timeMs = 11000, grid = 5, flashMs = 340 },
    casino_fingerprint = { mode = 'trace', steps = 5, timeMs = 18000, traceSpeed = 0.0042, traceWidth = 0.09 },
}

Config.CryptoExchange = {
    enabled = false,
    bankToCryptoRate = 1.0,
    feePercent = 5,
    minAmount = 500,
    maxAmount = 500000,
    currencyLabel = 'Crypto',
}

Config.BlackMarket = {
    coords = vector3(706.8483, -966.9983, 30.4129),
    heading = 22.0825,
    pedModel = 'ig_lestercrest',
    currency = 'cash',
    label = 'Lesteris',
    scenario = 'WORLD_HUMAN_AA_SMOKE',
    --- Tik dabartinei heist sistemai reikalingi daiktai (be OS / USB)
    items = {
        { item = 'basic_tablet', price = 3500, desc = 'L1 — ATM / parduotuvės stealth' },
        { item = 'advanced_tablet', price = 8500, desc = 'L2 — Fleeca seifas + deposit' },
        { item = 'military_tablet', price = 18000, desc = 'L3 — Pacific / Casino' },
        { item = 'tow_chain', price = 800, desc = 'ATM soft — grandinė' },
        { item = 'small_drill', price = 1200, desc = 'Deposit dėžutės' },
        { item = 'drill', price = 4500, desc = 'ATM / seifai / 24/7 seifas' },
        { item = 'thermite', price = 6500, desc = 'Pacific / Casino durys' },
    },
}

Config.ChainItem = 'tow_chain'
Config.DrillItem = 'drill'
Config.SmallDrillItem = 'small_drill'

--- Discovery nebereikalingas — soft apiplėšimai veikia be skenavimo
Config.RobberyDiscoveryTiers = {}
Config.RobberyDiscoverRadius = 20.0

Config.NetworkTargets = {
    { id = 'casino', label = 'Diamond Casino (L3)', security = 3, status = 'Apsaugota', tierId = 'casino' },
    { id = 'bank_main', label = 'Pacific Standard (L3)', security = 3, status = 'Apsaugota', tierId = 'bank_main' },
    { id = 'bank_fleeca', label = 'Fleeca bankai (L2)', security = 2, status = 'Veikia', tierId = 'bank_fleeca' },
    { id = 'store', label = 'Parduotuvės (L1)', security = 1, status = 'Veikia', tierId = 'store' },
    { id = 'atm', label = 'Bankomatai (L1)', security = 1, status = 'Veikia', tierId = 'atm' },
}

Config.TabletTargetMeta = {
    bank_fleeca = {
        encryption = 'AES-128',
        firewall = 'Aktyvuota',
        rewards = { 'Grynieji', 'Deposit dėžutės' },
        requirements = 'L2 planšetė (seifas)',
    },
    bank_main = {
        encryption = 'AES-256',
        firewall = 'Karinė klasė',
        rewards = { 'Grynieji', 'Aukso luitai' },
        requirements = 'L3 planšetė',
    },
    atm = {
        encryption = 'DES Legacy',
        firewall = 'Silpna',
        rewards = { 'Grynieji' },
        requirements = 'L1 optional (stealth)',
    },
    casino = {
        encryption = 'RSA-4096',
        firewall = 'Aktyvuota',
        rewards = { 'Žetonai', 'Grynieji' },
        requirements = 'L3 planšetė',
    },
    store = {
        encryption = 'TLS 1.2',
        firewall = 'Standartinė',
        rewards = { 'Kasos grynieji' },
        requirements = 'L1 optional (stealth)',
    },
}

Config.TabletFiles = {
    { id = 'bank_codes', label = 'Banko kodai', locked = false },
    { id = 'heist_notes', label = 'Apiplėšimų pastabos', locked = false },
}

Config.TabletContracts = {}

Config.DebugHeistVendor = {
    enabled = false,
    pedModel = `s_m_y_dealer_01`,
    coords = vector4(-328.15, -133.62, 39.02, 252.0),
    scenario = 'WORLD_HUMAN_STAND_MOBILE',
    Blip = {
        sprite = 478,
        colour = 1,
        scale = 0.88,
        label = 'TEST: Heist įrankiai',
    },
}

Config.DebugHeistShopItems = {
    { item = 'basic_tablet', price = 1 },
    { item = 'advanced_tablet', price = 1 },
    { item = 'military_tablet', price = 1 },
    { item = 'tow_chain', price = 1 },
    { item = 'small_drill', price = 1 },
    { item = 'drill', price = 1 },
    { item = 'thermite', price = 1 },
}

function Config.GetTabletLevel(itemName)
    return Config.TabletLevel[tostring(itemName or '')] or 0
end
