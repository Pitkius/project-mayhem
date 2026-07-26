Config = Config or {}
Config.Missions = {}

local function add(id, data)
    data.id = id
    data.enabled = data.enabled ~= false
    data.allowedDifficulties = data.allowedDifficulties or { 'easy', 'medium', 'hard', 'extreme' }
    data.cooldownSec = data.cooldownSec or 1800
    Config.Missions[id] = data
end

local indoorRaid = {
    { type = 'approach', label = 'Atvyk į operacijos vietą', minSeconds = 5 },
    { type = 'breach', label = 'Įveik apsaugotą įėjimą', location = 'site', durationMs = 7000 },
    { type = 'enter', label = 'Patek į pastatą', minSeconds = 2 },
    { type = 'eliminate', label = 'Neutralizuok apsaugą', encounter = 'raid' },
    { type = 'collect', label = 'Paimk operacijos objektą', objectiveIndex = 1, durationMs = 8000 },
    { type = 'exit', label = 'Palik pastatą', minSeconds = 2 },
    { type = 'extract', label = 'Pristatyk krovinį kontaktui', minSeconds = 10 },
}

local indoorSearch = {
    { type = 'approach', label = 'Atvyk nepastebėtas', minSeconds = 5 },
    { type = 'breach', label = 'Atrakink alternatyvų įėjimą', location = 'site', durationMs = 7000 },
    { type = 'enter', label = 'Patek į vidų', minSeconds = 2 },
    { type = 'search', label = 'Patikrink pirmą vietą', objectiveIndex = 1, durationMs = 5000 },
    { type = 'eliminate', label = 'Atremk apsaugą', encounter = 'search' },
    { type = 'search', label = 'Surask tikrą objektą', objectiveIndex = 2, durationMs = 9000 },
    { type = 'exit', label = 'Pasitrauk iš pastato', minSeconds = 2 },
    { type = 'extract', label = 'Perduok radinį', minSeconds = 10 },
}

local indoorDefence = {
    { type = 'approach', label = 'Atvyk į gynybos vietą', minSeconds = 5 },
    { type = 'enter', label = 'Užimk poziciją', minSeconds = 2 },
    { type = 'collect', label = 'Paruošk operacijos objektą', objectiveIndex = 1, durationMs = 5000 },
    { type = 'defend', label = 'Atlaikyk puolimą', encounter = 'defence', durationSec = 90 },
    { type = 'exit', label = 'Evakuokis', minSeconds = 2 },
    { type = 'extract', label = 'Pasiek saugią vietą', minSeconds = 10 },
}

local indoorRescue = {
    { type = 'approach', label = 'Atvyk į taikinio vietą', minSeconds = 5 },
    { type = 'breach', label = 'Pralaužk įėjimą', location = 'site', durationMs = 7000 },
    { type = 'enter', label = 'Patek į pastatą', minSeconds = 2 },
    { type = 'eliminate', label = 'Neutralizuok pagrobėjus', encounter = 'raid' },
    { type = 'rescue', label = 'Išlaisvink taikinį', objectiveIndex = 2, durationMs = 8000 },
    { type = 'exit', label = 'Išvesk taikinį', minSeconds = 2 },
    { type = 'extract', label = 'Pasiek saugią vietą', minSeconds = 10 },
}

local indoorSabotage = {
    { type = 'approach', label = 'Atvyk į objekto vietą', minSeconds = 5 },
    { type = 'breach', label = 'Įveik apsaugą', location = 'site', durationMs = 7000 },
    { type = 'enter', label = 'Patek į objektą', minSeconds = 2 },
    { type = 'eliminate', label = 'Neutralizuok apsaugą', encounter = 'raid' },
    { type = 'sabotage', label = 'Paruošk pirmą užtaisą', objectiveIndex = 1, durationMs = 7000 },
    { type = 'sabotage', label = 'Paruošk antrą užtaisą', objectiveIndex = 2, durationMs = 7000 },
    { type = 'exit', label = 'Palik objektą', minSeconds = 2 },
    { type = 'extract', label = 'Pasiek saugų atstumą', minSeconds = 12 },
}

local outdoorDelivery = {
    { type = 'approach', label = 'Atvyk į paėmimo vietą', minSeconds = 5 },
    { type = 'collect', label = 'Paimk krovinį', location = 'site', durationMs = 7000, cargo = true },
    { type = 'eliminate', label = 'Atremk pasalą', encounter = 'outdoor' },
    { type = 'extract', label = 'Pristatyk krovinį', minSeconds = 15 },
}

local outdoorEscort = {
    { type = 'approach', label = 'Susitik su kontaktu', minSeconds = 5 },
    { type = 'collect', label = 'Paruošk transportą', location = 'site', durationMs = 6000 },
    { type = 'defend', label = 'Apsaugok pakrovimą', encounter = 'outdoor', durationSec = 75 },
    { type = 'extract', label = 'Užbaik pristatymą', minSeconds = 15 },
}

local raceContract = {
    { type = 'approach', label = 'Atvyk į starto vietą', minSeconds = 5 },
    { type = 'vehicle', label = 'Perimk užsakymo transportą', minSeconds = 5 },
    { type = 'checkpoint_run', label = 'Įveik kontrakto maršrutą', checkpointCount = 5 },
    { type = 'extract', label = 'Pristatyk automobilį', minSeconds = 10 },
}

-- UNIVERSAL (5)
add('warehouse_break_in', {
    label = 'Warehouse Break-In',
    category = 'universal',
    description = 'Įsilaužk į sandėlį, neutralizuok apsaugą ir išnešk pažymėtą krovinį.',
    sitePool = 'industrial', interior = 'warehouse_large', baseReward = 4200, baseReputation = 12, phases = indoorRaid,
})
add('missing_cargo', {
    label = 'Missing Cargo',
    category = 'universal',
    description = 'Surask dingusį krovinį pagal kelias patikros vietas.',
    sitePool = 'docks', interior = 'warehouse_large', baseReward = 3900, baseReputation = 11, phases = indoorSearch,
})
add('contact_extraction', {
    label = 'Contact Extraction',
    category = 'universal',
    description = 'Ištrauk kontaktą iš priešiškos bazės ir saugiai pasitrauk.',
    sitePool = 'city', interior = 'clubhouse', baseReward = 4600, baseReputation = 14, phases = indoorRaid,
})
add('secret_meeting', {
    label = 'Secret Meeting',
    category = 'universal',
    description = 'Apsaugok slaptą sandorį nuo išdavystės.',
    sitePool = 'rural', baseReward = 4000, baseReputation = 12, phases = outdoorEscort,
})
add('emergency_cash_move', {
    label = 'Emergency Cash Move',
    category = 'universal',
    description = 'Perkelk pinigus prieš prasidedant reidui.',
    sitePool = 'city', baseReward = 4400, baseReputation = 13, phases = outdoorDelivery,
})

-- STREET (5)
add('street_trap_house_defence', {
    label = 'Trap House Defence',
    category = 'street', gangTypes = { street = true },
    description = 'Apsaugok trap house ir evakuok likusį produktą.',
    sitePool = 'city', interior = 'weed_lab', baseReward = 4300, baseReputation = 15, phases = indoorDefence,
})
add('street_stash_house_raid', {
    label = 'Stash House Raid',
    category = 'street', gangTypes = { street = true },
    description = 'Rask konkurentų stash ir išnešk įrodymus.',
    sitePool = 'industrial', interior = 'warehouse_large', baseReward = 4500, baseReputation = 16, phases = indoorSearch,
})
add('street_debt_collection', {
    label = 'Debt Collection',
    category = 'street', gangTypes = { street = true },
    description = 'Surask skolininką ir paimk sutartą paketą.',
    sitePool = 'city', interior = 'clubhouse', baseReward = 3700, baseReputation = 13, phases = indoorSearch,
})
add('street_hostage_rescue', {
    label = 'Block Hostage',
    category = 'street', gangTypes = { street = true },
    description = 'Išlaisvink pagrobtą gaujos kontaktą.',
    sitePool = 'industrial', interior = 'warehouse_large', baseReward = 4900, baseReputation = 18, phases = indoorRescue,
})
add('street_missing_package', {
    label = 'Missing Package',
    category = 'street', gangTypes = { street = true },
    description = 'Atsek dingusį paketą ir išgyvenk pasalą.',
    sitePool = 'city', baseReward = 3800, baseReputation = 14, phases = outdoorDelivery,
})

-- CARTEL (5)
add('cartel_lab_seizure', {
    label = 'Lab Seizure',
    category = 'cartel', gangTypes = { cartel = true },
    description = 'Perimk veikiančią laboratoriją jos nesunaikindamas.',
    sitePool = 'rural', interior = 'meth_lab', baseReward = 5600, baseReputation = 20, phases = indoorRaid,
})
add('cartel_lab_demolition', {
    label = 'Lab Demolition',
    category = 'cartel', gangTypes = { cartel = true },
    description = 'Neutralizuok apsaugą ir paruošk laboratoriją sunaikinimui.',
    sitePool = 'industrial', interior = 'weed_lab', baseReward = 5400, baseReputation = 19, phases = indoorSabotage,
})
add('cartel_bulk_shipment', {
    label = 'Bulk Shipment',
    category = 'cartel', gangTypes = { cartel = true },
    description = 'Apsaugok didelę kontrabandos siuntą.',
    sitePool = 'docks', baseReward = 5800, baseReputation = 21, phases = outdoorEscort,
})
add('cartel_chemist_extraction', {
    label = 'Chemist Extraction',
    category = 'cartel', gangTypes = { cartel = true },
    description = 'Surask specialistą priešiškoje laboratorijoje.',
    sitePool = 'rural', interior = 'meth_lab', baseReward = 6000, baseReputation = 22, phases = indoorRescue,
})
add('cartel_boat_landing', {
    label = 'Boat Landing',
    category = 'cartel', gangTypes = { cartel = true },
    description = 'Priimk pakrantės krovinį ir išgabenk jį iš uosto.',
    sitePool = 'docks', baseReward = 5200, baseReputation = 18, phases = outdoorDelivery,
})

-- MAFIA (5)
add('mafia_protection_collection', {
    label = 'Protection Collection',
    category = 'mafia', gangTypes = { mafia = true },
    description = 'Surink apsaugos sutarties escrow ir atremk vagystę.',
    sitePool = 'city', baseReward = 4400, baseReputation = 15, phases = outdoorDelivery,
})
add('mafia_laundering_ledger', {
    label = 'Laundering Ledger',
    category = 'mafia', gangTypes = { mafia = true },
    description = 'Pakeisk pinigų plovimo dokumentus saugomame biure.',
    sitePool = 'city', interior = 'warehouse_large', baseReward = 5000, baseReputation = 18, phases = indoorSearch,
})
add('mafia_vip_protection', {
    label = 'VIP Protection',
    category = 'mafia', gangTypes = { mafia = true },
    description = 'Apsaugok svarbų kontaktą sandorio metu.',
    sitePool = 'city', baseReward = 5200, baseReputation = 19, phases = outdoorEscort,
})
add('mafia_blackmail_archive', {
    label = 'Blackmail Archive',
    category = 'mafia', gangTypes = { mafia = true },
    description = 'Pavok kompromituojančius dokumentus.',
    sitePool = 'city', interior = 'clubhouse', baseReward = 5100, baseReputation = 19, phases = indoorSearch,
})
add('mafia_armored_cash_pickup', {
    label = 'Armored Cash Pickup',
    category = 'mafia', gangTypes = { mafia = true },
    description = 'Perimk grynųjų transportą ir pristatyk į safe point.',
    sitePool = 'industrial', baseReward = 5500, baseReputation = 20, phases = outdoorDelivery,
})

-- BIKER (5)
add('biker_gunrunner_convoy', {
    label = 'Gunrunner Convoy',
    category = 'biker', gangTypes = { biker = true },
    description = 'Apsaugok ginklų dalių pakrovimą ir pristatymą.',
    sitePool = 'rural', baseReward = 5200, baseReputation = 19, phases = outdoorEscort,
})
add('biker_lost_motorcycle', {
    label = 'Lost Motorcycle',
    category = 'biker', gangTypes = { biker = true },
    description = 'Surask pavogtą motociklą ir pristatyk į saugią vietą.',
    sitePool = 'vehicle', vehicleModel = 'daemon', baseReward = 4100, baseReputation = 15, phases = raceContract,
})
add('biker_custom_parts', {
    label = 'Custom Parts Run',
    category = 'biker', gangTypes = { biker = true },
    description = 'Paimk retas dalis iš saugomo garažo.',
    sitePool = 'industrial', interior = 'warehouse_large', baseReward = 4700, baseReputation = 17, phases = indoorRaid,
})
add('biker_clubhouse_defence', {
    label = 'Clubhouse Defence',
    category = 'biker', gangTypes = { biker = true },
    description = 'Atlaikyk puolimą ir evakuok klubo dokumentus.',
    sitePool = 'rural', interior = 'clubhouse', baseReward = 5000, baseReputation = 19, phases = indoorDefence,
})
add('biker_truck_hijack', {
    label = 'Truck Hijack',
    category = 'biker', gangTypes = { biker = true },
    description = 'Perimk dalių siuntą ir pasitrauk nuo apsaugos.',
    sitePool = 'industrial', baseReward = 4900, baseReputation = 18, phases = outdoorDelivery,
})

-- RACING (5)
add('racing_luxury_order', {
    label = 'Luxury Order',
    category = 'racing', gangTypes = { racing = true },
    description = 'Pavok užsakytą prabangų automobilį.',
    sitePool = 'vehicle', vehicleModel = 'tailgater2', baseReward = 4800, baseReputation = 17, phases = raceContract,
})
add('racing_multi_car_boost', {
    label = 'Multi-Car Boost',
    category = 'racing', gangTypes = { racing = true },
    description = 'Sinchronizuotai paruošk ir išgabenk automobilių užsakymą.',
    sitePool = 'vehicle', vehicleModel = 'sultan2', baseReward = 5400, baseReputation = 20, phases = raceContract,
})
add('racing_illegal_race', {
    label = 'Illegal Race',
    category = 'racing', gangTypes = { racing = true },
    description = 'Įveik nelegalų kontrakto maršrutą.',
    sitePool = 'vehicle', vehicleModel = 'elegy2', baseReward = 4400, baseReputation = 16, phases = raceContract,
})
add('racing_rare_parts', {
    label = 'Rare Parts',
    category = 'racing', gangTypes = { racing = true },
    description = 'Paimk retas dalis iš saugomo garažo.',
    sitePool = 'industrial', interior = 'warehouse_large', baseReward = 4700, baseReputation = 17, phases = indoorSearch,
})
add('racing_tracker_removal', {
    label = 'Tracker Removal',
    category = 'racing', gangTypes = { racing = true },
    description = 'Pervežk automobilį per jammer maršrutą ir pristatyk.',
    sitePool = 'vehicle', vehicleModel = 'jester', baseReward = 5000, baseReputation = 18, phases = raceContract,
})
