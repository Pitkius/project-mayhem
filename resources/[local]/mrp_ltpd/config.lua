Config = {}

--- Darbo pavadinimas turi sutapti su `qb-core/shared/jobs.lua` įrašu `police`.
Config.JobName = 'police'

--[[
  Padaliniai – saugoma DB `ltpd_profiles.division` (tik police job).
  Rangai 0–3: automatiškai LPM. Nuo 4 rango – žaidėjas renkasi padalinį (/pddept arba rūbinėje).
]]
Config.DivisionRules = {
    lpmMaxGrade = 3,      -- įskaitant 3 – vis dar LPM
    chooseMinGrade = 4,   -- nuo šio rango galima keisti padalinį
}

Config.Divisions = {
    lpm = { label = 'LPM (mokymo padalinys)', abbr = 'LPM', minGrade = 0, choosable = false, autoOnly = true },
    mp = { label = 'Miesto patrulių divizija', abbr = 'MP', minGrade = 4, choosable = true },
    kpd = { label = 'Kelių policijos divizija', abbr = 'KPD', minGrade = 4, choosable = true },
    ktd = { label = 'Kriminalinių tyrimų divizija', abbr = 'KTD', minGrade = 4, choosable = true },
    sor = { label = 'Specialiųjų operacijų rinktinė', abbr = 'SOR', minGrade = 4, choosable = true },
    opd = { label = 'Oro paramos divizija', abbr = 'OPD', minGrade = 4, choosable = true },
    kd = { label = 'Kinologų divizija', abbr = 'KD', minGrade = 4, choosable = true },
    vtd = { label = 'Vidaus tyrimų divizija', abbr = 'VTD', minGrade = 4, choosable = true },
    admin = { label = 'Administracija', abbr = 'ADM', minGrade = 7, choosable = false },
}

--- Kol nėra atskirų ARO aprangų įrašų su `divisions = {'aro'}`, ARO rūbinė rodo tas pačias uniformas
Config.AroLockerShowsAllUniforms = true

--- Minimalus grade (0 = Kursantas) veiksmui
--- F7 – surinktų pirštų atspaudų žurnalas (tarnybos metu)
Config.FingerprintJournalKey = 'F7'

Config.Permissions = {
    mdt_open = 0,
    mdt_search_basic = 0,
    mdt_search_full = 3, -- pinigai, transportas, išsamiau
    mdt_fine = 1,
    mdt_wanted = 2,
    mdt_fingerprint = 1,
    mdt_arrest_record = 2,
    mdt_interrogation = 2,
    cuff = 1,
    search_inventory = 1,
    traffic_radar = 1, -- rezervas / ateities integracija
    division_admin = 8,
    armory = 0, -- bendra policijos ginklinė (stash)
    garage = 0, -- PD tarnybinio transporto išėmimas
    boss_menu = 7, -- Įdarb./atleisti/rangas (isboss arba ≥ šis grade – qb-core rangų sutapimas)
    --- PD sirenos / laikina įranga ant civilinės mašinos
    pd_siren_controller = 0,
    pd_emergency_kit = 0,
    --- PD išorinių / vidinių durų ir vartų užraktas (E) – tik tarnyboje
    pd_doors = 0,
    pd_craft = 0,
    mdt_cctv = 0,
    mdt_bodycam = 0,
    mdt_weapon_license = 3,
    bodycam_wear = 0,
}

--- Šviesų ir sirenos valdymas (masinoje): režimas per entity statebag (sinchr. visiems žaidėjams)
Config.EmergencyVehicle = {
    --- qb-menu komandos (tik adminams – žaidėjai naudoja itemą)
    sirenMenuCommand = 'pdsirenai',
    kitMenuCommand = 'pdiranga',
    commandsAdminOnly = true,
    kitItem = 'pd_emergency_kit',
    returnKitItemOnRemove = true,
    --- kai išlipi iš vairuotojo vietos – išjungti sirenos režimą ir garsą
    resetModeWhenLeaveDriverSeat = true,
    --- nuo transporto centro atstumas (m), kuriuo serveris priima veiksmus
    validateDistance = 28.0,
    --- Laikina švyturėlių juosta civilinei TP (prop ant stogo)
    lightbarModel = 'prop_lightbar_01',
    lightbarYOffset = -0.10,
    lightbarZOffset = 0.06,
    --- Mažos matomos lempos ant švyturėlio (šviesa papildomai piešiama scriptu)
    lensModel = 'prop_warninglight_01',
    lensHideProp = false,
    lensLeftOffset = { x = -0.26, y = 0.0, z = 0.08 },
    lensRightOffset = { x = 0.26, y = 0.0, z = 0.08 },
    --- Vizualas: standard | enhanced (dvigubas halo + bar pulse)
    flashVisualPreset = 'enhanced',
    flashColors = {
        red = { r = 255, g = 48, b = 52 },
        blue = { r = 58, g = 128, b = 255 },
        white = { r = 248, g = 252, b = 255 },
    },
    --- Mirksėjimo intervalas (ms)
    flashIntervalMs = 420,
    flashTickMs = 65,
    --- Šviesos prie lempų – ryškesnės, panašiau į tikrą policijos signalą
    flashLightRange = 13.5,
    flashLightIntensity = 5.2,
    flashUseLensGlow = true,
    flashUseBarGlow = true,
    flashMarkerScale = 0.058,
    flashMarkerGlowScale = 0.145,
    --- Kryptiniai spinduliai (matomi ir toliau)
    flashUseSpotBeams = true,
    flashUseNearSpotBeams = true,
    flashNearSpotDistance = 48.0,
    flashSpotRange = 24.0,
    flashSpotIntensity = 9.5,
    flashUseAmbientGlow = true,
    flashDrawDistance = 80.0,
    --- Tik Config.FleetVehicles + native emergency — ne visi GetVehicleClass 18 (addon klaidos)
    trustVehicleClassEmergency = false,
    --- Lengvas „tuning“ civilinei TP su įranga (sirenos + švyturėliai)
    allowPassengerControl = true,
    performanceTune = {
        enabled = true,
        acceleration = 1.045,
        topSpeed = 1.028,
        extraMaxKmh = 6,
        braking = 1.06,
        steering = 1.025,
        traction = 1.03,
        driveInertia = 0.97,
    },
}

--- Baudų šablonai (kodas rodomas MDT)
Config.FinePresets = {
    { code = 'SPEED', label = 'Greičio viršijimas', defaultAmount = 150 },
    { code = 'RED', label = 'Raudono šviesoforo pažeidimas', defaultAmount = 200 },
    { code = 'PARK', label = 'Netinkamas parkavimas', defaultAmount = 80 },
    { code = 'DOC', label = 'Dokumentų neturėjimas', defaultAmount = 120 },
    { code = 'NOISE', label = 'Triukšmo pažeidimas', defaultAmount = 100 },
}

--- MDT žemėlapis — Leaflet CRS.Simple + satelitinį PNG.
--- projection = homography: projekcinė transformacija (stabiliausia su 20+ taškų).
--- coordSpace = pixel: žymekliai tiesiai ant PNG pikselių (ne per ištemptą game bbox).
--- Paleisti: node tools/mdt_map_fit.mjs
Config.MdtMap = {
    projection = 'homography',
    coordSpace = 'pixel',
    gameMin = { x = -4000.0, y = -4000.0 },
    gameMax = { x = 4500.0, y = 6625.0 },
    coordMin = { x = -4000.0, y = -4000.0 },
    coordMax = { x = 4500.0, y = 6625.0 },
    viewMin = { x = -4000.0, y = -4000.0 },
    viewMax = { x = 4500.0, y = 6625.0 },
    offsetX = 0.0,
    offsetY = 0.0,
    scaleX = 1.0,
    scaleY = 1.0,
    flipY = false,
    imageFile = 'mdt/asset/gtav_satellite_2048.png',
    imageWidth = 2048,
    imageHeight = 2048,
    calibration = {
        { gx = -448.15,  gy = 6012.0,   u = 0.4585, v = 0.1099 },
        { gx = 450.77,   gy = 5566.86,  u = 0.5352, v = 0.1426 },
        { gx = 1853.2,   gy = 3686.5,   u = 0.6460, v = 0.2881 },
        { gx = 1695.0,   gy = 4785.0,   u = 0.6616, v = 0.1904 },
        { gx = 611.0,    gy = 2745.0,   u = 0.5156, v = 0.3901 },
        { gx = -2360.0,  gy = 3249.0,   u = 0.2261, v = 0.3896 },
        { gx = -3192.0,  gy = 1100.0,   u = 0.1025, v = 0.5894 },
        { gx = -1520.0,  gy = -440.0,   u = 0.2593, v = 0.6978 },
        { gx = -1098.0,  gy = -808.0,   u = 0.3022, v = 0.7280 },
        { gx = 441.84,   gy = -982.05,  u = 0.4487, v = 0.7383 },
        { gx = 195.0,    gy = -933.0,   u = 0.4092, v = 0.7446 },
        { gx = 311.0,    gy = -590.0,   u = 0.4136, v = 0.6953 },
        { gx = 379.39,   gy = -1591.37, u = 0.4390, v = 0.8008 },
        { gx = 85.0,     gy = -1958.0,  u = 0.3989, v = 0.8276 },
        { gx = -1037.0,  gy = -2737.0,  u = 0.2827, v = 0.9175 },
        { gx = 1206.24,  gy = -3157.06, u = 0.4688, v = 0.9116 },
        { gx = 293.0,    gy = 180.0,    u = 0.4395, v = 0.6274 },
        { gx = -800.0,   gy = 180.0,    u = 0.3472, v = 0.6489 },
        { gx = 981.69,   gy = -102.8,   u = 0.5078, v = 0.6528 },
        { gx = 2452.28,  gy = 4969.7,   u = 0.7065, v = 0.1758 },
        { gx = 826.0,    gy = -1290.0,  u = 0.4727, v = 0.7417 },
        { gx = -75.0,    gy = -818.0,   u = 0.4009, v = 0.7231 },
    },
}

--- MDT GPS žemėlapis — laikinas išjungimas (skirta nuo CCTV/bodycam).
--- Neįtakoja: PANIC mygtuko, dispatch blipų įprastame žemėlapyje, iškvietimų sąrašo.
Config.MdtMapMaintenance = {
    enabled = true,
    message = 'GPS žemėlapio sistema laikinai neveikia. Dėl finansavimo skyrimo ir įrengimo kreipkitės į miesto merą.',
}

--- Maks. atstumas iki ginklinės / sandėlių / PD garažo (patikra serveryje)
Config.ArmoryGarageDistance = 38.0
--- (Rezervas) vadovybės veiksmų atstumo patikra serveryje
Config.ManagementRadius = 18.0

--- Blipai žemėlapyje (komisariatai)
Config.ShowStationBlips = true
Config.BlipSprite = 60
Config.BlipColour = 38
Config.BlipScale = 0.85
--- Stogo helipado blipas (PD sraigtasparnis)
Config.ShowHelipadBlip = false
Config.HelipadBlipSprite = 43
Config.HelipadBlipScale = 0.9

--- 3D markeriai ant žemės MRPD / Sandy Shores PD (ne žemėlapio blipai)
Config.ShowPd3DMarkers = true
Config.PdMarkerDrawDistance = 32.0
Config.PdMarkerNearTickMs = 50
Config.PdMarkerZOffset = 0.02
--- Sandėliai: mažas trikampis (DrawMarker tipas 2)
Config.PdStashMarkerType = 2
Config.PdStashMarkerScale = { x = 0.34, y = 0.34, z = 0.34 }
Config.PdStashMarkerDrawDistance = 32.0
Config.PdMarkerTextDistance = 2.2

--- Tarnybinis transportas (MRPD pack — žr. server spawnFleet)
Config.FleetVehicles = {
  { model = 'mrpd1', label = 'MRPD 1 (undercover)' },
  { model = 'mrpd2', label = 'MRPD 2 (undercover)' },
  { model = 'mrpd3', label = 'MRPD 3 (undercover)' },
  { model = 'mrpd4', label = 'MRPD 4 (undercover)' },
  { model = 'mrpd5', label = 'MRPD 5 (animuotas)' },
  { model = 'mrpd6', label = 'MRPD 6 (animuotas)' },
  { model = 'mrpd7', label = 'MRPD 7 (animuotas)' },
  { model = 'mrpd8', label = 'MRPD 8 (animuotas)' },
  { model = 'mrpd9', label = 'MRPD 9 (animuotas)' },
  { model = 'mrpd10', label = 'MRPD 10 (animuotas)' },
  { model = 'mrpd11', label = 'MRPD 11 (animuotas)' },
  { model = 'mrpd12', label = 'MRPD 12 (animuotas)' },
  { model = 'mrpd13', label = 'MRPD 13 — Audi RS6 Avant' },
  { model = 'mrpd14', label = 'MRPD 14 — Kia Stinger' },
  { model = 'mrpd15', label = 'MRPD 15 — Hyundai' },
  { model = 'mrpd16', label = 'MRPD 16 — Alfa Romeo' },
}

--- Sraigtasparniai (stogas / helipadas) – spawn ant `heliGarage.spawn`
Config.FleetHelicopters = {
    { model = 'polmav', label = 'Policijos Maverick' },
    { model = 'buzzard2', label = 'Buzzard (tarnybinis)' },
}

--- PD registratūra (civiliai) ir priėmimo anketos
Config.Reception = {
    statementMinLen = 15,
    applicationMinMotivation = 20,
    applicationCooldownHours = 48,
    statementCooldownMinutes = 10,
}

--[[
  Postai: MDT + ginklinė + PD garažas.
  ls_main – cfx-nteam-mrpd (NTeam Mission Row). Koordinates reikia tikslinti žaidime.
  sandy – cfx-gabz-sandypd.
]]
Config.Stations = {
    {
        id = 'ls_main',
        label = 'Los Santos – pagrindinė komisariatas',
        coords = vector3(441.84, -982.05, 30.69),
        blipCoords = vector3(427.120, -979.559, 30.716),
        heading = 90.0,
        duty = {
            coords = vector3(440.085, -974.924, 30.689),
        },
        reception = {
            coords = vector3(431.06, -988.37, 31.39),
            heading = 180.0,
            length = 1.65,
            width = 1.45,
            label = 'PD registratūra',
            blip = { sprite = 280, color = 3, scale = 0.72, label = 'PD registratūra' },
        },
        supply = {
            coords = vector3(462.23, -981.12, 30.68),
            label = 'PD ginklinė / inventorius',
        },
        armory = {
            coords = vector3(480.32, -996.67, 30.6896),
            stashId = 'ltpd_armory_ls',
            label = 'ARO sandėlis (ginklinė)',
            minGrade = 2,
            divisions = { 'sor' },
            maxweight = 5000000,
            slots = 90,
        },
        pdGarageId = 'pd_ls_main',
        policeDealership = {
            coords = vector3(460.57, -1006.34, 21.34),
            heading = 90.0,
        },
        garage = {
            coords = vector3(460.57, -1006.34, 21.34),
            spawn = vector4(460.57, -1006.34, 21.34, 90.0),
        },
        boss = {
            coords = vector4(461.03, -985.58, 34.3725, 180.0),
            label = 'LTPD vadovybė',
            prop = 'prop_laptop_01a',
            spawnProp = true,
        },
        locker = {
            coords = vector3(453.075, -980.124, 30.889),
            heading = 90.0,
        },
        locker2 = {
            coords = vector3(455.65, -997.62, 30.6896),
            heading = 90.0,
            label = 'ARO rūbinė',
            lockerMode = 'aro',
            divisions = { 'sor' },
        },
        stashes = {
            {
                coords = vector3(453.075, -980.124, 30.889),
                stashId = 'ltpd_stash_public_ls',
                label = 'PD sandėlis (bendras)',
                minGrade = 0,
                divisions = { 'lpm', 'mp', 'kpd', 'ktd', 'sor', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 2000000,
                slots = 60,
            },
            {
                coords = vector3(451.7031, -973.232, 30.689),
                stashId = 'ltpd_stash_grade3_ls',
                label = 'PD sandėlis (≥3 rango)',
                minGrade = 3,
                divisions = { 'lpm', 'mp', 'kpd', 'ktd', 'sor', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 2500000,
                slots = 70,
            },
            {
                coords = vector3(455.1456, -985.462, 30.689),
                stashId = 'ltpd_stash_grade8_ls',
                label = 'PD sandėlis (vadovų)',
                minGrade = 8,
                divisions = { 'mp', 'kpd', 'ktd', 'sor', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 3000000,
                slots = 80,
            },
            {
                coords = vector3(459.85, -986.20, 34.3725),
                stashId = 'ltpd_stash_boss_ls',
                label = 'PD sandėlis (bosas / pavaduotojas)',
                minGrade = 7,
                divisions = { 'mp', 'kpd', 'ktd', 'sor', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 3500000,
                slots = 90,
            },
        },
        heliGarage = {
            coords = vector3(449.168, -981.325, 43.691),
            spawn = vector4(449.168, -981.325, 43.691, 87.234),
        },
    },
    {
        id = 'sandy',
        label = 'Sandy Shores PD',
        coords = vector3(1853.2, 3686.5, 34.27),
        blipCoords = vector3(1871.453, 3664.964, 33.687),
        heading = 210.0,
        duty = true,
        reception = {
            coords = vector3(1859.75, 3689.12, 33.99),
            heading = 210.0,
            length = 1.65,
            width = 1.45,
            label = 'PD registratūra',
            blip = { sprite = 280, color = 3, scale = 0.72, label = 'PD registratūra' },
        },
        supply = {
            coords = vector3(1849.12, 3690.04, 34.27),
            label = 'PD inventorius',
        },
        armory = {
            coords = vector3(1849.12, 3690.04, 34.27),
            stashId = 'ltpd_armory_sandy',
            label = 'Policijos ginklinė (Sandy)',
            maxweight = 4000000,
            slots = 70,
        },
        pdGarageId = 'pd_sandy',
        policeDealership = {
            coords = vector3(1869.5, 3695.2, 33.53),
            heading = 210.0,
        },
        garage = {
            coords = vector3(1869.5, 3695.2, 33.53),
            spawn = vector4(1869.5, 3695.2, 33.53, 210.0),
        },
        boss = {
            coords = vector4(1852.0, 3688.5, 34.27, 210.0),
            label = 'LTPD vadovybė',
            prop = 'prop_laptop_01a',
            spawnProp = true,
        },
        locker = {
            coords = vector3(1851.2, 3689.1, 34.27),
            heading = 210.0,
        },
        stashes = {
            { coords = vector3(1850.5, 3691.5, 34.27), stashId = 'ltpd_stash_public_sandy', label = 'PD sandėlis (bendras)', minGrade = 0, maxweight = 2000000, slots = 60 },
            { coords = vector3(1851.5, 3691.5, 34.27), stashId = 'ltpd_stash_grade3_sandy', label = 'PD sandėlis (nuo 3 rango)', minGrade = 3, maxweight = 2500000, slots = 70 },
            { coords = vector3(1852.5, 3691.5, 34.27), stashId = 'ltpd_stash_grade8_sandy', label = 'PD sandėlis (nuo 8 rango)', minGrade = 8, maxweight = 3000000, slots = 80 },
        },
    },
}

--- Tarnybinė PD apranga – žr. config_duty_outfits.lua (addon kolekcijos mrp_pd_uniforms)

Config.TargetDistance = 2.5
Config.MaxFineAmount = 50000

--- PD durys / vartai — NTeam MRPD (LS) + Sandy Shores MLO
Config.PdDoorToggleReach = 6.0
--- Spynos ikonos Z poslinkis nuo durų slab koord. (standartinės durys)
Config.PdDoorLockIconZOffset = 0.38
--- Spynos ikona: tik arti durų · ms tarp piešimų (≥50)
Config.PdDoorLockIconDrawDistance = 10.0
Config.PdDoorLockIconTickMs = 50
--- false = tik E mygtukas; true = papildomai qb-target (numatyta: tik E)
Config.PdDoorUseQbTarget = false
Config.PdDoorGroups = {
    {
        id = 'ls_mrpd_garage_roll',
        label = 'Garažo vartai (MRPD)',
        doorType = 'garage_roll',
        interact = vector3(460.57, -1006.34, 21.34),
        interactDist = 5.0,
        defaultLocked = true,
        doors = {},
        entityScan = {
            center = vector3(452.0, -1001.0, 24.0),
            radius = 18.0,
            models = { 'nteam_mrpd_garagedoors', 'nteam_mrpd_shut' },
        },
    },
    {
        id = 'ls_mrpd_front_entry',
        label = 'Priekinis kiemas (vartai)',
        doorType = 'barrier',
        interact = vector3(410.223, -1021.4033, 29.2392),
        interactDist = 5.5,
        defaultLocked = true,
        doors = {
            { model = 'prop_facgate_07b', coords = vector3(411.0243, -1025.059, 28.335), heading = 270.0 },
        },
        entityScan = {
            center = vector3(411.0243, -1025.059, 28.335),
            radius = 12.0,
            models = { 'prop_facgate_07b' },
        },
    },
    {
        id = 'ls_mrpd_back_gate',
        label = 'Kiemo vartai',
        doorType = 'barrier',
        interact = vector3(488.8, -1020.2, 29.0),
        interactDist = 12.0,
        defaultLocked = true,
        doors = {
            { model = 'hei_prop_station_gate', coords = vector3(488.8, -1017.2, 27.1) },
        },
        entityScan = {
            center = vector3(488.8, -1017.2, 27.1),
            radius = 14.0,
            models = { 'hei_prop_station_gate' },
        },
    },
    {
        id = 'ss_pd_front_manual',
        label = 'Sandy PD main doors',
        interact = vector3(1859.75, 3689.12, 33.99),
        interactDist = 2.9,
        defaultLocked = true,
        doors = {
            { model = 'hedwig_sheriff_door01', coords = vector3(1860.32, 3689.71, 33.986) },
            { model = 'hedwig_sheriff_door01', coords = vector3(1859.18, 3688.52, 33.986) },
        },
    },
    {
        id = 'ss_pd_garage_manual',
        label = 'Sandy PD garage door',
        doorType = 'garage_roll',
        interact = vector3(1854.92, 3701.15, 33.73),
        interactDist = 3.8,
        defaultLocked = true,
        doors = {
            { model = 'hedwig_sheriff_garage_gardoor', coords = vector3(1854.92, 3701.15, 33.73), heading = 0.0 },
        },
        entityScan = {
            center = vector3(1854.92, 3701.15, 33.73),
            radius = 12.0,
            models = { 'hedwig_sheriff_garage_gardoor', 'hedwig_sheriff_garage_door', 'hedwig_sheriif_garage_door' },
        },
    },
}

Config.PdDoorInteractExtras = {
    { groupId = 'ls_mrpd_garage_roll', interact = vector3(455.0, -1001.0, 22.0), interactDist = 5.0 },
    { groupId = 'ls_mrpd_front_entry', interact = vector3(410.1, -1024.3, 29.75), interactDist = 5.0 },
    { groupId = 'ls_mrpd_back_gate', interact = vector3(488.8, -1017.2, 27.1), interactDist = 6.0 },
}

--- Automatinis durų radimas (objektai žemėlapyje pagal modelį ir dėžę)
Config.PdDoorDynamics = {
    {
        stationId = 'ls_main',
        label = 'PD durys (NTeam MRPD – auto)',
        bounds = {
            min = vector3(400.0, -1060.0, 18.0),
            max = vector3(505.0, -910.0, 58.0),
        },
        models = {
            'nteam_mrpd_metaldoor',
            'nteam_mrpd_garagedoors',
            'nteam_mrpd_bathroomdoor',
            'nteam_mrpd_tamdoor',
            'nteam_mrpd_shut',
            'xm3_prop_xm3_glass_door_02a',
            'v_ilev_ph_gendoor',
            'v_ilev_fib_doore_l',
            'v_ilev_fib_doore_r',
        },
        pairDist = 4.35,
        interactDist = 2.85,
    },
    {
        stationId = 'sandy',
        label = 'PD durys (Sandy)',
        bounds = { min = vector3(1775.0, 3585.0, 18.0), max = vector3(1935.0, 3785.0, 75.0) },
        models = {
            'hedwig_sheriff_door01',
            'hedwig_sheriff_door02',
            'hedwig_sheriff_door03',
            'hedwig_sheriff_door04',
            'hedwig_sheriff_door05',
            'hedwig_sheriff_door06',
            'hedwig_sheriff_garage_gardoor',
            'hedwig_sheriif_garage_door',
            'hedwig_sheriff_garage_door',
        },
        pairDist = 4.35,
        interactDist = 2.85,
    },
}

--- MDT asmens paieška — licencijų rodymas (sutampa su mrp_licenses / drivingschool)
Config.MdtLicenses = {
    DrivingCategories = {
        { key = 'driver_a', letter = 'A', label = 'Motociklai' },
        { key = 'driver_b', letter = 'B', label = 'Lengvieji automobiliai', altKeys = { 'driver' } },
        { key = 'driver_c', letter = 'C', label = 'Sunkvežimiai' },
    },
    DrivingItems = { 'driving_license', 'driver_license' },
    IdItem = 'id_card',
    FishingItem = 'fishing_license',
    HuntingItem = 'hunting_license',
    WeaponItem = 'weaponlicense',
}
