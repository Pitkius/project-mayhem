Config = {}

--[[
  TABLETAI – unique itemai, metadata:
    installed_os (string|nil), exploits (table of exploit ids), storage_used (number)
]]
Config.Tablets = {
    basic_tablet = {
        label = 'Paprasta planšetė',
        osLevel = 1,
        storage = 4,
        exploitSlots = 1,
        hackSpeed = 1.0,
        maxRobberyTier = 2, --- iki store
    },
    advanced_tablet = {
        label = 'Pažangi planšetė',
        osLevel = 3,
        storage = 8,
        exploitSlots = 2,
        hackSpeed = 1.25,
        maxRobberyTier = 4,
    },
    military_tablet = {
        label = 'Karinė planšetė',
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
    basic_flashdrive = { label = 'Paprastas USB', capacity = 1 },
    encrypted_flashdrive = { label = 'Šifruotas USB', capacity = 2 },
    military_flashdrive = { label = 'Karinis USB', capacity = 3 },
}

Config.Exploits = {
    signal_jammer = {
        label = 'Signalo slopintuvas',
        desc = 'Sėkmingo įsilaužimo metu vėluoja policijos iškvietimai.',
        delayDispatchSec = 90,
    },
    atm_bypass = {
        label = 'Bankomato apsaugos apeiti',
        desc = 'Lengvesnis bankomato įsilaužimas (+laikas, −sunkumas).',
        hackBonus = { timeMs = 4000, steps = -1 },
    },
    dye_sniffer = {
        label = 'Dažų paketo detektorius',
        desc = 'Įspėja prieš neteisingą sekos kombinaciją (bankomatas).',
    },
    cam_spoof = {
        label = 'Kamerų suklastojimas',
        desc = 'Sėkmingo įsilaužimo metu išjungia artimas kameras.',
        cctvRadius = 35.0,
        cctvSeconds = 180,
    },
}

--- Robbery tier reikalavimai (progresija) — level 1 (apačia) … 5 (viršus)
Config.RobberyTiers = {
    atm = {
        label = 'Bankomatas',
        level = 1,
        minOs = 'basicos',
        minTablet = 'basic_tablet',
        hackProfile = 'atm_security',
    },
    store = {
        label = 'Parduotuvė',
        level = 2,
        minOs = 'blackos',
        minTablet = 'basic_tablet',
        hackProfile = 'store_register',
    },
    bank_fleeca = {
        label = 'Fleeca bankas',
        level = 3,
        minOs = 'ghostos',
        minTablet = 'advanced_tablet',
        hackProfile = 'fleeca_vault',
    },
    bank_main = {
        label = 'Pagrindinis bankas',
        level = 4,
        minOs = 'cipheros',
        minTablet = 'advanced_tablet',
        hackProfile = 'pacific_vault',
    },
    casino = {
        label = 'Kazino',
        level = 4,
        minOs = 'cipheros',
        minTablet = 'military_tablet',
        hackProfile = 'casino_fingerprint',
    },
    vault = {
        label = 'Seifas / federalinis',
        level = 5,
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

--- Lesteris — 1 lygio hacking įrankių kontaktas (grynieji, ne crypto).
--- Senasis Dark Net crypto dealer šioje vietoje pašalintas.
Config.CryptoExchange = {
    enabled = false, --- crypto keitykla pas Lesterį išjungta
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
    --- Tik 1 lygio planšetė + BasicOS USB (pradžia).
    items = {
        { item = 'basic_tablet', price = 3500, payload = nil },
        { item = 'basic_flashdrive', price = 650, payload = { payload_type = 'os', payload_id = 'basicos' } },
        { item = 'basic_flashdrive', price = 900, payload = { payload_type = 'exploit', payload_id = 'atm_bypass' } },
    },
}

Config.ChainItem = 'tow_chain'
Config.DrillItem = 'drill'

--- HackOS planšetės NETWORK vaizdas (UI) — LVL 5 viršuje, LVL 1 apačioje
--- Parduotuvės (ir kiti tieriai) matomi tik po planšetės skenavimo vietoje.
Config.RobberyDiscoveryTiers = {
    store = true,
}

Config.RobberyDiscoverRadius = 20.0

Config.NetworkTargets = {
    { id = 'vault', label = 'Federal vault', security = 5, status = 'Užrakinta', tierId = 'vault' },
    { id = 'bank_main', label = 'Pacific Standard', security = 4, status = 'Apsaugota', tierId = 'bank_main' },
    { id = 'casino', label = 'Diamond Casino', security = 4, status = 'Apsaugota', tierId = 'casino' },
    { id = 'bank_fleeca', label = 'Fleeca bankai', security = 3, status = 'Veikia', tierId = 'bank_fleeca' },
    { id = 'store', label = 'Parduotuvės tinklas', security = 2, status = 'Veikia', tierId = 'store' },
    { id = 'atm', label = 'Bankomatų tinklas', security = 1, status = 'Veikia', tierId = 'atm' },
}

Config.TabletTargetMeta = {
    bank_fleeca = {
        encryption = 'AES-128',
        firewall = 'Aktyvuota',
        rewards = { 'Grynieji', 'Banko duomenys', 'Apsaugos kodai' },
        requirements = 'GhostOS',
    },
    bank_main = {
        encryption = 'AES-256 + HSM',
        firewall = 'Karinė klasė',
        rewards = { 'Grynieji', 'Aukso luitai', 'Federaliniai duomenys' },
        requirements = 'CipherOS',
    },
    atm = {
        encryption = 'DES Legacy',
        firewall = 'Silpna',
        rewards = { 'Grynieji', 'Kortelių duomenys' },
        requirements = 'BasicOS',
    },
    casino = {
        encryption = 'RSA-4096',
        firewall = 'Aktyvuota',
        rewards = { 'Žetonai', 'Seifo kodai', 'VIP duomenys' },
        requirements = 'CipherOS',
    },
    vault = {
        encryption = 'Quantum Seal',
        firewall = 'Federalinė',
        rewards = { 'Prototipo duomenys', 'Biologiniai mėginiai' },
        requirements = 'FederalOS',
    },
    store = {
        encryption = 'TLS 1.2',
        firewall = 'Standartinė',
        rewards = { 'Kasos grynieji', 'Inventoriaus žurnalai' },
        requirements = 'BlackOS',
    },
}

Config.TabletFiles = {
    { id = 'bank_codes', label = 'Banko kodai', locked = false },
    { id = 'police_evidence', label = 'Policijos įrodymai', locked = true },
    { id = 'encrypted_files', label = 'Šifruoti failai', locked = true },
    { id = 'casino_data', label = 'Kazino duomenys', locked = true },
    { id = 'blueprints', label = 'Brėžiniai', locked = true },
}

Config.TabletContracts = {
    { id = 'atm_hack', label = 'Įsilaužti į bankomatą', reward = 2500, tierId = 'atm' },
    { id = 'cctv_off', label = 'Išjungti kameras', reward = 5000, tierId = 'store' },
    { id = 'corp_data', label = 'Vogti korporacinius duomenis', reward = 12000, tierId = 'bank_main' },
}

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
    name = 'mrp_hack_debug_heist',
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
