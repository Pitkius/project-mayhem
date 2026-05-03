Config = Config or {}

Config.Dealership = {
    label = 'Simion Autosalonas',
    office = vector3(-31.97, -1114.07, 26.42),
    officeHeading = 71.20,
    spawn = vector4(-43.73, -1097.18, 26.42, 339.53),
    preview = vector4(-47.25, -1094.42, 26.42, 295.0),
    camera = vector4(-40.80, -1099.20, 28.10, 340.0),
    targetSize = vec3(1.2, 1.2, 1.8),
    targetDistance = 2.0,
    garage = 'pillboxgarage',
}

Config.PreviewColors = {
    { label = 'Balta', idx = 111 },
    { label = 'Juoda', idx = 0 },
    { label = 'Pilka', idx = 4 },
    { label = 'Raudona', idx = 27 },
    { label = 'Melyna', idx = 64 },
    { label = 'Geltona', idx = 88 },
    { label = 'Zalia', idx = 55 },
    { label = 'Oranzine', idx = 38 },
    { label = 'Violetine', idx = 71 },
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

--- Policijos salonas – tas pats NUI kaip Simion; mašinos įrašomos į `pd_*` garažą pagal stotį.
Config.PoliceDealership = {
    label = 'Policijos transporto skyrius',
    targetSize = vec3(1.4, 1.4, 2.0),
    targetDistance = 2.5,
    --- Kokį `garage` įrašyti į DB pagal fivempro_ltpd stoties id
    garageByStation = {
        ls_main = 'pd_ls_main',
        sandy = 'pd_sandy',
        paleto = 'pd_paleto',
    },
    --- Peržiūra / spawn po pirkimo pagal stotį (fivempro_ltpd Config.Stations.id)
    stations = {
        ls_main = {
            spawn = vector4(441.64, -1013.14, 28.62, 175.52),
            --- Mašina šiek tiek į kairę kad nesikirstų su dešiniu UI
            preview = vector4(443.25, -1011.15, 28.62, 265.0),
            camera = vector4(446.45, -1011.45, 30.15, 265.0),
        },
        sandy = {
            spawn = vector4(1869.5, 3695.2, 33.53, 210.0),
            preview = vector4(1872.0, 3693.5, 33.53, 120.0),
            camera = vector4(1875.2, 3694.5, 35.0, 120.0),
        },
        paleto = {
            spawn = vector4(-459.2, 6016.3, 31.49, 45.0),
            preview = vector4(-456.5, 6015.0, 31.49, 225.0),
            camera = vector4(-453.5, 6015.5, 33.2, 225.0),
        },
    },
    PoliceCategoryLabels = {
        patrol = 'Patrulis',
        interceptor = 'Interceptor',
        spec = 'Specialus',
        air = 'Oro tarnyba',
    },
    vehicles = {
        { model = 'police', name = 'Police Cruiser', brand = 'Vapid', category = 'patrol', price = 18000 },
        { model = 'police2', name = 'Police Buffalo', brand = 'Bravado', category = 'patrol', price = 22000 },
        { model = 'police3', name = 'Interceptor', brand = 'Vapid', category = 'interceptor', price = 26000 },
        { model = 'policeb', name = 'Police Bike', brand = 'Western', category = 'patrol', price = 12000 },
        { model = 'sheriff', name = 'Sheriff Cruiser', brand = 'Declasse', category = 'patrol', price = 16000 },
        { model = 'sheriff2', name = 'Sheriff SUV', brand = 'Declasse', category = 'patrol', price = 20000 },
        { model = 'riot', name = 'Riot', brand = 'Brute', category = 'spec', price = 45000 },
    },
}

--- Mechanikų tarnybinis transportas (job: mechanic)
Config.MechanicDealership = {
    label = 'Mechanikų transporto skyrius',
    garageByStation = {
        mech_ls = 'mech_ls',
    },
    stations = {
        mech_ls = {
            spawn = vector4(-347.5, -119.2, 38.95, 246.37),
            preview = vector4(-349.1, -118.05, 38.95, 246.37),
            camera = vector4(-352.0, -115.2, 40.35, 246.37),
        },
    },
    MechanicCategoryLabels = {
        tow = 'Tralas / transportas',
        utility = 'Paslaugos',
    },
    vehicles = {
        { model = 'flatbed', name = 'Flatbed', brand = 'MTL', category = 'tow', price = 32000 },
        { model = 'towtruck', name = 'Tow Truck', brand = 'Vapid', category = 'tow', price = 28000 },
        { model = 'towtruck2', name = 'Tow Truck (did.)', brand = 'Vapid', category = 'tow', price = 32000 },
        { model = 'minivan', name = 'Minivan (įrankiai)', brand = 'Vapid', category = 'utility', price = 12000 },
        { model = 'sadler', name = 'Sadler', brand = 'Vapid', category = 'utility', price = 15000 },
    },
}

--- Greitosios pagalbos transportas (job: ambulance)
Config.EmsDealership = {
    label = 'Greitosios pagalbos transportas',
    garageByStation = {
        ems_ls = 'ems_ls',
    },
    stations = {
        ems_ls = {
            spawn = vector4(-464.42, -324.37, 34.50, 91.30),
            preview = vector4(-462.1, -324.35, 34.50, 91.30),
            camera = vector4(-458.4, -323.2, 36.05, 91.30),
        },
    },
    EmsCategoryLabels = {
        ems = 'Greitoji',
        support = 'Pagalbinis',
    },
    vehicles = {
        { model = 'ambulance', name = 'Greitosios pagalbos auto', brand = 'Brute', category = 'ems', price = 18000 },
        { model = 'granger', name = 'Visureigis', brand = 'Declasse', category = 'support', price = 22000 },
    },
}

