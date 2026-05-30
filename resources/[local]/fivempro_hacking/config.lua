Config = {}

--[[
  TABLETAI – unique itemai, metadata:
    installed_os (string|nil), exploits (table of exploit ids), storage_used (number)
]]
Config.Tablets = {
    basic_tablet = {
        label = 'Basic Tablet',
        osLevel = 1,
        storage = 4,
        exploitSlots = 1,
        hackSpeed = 1.0,
        maxRobberyTier = 2, --- iki store
    },
    advanced_tablet = {
        label = 'Advanced Tablet',
        osLevel = 3,
        storage = 8,
        exploitSlots = 2,
        hackSpeed = 1.25,
        maxRobberyTier = 4,
    },
    military_tablet = {
        label = 'Military Tablet',
        osLevel = 5,
        storage = 12,
        exploitSlots = 3,
        hackSpeed = 1.5,
        maxRobberyTier = 6,
    },
}

--[[ OS – įdiegiama per flashdrive ]]
Config.OperatingSystems = {
    basicos = {
        label = 'BasicOS',
        level = 1,
        hackSpeed = 1.0,
        robberies = { 'atm' },
    },
    blackos = {
        label = 'BlackOS',
        level = 2,
        hackSpeed = 1.15,
        robberies = { 'atm', 'store' },
    },
    ghostos = {
        label = 'GhostOS',
        level = 3,
        hackSpeed = 1.3,
        robberies = { 'atm', 'store', 'bank_fleeca' },
    },
    cipheros = {
        label = 'CipherOS',
        level = 4,
        hackSpeed = 1.45,
        robberies = { 'atm', 'store', 'bank_fleeca', 'bank_main', 'casino' },
    },
    federalos = {
        label = 'FederalOS',
        level = 5,
        hackSpeed = 1.6,
        robberies = { 'atm', 'store', 'bank_fleeca', 'bank_main', 'casino', 'vault' },
    },
}

--[[ FLASHDRIVE – metadata: payload_type = os|exploit, payload_id = string ]]
Config.Flashdrives = {
    basic_flashdrive = { label = 'Basic Flashdrive', capacity = 1 },
    encrypted_flashdrive = { label = 'Encrypted Flashdrive', capacity = 2 },
    military_flashdrive = { label = 'Military Flashdrive', capacity = 3 },
}

Config.Exploits = {
    signal_jammer = {
        label = 'Signal Jammer',
        desc = 'Delays police dispatch after successful hack.',
        delayDispatchSec = 90,
    },
    atm_bypass = {
        label = 'ATM Security Bypass',
        desc = 'Easier ATM hack (+time, -difficulty).',
        hackBonus = { timeMs = 4000, steps = -1 },
    },
    dye_sniffer = {
        label = 'Dye Pack Sniffer',
        desc = 'Warns before wrong crack sequence (ATM loot).',
    },
    cam_spoof = {
        label = 'Camera Spoof',
        desc = 'Disables nearby CCTV on successful hack.',
        cctvRadius = 35.0,
        cctvSeconds = 180,
    },
}

--- Robbery tier reikalavimai (progresija)
Config.RobberyTiers = {
    atm = {
        label = 'Bankomatas',
        minOs = 'basicos',
        minTablet = 'basic_tablet',
        hackProfile = 'atm_security',
    },
    store = {
        label = 'Parduotuvė',
        minOs = 'blackos',
        minTablet = 'basic_tablet',
        hackProfile = 'store_register',
    },
    bank_fleeca = {
        label = 'Fleeca bankas',
        minOs = 'ghostos',
        minTablet = 'advanced_tablet',
        hackProfile = 'fleeca_vault',
    },
    bank_main = {
        label = 'Pagrindinis bankas',
        minOs = 'cipheros',
        minTablet = 'advanced_tablet',
        hackProfile = 'pacific_vault',
    },
    casino = {
        label = 'Kazino',
        minOs = 'cipheros',
        minTablet = 'military_tablet',
        hackProfile = 'casino_fingerprint',
    },
    vault = {
        label = 'Vault / federal',
        minOs = 'federalos',
        minTablet = 'military_tablet',
        hackProfile = 'federal_core',
    },
}

--- Hack profiliai (NUI minigame) — kiekvienas tier skirtingas `mode`
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
    federal_core = { mode = 'code', steps = 7, timeMs = 10000, grid = 5, flashMs = 320 },
}

--- Black market (qb-target)
Config.BlackMarket = {
    coords = vector3(707.35, -966.98, 30.41),
    heading = 180.0,
    pedModel = 's_m_y_dealer_01',
    items = {
        { item = 'basic_tablet', price = 2500, payload = nil },
        { item = 'advanced_tablet', price = 8500, payload = nil },
        { item = 'military_tablet', price = 22000, payload = nil },
        { item = 'basic_flashdrive', price = 400, payload = { payload_type = 'os', payload_id = 'basicos' } },
        { item = 'encrypted_flashdrive', price = 1200, payload = { payload_type = 'os', payload_id = 'blackos' } },
        { item = 'encrypted_flashdrive', price = 3500, payload = { payload_type = 'os', payload_id = 'ghostos' } },
        { item = 'military_flashdrive', price = 8000, payload = { payload_type = 'os', payload_id = 'cipheros' } },
        { item = 'basic_flashdrive', price = 900, payload = { payload_type = 'exploit', payload_id = 'signal_jammer' } },
        { item = 'basic_flashdrive', price = 750, payload = { payload_type = 'exploit', payload_id = 'atm_bypass' } },
        { item = 'encrypted_flashdrive', price = 1100, payload = { payload_type = 'exploit', payload_id = 'dye_sniffer' } },
        { item = 'encrypted_flashdrive', price = 1400, payload = { payload_type = 'exploit', payload_id = 'cam_spoof' } },
        { item = 'tow_chain', price = 350, payload = nil },
        { item = 'drill', price = 500, payload = nil },
        { item = 'thermite', price = 2200, payload = nil },
        { item = 'security_card_01', price = 4500, payload = nil },
        { item = 'security_card_02', price = 6500, payload = nil },
    },
}

Config.ChainItem = 'tow_chain'
Config.DrillItem = 'drill'

--- Test vieta (kaip mechanikų sandbox): blip + NPC + $1 parduotuvė visiems heist/hacking itemams.
Config.DebugHeistVendor = {
    enabled = true,
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

--- qb-inventory shop (vienas item = vienas slotas)
Config.DebugHeistShopItems = {
    { item = 'basic_tablet', price = 1 },
    { item = 'advanced_tablet', price = 1 },
    { item = 'military_tablet', price = 1 },
    { item = 'drill', price = 1 },
    { item = 'tow_chain', price = 1 },
    { item = 'thermite', price = 1 },
    { item = 'electronickit', price = 1 },
    { item = 'lockpick', price = 1 },
    { item = 'advancedlockpick', price = 1 },
    { item = 'screwdriverset', price = 1 },
    { item = 'security_card_01', price = 1 },
    { item = 'security_card_02', price = 1 },
    { item = 'goldbar', price = 1 },
    { item = 'markedbills', price = 1 },
}

Config.DebugHeistShop = {
    name = 'fivempro_hack_debug_heist',
    label = 'TEST: Heist įrankiai ($1)',
}

--- Flashdrive su OS/exploit payload ($1) — tas pats principas kaip BlackMarket, tik test kainos.
Config.DebugHeistFlashOffers = {
    { item = 'basic_flashdrive', price = 1, payload = { payload_type = 'os', payload_id = 'basicos' } },
    { item = 'encrypted_flashdrive', price = 1, payload = { payload_type = 'os', payload_id = 'blackos' } },
    { item = 'encrypted_flashdrive', price = 1, payload = { payload_type = 'os', payload_id = 'ghostos' } },
    { item = 'military_flashdrive', price = 1, payload = { payload_type = 'os', payload_id = 'cipheros' } },
    { item = 'military_flashdrive', price = 1, payload = { payload_type = 'os', payload_id = 'federalos' } },
    { item = 'basic_flashdrive', price = 1, payload = { payload_type = 'exploit', payload_id = 'signal_jammer' } },
    { item = 'basic_flashdrive', price = 1, payload = { payload_type = 'exploit', payload_id = 'atm_bypass' } },
    { item = 'encrypted_flashdrive', price = 1, payload = { payload_type = 'exploit', payload_id = 'dye_sniffer' } },
    { item = 'encrypted_flashdrive', price = 1, payload = { payload_type = 'exploit', payload_id = 'cam_spoof' } },
}
