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
    compacts = 'Kompaktiniai / ekonominiai',
    sedans = 'Sedanai',
    suvs = 'SUV / visureigiai',
    wagons = 'Universalai',
    coupes = 'Kupė',
    muscle = 'Muscle',
    sportsclassics = 'Sporto klasika',
    sports = 'Sportiniai',
    super = 'Super / hiperautomobiliai',
    motorcycles = 'Motociklai',
    offroad = 'Visureigiai',
    industrial = 'Pramoniniai',
    utility = 'Paslaugų',
    vans = 'Furgonai',
    cycles = 'Dviraciai',
    boats = 'Valtys',
    helicopters = 'Sraigtasparniai',
    planes = 'Lėktuvai',
    service = 'Paslaugų transportas',
    emergency = 'Skubios pagalbos',
    military = 'Kariniai',
    commercial = 'Komerciniai',
    trains = 'Traukiniai',
    openwheel = 'Formulės',
}

Config.UsePerformancePricing = true

--- Rankinės išimtys (darbo transportas ir pan.) — ne performance formulė.
Config.ManualPriceOverrides = {}

--- Seni rankiniai override (naudojami tik jei UsePerformancePricing = false).
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
    asbo = 12000, club = 9000, weevil = 10000, boor = 22000,
}

--- Civilinis Simion: tik šios QB `category` reikšmės (likusios – nerodomos).
Config.CivilianShopAllowedCategories = {
    compacts = true,
    sedans = true,
    suvs = true,
    wagons = true,
    coupes = true,
    muscle = true,
    sportsclassics = true,
    sports = true,
    super = true,
    motorcycles = true,
    offroad = true,
    utility = true,
    vans = true,
    cycles = true,
}

--- Performance kainų fallback ribos (kai vehicle_perf išjungtas).
Config.CivilianPriceBands = {
    compacts = { min = 8000, max = 65000 },
    cycles = { min = 500, max = 15000 },
    sedans = { min = 45000, max = 320000 },
    wagons = { min = 40000, max = 280000 },
    coupes = { min = 90000, max = 380000 },
    suvs = { min = 55000, max = 420000 },
    sports = { min = 200000, max = 650000 },
    sportsclassics = { min = 80000, max = 450000 },
    super = { min = 480000, max = 1500000 },
    muscle = { min = 70000, max = 380000 },
    offroad = { min = 35000, max = 280000 },
    utility = { min = 25000, max = 120000 },
    vans = { min = 25000, max = 120000 },
    motorcycles = { min = 15000, max = 180000 },
    _default = { min = 8000, max = 4500000 },
}

--- Papildomas blokas civiliniam katalogui (šarvai / ginklai / arena / aiškūs dubliatai).
Config.CivilianShopExtraBlockedModels = {
    ninef2 = true, -- Obey 9F Cabrio – ne parduodamas
    kuruma2 = true, voltic2 = true, caracara2 = true, tampa3 = true,
    vigilante = true, scramjet = true, toreador = true, stromberg = true,
    dune3 = true, dune4 = true, dune5 = true,
    deathbike = true, deathbike2 = true, deathbike3 = true,
    baller2 = true, baller3 = true, baller4 = true, baller5 = true, baller6 = true, baller7 = true,
    blista2 = true, blista3 = true, kanjo = true, kanjosj = true,
    brioso3 = true,
    issi4 = true, issi5 = true, issi6 = true, issi7 = true,
    buffalo2 = true, buffalo4 = true, buffalo5 = true,
    dominator2 = true, dominator3 = true, dominator4 = true, dominator7 = true, dominator8 = true, dominator9 = true,
    schafter4 = true,
    sultan2 = true, sultan3 = true, sultanrs = true,
    comet3 = true, comet4 = true, comet5 = true, comet6 = true, comet7 = true,
    jester2 = true, jester4 = true,
    elegy = true,
    futo2 = true,
    glendale2 = true, primo2 = true, dilettante2 = true,
    dukes2 = true,
    patriot2 = true, patriot3 = true,
    jb7002 = true,
    impaler2 = true, impaler3 = true, impaler4 = true, impaler5 = true, impaler6 = true,
    imperator = true, imperator2 = true, imperator3 = true,
    gauntlet2 = true, gauntlet3 = true, gauntlet4 = true, gauntlet5 = true,
    weevil2 = true,
    tulip2 = true, vigero2 = true, vigero3 = true,
    deity = true, jubilee = true, asterope2 = true,
}

if Config.ManualPriceOverrides then
    for model, price in pairs(Config.ManualPriceOverrides) do
        Config.PriceOverrides[model] = price
    end
end

--- Policijos salonas – tas pats NUI kaip Simion; mašinos įrašomos į `pd_*` garažą pagal stotį.
Config.PoliceDealership = {
    label = 'Policijos transporto skyrius',
    targetSize = vec3(1.4, 1.4, 2.0),
    targetDistance = 2.5,
    --- Kokį `garage` įrašyti į DB pagal mrp_ltpd stoties id
    garageByStation = {
        ls_main = 'pd_ls_main',
        davis = 'pd_davis',
        sandy = 'pd_sandy',
        paleto = 'pd_paleto',
    },
    --- Peržiūra / spawn po pirkimo pagal stotį (mrp_ltpd Config.Stations.id)
    stations = {
        ls_main = {
            spawn = vector4(452.3017, -1001.141, 25.6928, 0.0),
            preview = vector4(447.4821, -1001.14, 25.6882, 90.0),
            previewLateralM = 0.0,
            camera = vector4(450.0, -1005.0, 27.5, 90.0),
        },
        davis = {
            spawn = vector4(397.85, -1607.09, 29.29, 230.0),
            preview = vector4(392.4, -1609.85, 29.29, 50.0),
            previewLateralM = 0.0,
            camera = vector4(395.8, -1608.2, 30.85, 50.0),
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
        undercover = 'Undercover',
        anim = 'Animuotos šviesos',
    },
    vehicles = {
        -- Old style pack (mrp_pd_oldstyle)
        { model = 'gcpd1', name = 'PD patrulis 1', brand = 'PD', category = 'patrol', price = 18000 },
        { model = 'gcpd2', name = 'PD patrulis 2', brand = 'PD', category = 'patrol', price = 19000 },
        { model = 'gcpd3', name = 'PD patrulis 3', brand = 'PD', category = 'patrol', price = 20000 },
        { model = 'gcpd4', name = 'PD patrulis 4', brand = 'PD', category = 'patrol', price = 20000 },
        { model = 'gcpd5', name = 'PD patrulis 5', brand = 'PD', category = 'patrol', price = 21000 },
        { model = 'gcpd6', name = 'PD patrulis 6', brand = 'PD', category = 'patrol', price = 21000 },
        { model = 'gcpd10', name = 'PD patrulis 10', brand = 'PD', category = 'patrol', price = 22000 },
        -- Undercover pack (mrp_pd_undercover)
        { model = 'gcpd20', name = 'PD undercover 20', brand = 'PD', category = 'undercover', price = 24000 },
        { model = 'gcpd21', name = 'PD undercover 21', brand = 'PD', category = 'undercover', price = 25000 },
        { model = 'gcpd22', name = 'PD undercover 22', brand = 'PD', category = 'undercover', price = 26000 },
        { model = 'gcpd23', name = 'PD undercover 23', brand = 'PD', category = 'undercover', price = 27000 },
        -- Animated lights pack (mrp_pd_animuotu)
        { model = 'gcapd1', name = 'PD animuotas 1', brand = 'PD', category = 'anim', price = 26000 },
        { model = 'gcapd2', name = 'PD animuotas 2', brand = 'PD', category = 'anim', price = 27000 },
        { model = 'gcapd3', name = 'PD animuotas 3', brand = 'PD', category = 'anim', price = 28000 },
        { model = 'gcapd4', name = 'PD animuotas 4', brand = 'PD', category = 'anim', price = 28000 },
        { model = 'gcapd5', name = 'PD animuotas 5', brand = 'PD', category = 'anim', price = 29000 },
        { model = 'gcapd6', name = 'PD animuotas 6', brand = 'PD', category = 'anim', price = 30000 },
        { model = 'gcapd10', name = 'PD animuotas 10', brand = 'PD', category = 'anim', price = 31000 },
        { model = 'gcapd11', name = 'PD animuotas 11', brand = 'PD', category = 'anim', price = 32000 },
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
            spawn = vector4(125.9513, -3023.2095, 7.0409, 87.3217),
            preview = vector4(126.1551, -3047.4792, 7.0409, 87.9093),
            camera = vector4(118.5, -3035.5, 10.5, 265.0),
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
        ems_sandy = 'ems_sandy',
        ems_paleto = 'ems_paleto',
    },
    stations = {
        ems_ls = {
            spawn = vector4(331.58, -543.68, 28.74, 340.0),
            preview = vector4(334.5, -546.0, 28.74, 340.0),
            camera = vector4(338.0, -548.5, 30.4, 340.0),
        },
        ems_sandy = {
            spawn = vector4(1843.5, 3663.8, 33.85, 210.0),
            preview = vector4(1846.0, 3661.5, 33.85, 120.0),
            camera = vector4(1849.5, 3662.0, 35.4, 120.0),
        },
        ems_paleto = {
            spawn = vector4(-254.0, 6347.0, 32.50, 135.0),
            preview = vector4(-251.5, 6344.5, 32.50, 225.0),
            camera = vector4(-248.0, 6345.0, 34.1, 225.0),
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

Config.TaxiDealership = {
    label = 'Taksi transporto skyrius',
    garageByStation = {
        taxi_ls = 'taxi_ls',
    },
    stations = {
        taxi_ls = {
            spawn = vector4(908.42, -168.95, 74.12, 146.0),
            preview = vector4(905.55, -166.85, 74.12, 236.0),
            camera = vector4(901.95, -164.95, 75.55, 236.0),
        },
    },
    TaxiCategoryLabels = {
        taxi = 'Taksi parkas',
    },
    vehicles = {
        { model = 'taxi', name = 'Downtown Cab', brand = 'Vapid', category = 'taxi', price = 12000 },
        { model = 'cabby', name = 'Cabby', brand = 'Declasse', category = 'taxi', price = 14000 },
    },
}

Config.RangerDealership = {
    label = 'Gamtos apsaugos transportas',
    garageByStation = {
        ranger_main = 'ranger_main',
    },
    stations = {
        ranger_main = {
            spawn = vector4(371.33, 791.31, 187.47, 261.0),
            preview = vector4(368.5, 789.0, 187.47, 261.0),
            camera = vector4(375.5, 794.0, 189.2, 261.0),
        },
    },
    RangerCategoryLabels = {
        patrol = 'Patrulis',
        offroad = 'Visureigiai / specialūs',
    },
    vehicles = {
        { model = 'pranger', name = 'Park Ranger', brand = 'Declasse', category = 'patrol', price = 0 },
        { model = 'granger', name = 'Granger', brand = 'Declasse', category = 'patrol', price = 12000 },
        { model = 'blazer', name = 'Blazer', brand = 'Nagasaki', category = 'offroad', price = 8000 },
        { model = 'ripley', name = 'Ripley (technika)', brand = 'HVY', category = 'offroad', price = 15000 },
        { model = 'maverick', name = 'Maverick (sraigtasparnis)', brand = 'Buckingham', category = 'offroad', price = 45000 },
    },
}

--- Laivų salonas — Los Santos + Sandy Shores (tas pats NUI kaip Simion)
Config.BoatDealership = {
    label = 'Laivų salonas',
    targetSize = vec3(1.2, 1.2, 1.8),
    targetDistance = 2.2,
    garageByStation = {
        ls = 'ls_marina',
        sandy = 'sandy_marina',
    },
    CategoryLabels = {
        leisure = 'Valtys / pramoginiai',
        sport = 'Vandens motociklai',
        speed = 'Greitaeigiai kateriai',
        yacht = 'Jachtos ir kateriai',
    },
    vehicles = {
        -- Valtys
        { model = 'dinghy', name = 'Dinghy (2 vietos)', brand = 'Nagasaki', category = 'leisure', price = 95000 },
        { model = 'dinghy2', name = 'Dinghy (4 vietos)', brand = 'Nagasaki', category = 'leisure', price = 125000 },
        { model = 'dinghy4', name = 'Dinghy Yacht', brand = 'Nagasaki', category = 'leisure', price = 148000 },
        { model = 'suntrap', name = 'Suntrap', brand = 'Shitzu', category = 'leisure', price = 168000 },
        { model = 'tropic', name = 'Tropic', brand = 'Shitzu', category = 'leisure', price = 182000 },
        { model = 'tropic2', name = 'Tropic Yacht', brand = 'Shitzu', category = 'leisure', price = 215000 },
        -- Vandens motociklai
        { model = 'seashark', name = 'Seashark', brand = 'Speedophile', category = 'sport', price = 82000 },
        { model = 'seashark3', name = 'Seashark Yacht', brand = 'Speedophile', category = 'sport', price = 118000 },
        -- Greitaeigiai kateriai
        { model = 'squalo', name = 'Squalo', brand = 'Shitzu', category = 'speed', price = 198000 },
        { model = 'jetmax', name = 'Jetmax', brand = 'Shitzu', category = 'speed', price = 248000 },
        { model = 'speeder', name = 'Speeder', brand = 'Pegassi', category = 'speed', price = 288000 },
        { model = 'speeder2', name = 'Speeder Yacht', brand = 'Pegassi', category = 'speed', price = 338000 },
        { model = 'longfin', name = 'Longfin', brand = 'Shitzu', category = 'speed', price = 428000 },
        -- Jachtos / prabangūs kateriai
        { model = 'toro', name = 'Toro', brand = 'Lampadati', category = 'yacht', price = 525000 },
        { model = 'toro2', name = 'Toro Yacht', brand = 'Lampadati', category = 'yacht', price = 625000 },
        { model = 'marquis', name = 'Marquis', brand = 'Dinka', category = 'yacht', price = 780000 },
    },
    stations = {
        ls = {
            office = vector3(-802.92, -1352.35, 5.15),
            officeHeading = 110.0,
            preview = vector4(-797.5, -1368.0, 0.35, 110.0),
            camera = vector4(-788.0, -1360.0, 4.8, 120.0),
            spawn = vector4(-794.0, -1382.0, 0.12, 110.0),
            blip = { sprite = 410, color = 3, scale = 0.88, shortRange = true, label = 'Laivų salonas · Los Santos' },
        },
        sandy = {
            office = vector3(714.35, 4096.85, 30.73),
            officeHeading = 180.0,
            preview = vector4(712.0, 4110.0, 30.2, 180.0),
            camera = vector4(718.0, 4098.0, 33.5, 200.0),
            spawn = vector4(708.5, 4122.0, 29.8, 180.0),
            blip = { sprite = 410, color = 3, scale = 0.88, shortRange = true, label = 'Laivų salonas · Sandy Shores' },
        },
    },
}

--- Malūnsparnių salonas — Los Santos + Sandy Shores
Config.HeliDealership = {
    label = 'Malūnsparnių salonas',
    targetSize = vec3(1.2, 1.2, 1.8),
    targetDistance = 2.2,
    garageByStation = {
        ls = 'ls_heli',
        sandy = 'sandy_heli',
    },
    CategoryLabels = {
        civil = 'Civiliniai',
    },
    vehicles = {
        { model = 'maverick', name = 'Maverick', brand = 'Buckingham', category = 'civil', price = 425000 },
        { model = 'frogger', name = 'Frogger', brand = 'Maibatsu', category = 'civil', price = 535000 },
    },
    stations = {
        ls = {
            office = vector3(-1142.5, -2864.8, 13.95),
            officeHeading = 330.0,
            preview = vector4(-1145.2, -2865.5, 13.95, 330.0),
            camera = vector4(-1135.0, -2858.0, 16.5, 150.0),
            spawn = vector4(-1145.2, -2865.5, 13.95, 330.0),
            blip = { sprite = 43, color = 3, scale = 0.88, shortRange = true, label = 'Malūnsparnių salonas · Los Santos' },
        },
        sandy = {
            office = vector3(1770.15, 3239.85, 42.13),
            officeHeading = 15.0,
            preview = vector4(1772.0, 3246.0, 42.13, 15.0),
            camera = vector4(1765.0, 3238.0, 45.0, 200.0),
            spawn = vector4(1772.0, 3246.0, 42.13, 15.0),
            blip = { sprite = 43, color = 3, scale = 0.88, shortRange = true, label = 'Malūnsparnių salonas · Sandy Shores' },
        },
    },
}

