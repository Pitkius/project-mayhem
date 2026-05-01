Config = Config or {}

Config.Dealership = {
    label = 'Simion Autosalonas',
    office = vector3(-31.97, -1114.07, 26.42),
    officeHeading = 71.20,
    spawn = vector4(-43.73, -1097.18, 26.42, 339.53),
    targetSize = vec3(1.2, 1.2, 1.8),
    targetDistance = 2.0,
    garage = 'pillboxgarage',
}

Config.CategoryLabels = {
    compacts = 'Compact / Economy',
    sedans = 'Sedanai',
    suvs = 'SUV / Dzipai',
    wagons = 'Universalai / Wagons',
    coupes = 'Coupe',
    muscle = 'Muscle',
    sportsclassics = 'Sports Classics',
    sports = 'Sport Cars',
    super = 'Super / Hyper Cars',
    motorcycles = 'Motociklai',
    offroad = 'Offroad',
    industrial = 'Industrial',
    utility = 'Utility',
    vans = 'Vans',
    cycles = 'Dviraciai',
    boats = 'Valtys',
    helicopters = 'Helikopteriai',
    planes = 'Lektuvai',
    service = 'Service',
    emergency = 'Emergency',
    military = 'Military',
    commercial = 'Commercial',
    trains = 'Traukiniai',
    openwheel = 'Open Wheel',
}

-- Specific RP-balanced prices from your list. Any model not listed here
-- falls back to QBShared.Vehicles price.
Config.PriceOverrides = {
    -- Sedans
    asea = 8000, asterope = 12000, fugitive = 18000, intruder = 15000, premier = 14000,
    primo = 13000, regina = 10000, stanier = 16000, stratum = 20000, tailgater = 25000, washington = 14000,

    -- SUVs
    baller = 60000, baller2 = 65000, cavalcade = 40000, cavalcade2 = 45000, contender = 70000,
    dubsta = 90000, fq2 = 35000, granger = 55000, gresley = 30000, huntley = 42000,
    landstalker = 38000, mesa = 50000, patriot = 80000, radi = 32000, rocoto = 45000,
    seminole = 28000, xls = 75000,

    -- Sports
    alpha = 70000, banshee = 90000, buffalo = 50000, buffalo2 = 65000, carbonizzare = 120000,
    comet2 = 110000, feltzer2 = 100000, furoregt = 140000, fusilade = 60000, jester = 130000,
    kuruma = 85000, massacro = 125000, ninef = 140000, schafter3 = 95000, schwarzer = 75000, sultan = 60000,

    -- Super
    adder = 1000000, bullet = 250000, cheetah = 650000, entityxf = 800000, fmj = 900000,
    infernus = 500000, nero = 1200000, osiris = 1100000, reaper = 950000, t20 = 1300000,
    tempesta = 1000000, turismor = 700000, tyrus = 1200000, vacca = 450000, voltic = 300000, zentorno = 900000,

    -- Motorcycles
    akuma = 45000, bagger = 30000, bati = 60000, carbonrs = 70000, daemon = 28000, double = 55000,
    hakuchou = 80000, hexer = 25000, innovation = 35000, nemesis = 40000, pcj = 30000,
    ruffian = 35000, sanchez = 20000, sovereign = 50000, vader = 32000,

    -- Compact
    blista = 12000, brioso = 18000, dilettante = 10000, issi2 = 14000, panto = 9000,
    prairie = 13000, rhapsody = 11000,

    -- Offroad
    bifta = 35000, blazer = 15000, dune = 80000, rebel = 25000, sandking = 90000, trophytruck = 150000,

    -- Coupes
    cogcabrio = 45000, exemplar = 60000, f620 = 55000, felon = 50000, felon2 = 65000,
    jackal = 48000, oracle = 52000, oracle2 = 58000, zion = 50000, zion2 = 55000,
}

