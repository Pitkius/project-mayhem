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
    lightbarYOffset = 0.12,
    lightbarZOffset = 0.04,
    --- Mirksėjimo intervalas (ms) — lėtesnis = saugesnis regėjimui
    flashIntervalMs = 720,
    --- Aplinkos šviesa ant prop (0 = tik maži žibintai ant juostos, be blizgesio)
    flashLightRange = 0.0,
    flashLightIntensity = 1.2,
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

--- 3D markeriai ant žemės MRPD / kituose postuose (ne žemėlapio blipai)
Config.ShowPd3DMarkers = true
Config.PdMarkerDrawDistance = 40.0
Config.PdMarkerZOffset = 0.02
--- Sandėliai: mažas trikampis (DrawMarker tipas 2)
Config.PdStashMarkerType = 2
Config.PdStashMarkerScale = { x = 0.34, y = 0.34, z = 0.34 }
Config.PdStashMarkerDrawDistance = 32.0
Config.PdMarkerTextDistance = 2.2

--- Tarnybinis transportas (modeliai turi būti whitelist – žr. server spawnFleet)
Config.FleetVehicles = {
    { model = 'police', label = 'Patrulinis' },
    { model = 'police2', label = 'Buffalo patrulinis' },
    { model = 'police3', label = 'Interceptoria' },
    { model = 'policeb', label = 'Motociklas' },
    { model = 'sheriff', label = 'Šerifų patrulinis' },
    { model = 'sheriff2', label = 'Šerifų visureigis' },
    { model = 'riot', label = 'Antiriot' },
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
  Postai: MDT + (pasirinktinai) ginklinė ir PD garažas.
  Koordinates patikrink su savo MLO – ypač armory.coords ir garage.spawn.
]]
Config.Stations = {
    {
        id = 'ls_main',
        label = 'Los Santos – pagrindinė komisariatas',
        coords = vector3(441.84, -982.05, 30.69),
        blipCoords = vector3(427.120, -979.559, 30.716),
        heading = 90.0,
        --- Civilinė registratūra — qb-target (be NPC)
        reception = {
            coords = vector3(441.2229, -982.0843, 30.6895),
            heading = 275.0,
            length = 1.65,
            width = 1.45,
            label = 'PD registratūra',
            blip = { sprite = 280, color = 3, scale = 0.72, label = 'PD registratūra' },
        },
        supply = {
            coords = vector3(489.05, -997.1946, 30.6896),
            label = 'PD inventorius (žaliavos)',
        },
        armory = {
            coords = vector3(486.5664, -995.1992, 30.6791),
            stashId = 'ltpd_armory_ls',
            label = 'ARO sandėlis (ginklinė)',
            minGrade = 2,
            divisions = { 'sor' },
            maxweight = 5000000,
            slots = 90,
        },
        --- PD asmeninis garažas (mrp_garages id – mašinos perkamos salone)
        pdGarageId = 'pd_ls_main',
        --- Policijos salonas (mrp_dealership) – sujungta su garažu
        policeDealership = {
            coords = vector3(460.1003, -986.7195, 25.6998),
            heading = 269.0115,
        },
        garage = {
            coords = vector3(460.1003, -986.7195, 25.6998),
            spawn = vector4(460.1003, -986.7195, 25.6998, 269.0115),
        },
        --- Vadovybės meniu (qb-target ant laptop propo)
        boss = {
            coords = vector4(462.1010, -985.5582, 30.7281, 169.0399),
            label = 'LTPD vadovybė',
            prop = 'prop_laptop_01a',
            spawnProp = true,
        },
        --- Rūbinė 1 (palikta)
        locker = {
            coords = vector3(461.85, -998.35, 30.69),
            heading = 90.0,
        },
        --- Rūbinė 2 – ARO uniforma
        locker2 = {
            coords = vector3(460.1924, -998.6480, 30.6849),
            heading = 0.3915,
            label = 'ARO rūbinė',
            lockerMode = 'aro',
            divisions = { 'sor' },
        },
        stashes = {
            {
                coords = vector3(480.5729, -995.2401, 30.6896),
                stashId = 'ltpd_stash_public_ls',
                label = 'PD sandėlis (bendras)',
                minGrade = 0,
                divisions = { 'lpm', 'mp', 'kpd', 'ktd', 'sor', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 2000000,
                slots = 60,
            },
            {
                coords = vector3(482.4943, -995.2571, 30.6896),
                stashId = 'ltpd_stash_grade3_ls',
                label = 'PD sandėlis (≥3 rango)',
                minGrade = 3,
                divisions = { 'lpm', 'mp', 'kpd', 'ktd', 'sor', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 2500000,
                slots = 70,
            },
            {
                coords = vector3(484.20, -995.27, 30.6896),
                stashId = 'ltpd_stash_criminal_ls',
                label = 'Kriminalistų sandėlis',
                minGrade = 4,
                divisions = { 'ktd', 'admin' },
                maxweight = 2500000,
                slots = 70,
            },
            {
                coords = vector3(485.3315, -995.2804, 30.6896),
                stashId = 'ltpd_stash_grade8_ls',
                label = 'PD sandėlis (vadovų)',
                minGrade = 8,
                divisions = { 'mp', 'kpd', 'ktd', 'sor', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 3000000,
                slots = 80,
            },
            {
                coords = vector3(463.1892, -988.8655, 30.6897),
                stashId = 'ltpd_stash_boss_ls',
                label = 'PD sandėlis (bosas / pavaduotojas)',
                minGrade = 7,
                divisions = { 'mp', 'kpd', 'ktd', 'sor', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 3500000,
                slots = 90,
            },
        },
        --- Stogas: helipadas + sraigtasparnio „garažas“ (keisk Z pagal MLO)
        heliGarage = {
            coords = vector3(449.32, -981.38, 43.69),
            spawn = vector4(449.32, -981.38, 44.05, 90.0),
        },
    },
    {
        id = 'davis',
        label = 'Davis PD (Gabz)',
        coords = vector3(379.39, -1591.37, 29.76),
        blipCoords = vector3(383.423, -1590.407, 29.276),
        heading = 320.0,
        duty = true,
        supply = {
            coords = vector3(374.04, -1608.08, 29.29),
            label = 'PD inventorius',
        },
        armory = {
            coords = vector3(374.04, -1608.08, 29.29),
            stashId = 'ltpd_armory_davis',
            label = 'Policijos ginklinė (Davis)',
            maxweight = 5000000,
            slots = 90,
        },
        pdGarageId = 'pd_davis',
        policeDealership = {
            coords = vector3(383.0487, -1616.0627, 29.2921),
            heading = 52.1940,
        },
        garage = {
            coords = vector3(383.0487, -1616.0627, 29.2921),
            spawn = vector4(383.0487, -1616.0627, 29.2921, 52.1940),
        },
        locker = {
            coords = vector3(365.13, -1598.32, 25.45),
            heading = 320.0,
        },
        stashes = {
            { coords = vector3(373.2, -1606.5, 29.29), stashId = 'ltpd_stash_public_davis', label = 'PD sandėlis (bendras)', minGrade = 0, maxweight = 2000000, slots = 60 },
            { coords = vector3(373.2, -1605.4, 29.29), stashId = 'ltpd_stash_grade3_davis', label = 'PD sandėlis (nuo 3 rango)', minGrade = 3, maxweight = 2500000, slots = 70 },
            { coords = vector3(373.2, -1604.3, 29.29), stashId = 'ltpd_stash_grade8_davis', label = 'PD sandėlis (nuo 8 rango)', minGrade = 8, maxweight = 3000000, slots = 80 },
        },
    },
    {
        id = 'sandy',
        label = 'Sandy Shores',
        coords = vector3(1853.2, 3686.5, 34.27),
        blipCoords = vector3(1871.453, 3664.964, 33.687),
        heading = 210.0,
        duty = true,
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
    {
        id = 'paleto',
        label = 'Paleto Bay',
        coords = vector3(-448.15, 6012.0, 31.72),
        blipCoords = vector3(-432.177, 6019.605, 31.490),
        heading = 45.0,
        duty = true,
        supply = {
            coords = vector3(-449.38, 6014.12, 31.72),
            label = 'PD inventorius',
        },
        armory = {
            coords = vector3(-449.38, 6014.12, 31.72),
            stashId = 'ltpd_armory_paleto',
            label = 'Policijos ginklinė (Paleto)',
            maxweight = 4000000,
            slots = 70,
        },
        pdGarageId = 'pd_paleto',
        policeDealership = {
            coords = vector3(-459.2, 6016.3, 31.49),
            heading = 45.0,
        },
        garage = {
            coords = vector3(-459.2, 6016.3, 31.49),
            spawn = vector4(-459.2, 6016.3, 31.49, 45.0),
        },
        locker = {
            coords = vector3(-448.9, 6013.2, 31.72),
            heading = 45.0,
        },
        stashes = {
            { coords = vector3(-450.5, 6015.2, 31.72), stashId = 'ltpd_stash_public_paleto', label = 'PD sandėlis (bendras)', minGrade = 0, maxweight = 2000000, slots = 60 },
            { coords = vector3(-451.5, 6015.2, 31.72), stashId = 'ltpd_stash_grade3_paleto', label = 'PD sandėlis (nuo 3 rango)', minGrade = 3, maxweight = 2500000, slots = 70 },
            { coords = vector3(-452.5, 6015.2, 31.72), stashId = 'ltpd_stash_grade8_paleto', label = 'PD sandėlis (nuo 8 rango)', minGrade = 8, maxweight = 3000000, slots = 80 },
        },
    },
}

--- Tarnybinė PD apranga – žr. config_duty_outfits.lua (addon kolekcijos mrp_pd_uniforms)

Config.TargetDistance = 2.5
Config.MaxFineAmount = 50000

--- PD durys / vartai (Gabz MRPD LS + automatinis Sandy / Paleto MLO skenavimas)
Config.PdDoorToggleReach = 6.0
Config.PdDoorGroups = {
    {
        id = 'ls_mrpd_reception',
        label = 'Registratūros įėjimas',
        interact = vector3(434.81, -981.93, 30.89),
        interactDist = 2.5,
        defaultLocked = true,
        doors = {
            { model = 'gabz_mrpd_reception_entrancedoor', coords = vector3(434.7, -983.0, 30.8) },
            { model = 'gabz_mrpd_reception_entrancedoor', coords = vector3(434.7, -980.7, 30.8) },
        },
    },
    {
        id = 'ls_mrpd_side',
        label = 'Šoninis įėjimas',
        interact = vector3(441.9, -998.7, 30.8),
        interactDist = 2.5,
        defaultLocked = true,
        doors = {
            { model = 'gabz_mrpd_reception_entrancedoor', coords = vector3(440.7, -998.7, 30.8) },
            { model = 'gabz_mrpd_reception_entrancedoor', coords = vector3(443.0, -998.7, 30.8) },
        },
    },
    {
        id = 'ls_mrpd_back',
        label = 'Galinis įėjimas',
        interact = vector3(468.6, -1014.4, 26.4),
        interactDist = 2.5,
        defaultLocked = true,
        doors = {
            { model = 'gabz_mrpd_door_03', coords = vector3(469.7, -1014.4, 26.4) },
            { model = 'gabz_mrpd_door_03', coords = vector3(467.3, -1014.4, 26.4) },
        },
    },
    {
        id = 'ls_mrpd_interview_1',
        label = 'Tardymo kambarys 1',
        interact = vector3(486.1472, -987.6362, 26.2733),
        interactDist = 3.0,
        defaultLocked = false,
        doors = {
            { model = 'gabz_mrpd_door_03', coords = vector3(485.0, -987.6362, 26.2733) },
        },
    },
    {
        id = 'ls_mrpd_interview_2',
        label = 'Tardymo kambarys 2',
        interact = vector3(486.1502, -995.6803, 26.2733),
        interactDist = 3.0,
        defaultLocked = false,
        doors = {
            { model = 'gabz_mrpd_door_03', coords = vector3(485.0, -995.6803, 26.2733) },
        },
    },
    {
        id = 'ls_mrpd_back_gate',
        label = 'Kiemo vartai',
        interact = vector3(488.8, -1020.2, 30.0),
        interactDist = 14.0,
        defaultLocked = true,
        doors = {
            { model = 'hei_prop_station_gate', coords = vector3(488.8, -1017.2, 27.1) },
        },
    },
    {
        id = 'ls_mrpd_front_entry',
        label = 'Priekinis kiemas (vartai + borteliai)',
        doorType = 'yard_gate',
        interact = vector3(416.2, -1024.0, 29.85),
        interactDist = 5.5,
        defaultLocked = true,
        bollardRaiseZ = 0.38,
        gateOpenHeadingDelta = 82.0,
        doors = {
            { model = 'prop_facgate_07b', coords = vector3(419.99, -1025.0, 28.99), heading = 270.0 },
            {
                model = 'gabz_mrpd_bollards1',
                coords = vector3(409.9059, -1020.1597, 28.98),
                heading = 265.5023,
                restZ = 28.98,
            },
            {
                model = 'gabz_mrpd_bollards2',
                coords = vector3(410.3823, -1028.5387, 28.98),
                heading = 168.6483,
                restZ = 28.98,
            },
        },
        entityScan = {
            center = vector3(416.2, -1024.0, 29.35),
            radius = 14.0,
            models = { 'prop_facgate_07b', 'gabz_mrpd_bollards1', 'gabz_mrpd_bollards2' },
        },
    },
    {
        id = 'ls_mrpd_garage_roll',
        label = 'Garažo vartai (šonas)',
        doorType = 'garage_roll',
        interact = vector3(431.45, -1001.15, 26.75),
        interactDist = 4.0,
        defaultLocked = true,
        doors = {
            { model = 'gabz_mrpd_room13_parkingdoor', coords = vector3(431.45, -1001.15, 26.75), heading = 178.0 },
        },
        entityScan = {
            center = vector3(431.45, -1001.15, 26.75),
            radius = 10.0,
            models = { 'gabz_mrpd_room13_parkingdoor' },
        },
    },
    {
        id = 'ls_mrpd_garage_park',
        label = 'Garage (parking)',
        doorType = 'garage_roll',
        interact = vector3(464.1, -997.5, 26.3),
        interactDist = 2.0,
        defaultLocked = true,
        doors = {
            { model = 'gabz_mrpd_room13_parkingdoor', coords = vector3(464.1, -997.5, 26.3), heading = 88.0 },
        },
        entityScan = {
            center = vector3(464.1, -997.5, 26.3),
            radius = 10.0,
            models = { 'gabz_mrpd_room13_parkingdoor' },
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
    {
        id = 'davis_pd_main',
        label = 'Davis PD pagrindinės durys',
        interact = vector3(380.15, -1591.25, 29.76),
        interactDist = 3.0,
        defaultLocked = true,
        doors = {
            { model = 'gabz_davispd_maindoor_left', coords = vector3(379.85, -1591.55, 29.76) },
            { model = 'gabz_davispd_maindoor_right', coords = vector3(380.45, -1590.85, 29.76) },
        },
    },
    {
        id = 'davis_pd_fence_gate',
        label = 'Davis PD kiemo vartai',
        doorType = 'barrier',
        interact = vector3(397.85, -1607.09, 29.29),
        interactDist = 5.5,
        defaultLocked = true,
        doors = {
            { model = 'gabz_davispd_fancegate', coords = vector3(397.2, -1606.5, 29.35), heading = 320.0 },
        },
        entityScan = {
            center = vector3(397.2, -1606.5, 29.35),
            radius = 12.0,
            models = { 'gabz_davispd_fancegate' },
        },
    },
    {
        id = 'paleto_pd_yard_gate',
        label = 'Paleto PD kiemo vartai',
        doorType = 'barrier',
        interact = vector3(-459.2, 6016.3, 31.49),
        interactDist = 5.5,
        defaultLocked = true,
        doors = {
            { model = 'gabz_paletopd_gate_fence', coords = vector3(-453.5, 6025.0, 31.35) },
        },
        entityScan = {
            center = vector3(-453.5, 6025.0, 31.35),
            radius = 14.0,
            models = { 'gabz_paletopd_gate_fence', 'gabz_paletopd_gate_fence_01' },
        },
    },
}

--- Papildomi E taškai toms pačioms `PdDoorGroups` (be dubliavimo slabų) – Gabz MRPD.
Config.PdDoorInteractExtras = {
    { groupId = 'ls_mrpd_side', interact = vector3(441.28, -986.51, 30.71), interactDist = 3.2 },
    { groupId = 'ls_mrpd_reception', interact = vector3(441.39, -977.68, 30.79), interactDist = 3.2 },
    { groupId = 'ls_mrpd_reception', interact = vector3(457.03, -971.67, 30.71), interactDist = 3.2 },
    { groupId = 'ls_mrpd_back_gate', interact = vector3(488.8, -1017.2, 27.1), interactDist = 6.0 },
    { groupId = 'ls_mrpd_front_entry', interact = vector3(410.1, -1024.3, 29.75), interactDist = 5.0 },
    { groupId = 'davis_pd_main', interact = vector3(379.39, -1591.37, 29.76), interactDist = 3.0 },
}

--- Automatinis durų radimas (objektai žemėlapyje pagal modelį ir dėžę) – Gabz Sandy / Paleto MLO
Config.PdDoorDynamics = {
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
            -- Kai kuriuose paketuose būna typo pavadinime; laikom abu
            'hedwig_sheriif_garage_door',
            'hedwig_sheriff_garage_door',
        },
        pairDist = 4.35,
        interactDist = 2.85,
    },
    --- Gabz MRPD LS: visos papildomos vidaus / tarnybinės durys ir vartai (nebendrinama su manual `PdDoorGroups` lokacijomis).
    {
        stationId = 'ls_mrpd_cells',
        label = 'PD cele (LS MRPD)',
        bounds = { min = vector3(460.0, -1012.0, 24.0), max = vector3(492.0, -982.0, 32.0) },
        models = { 'gabz_mrpd_cells_door' },
        pairDist = 0.75,
        interactDist = 2.15,
        interactOffset = vector3(0.0, 0.0, 0.92),
    },
    {
        stationId = 'davis_cells',
        label = 'PD cele (Davis)',
        bounds = { min = vector3(358.0, -1610.0, 24.0), max = vector3(392.0, -1575.0, 36.0) },
        models = { 'gabz_davispd_cell_door' },
        pairDist = 0.75,
        interactDist = 2.15,
        interactOffset = vector3(0.0, 0.0, 0.92),
    },
    {
        stationId = 'paleto_cells',
        label = 'PD cele (Paleto)',
        bounds = { min = vector3(-448.0, 6005.0, 30.0), max = vector3(-418.0, 6035.0, 36.0) },
        models = { 'gabz_paletopd_cells_gate', 'gabz_paletopd_glassdoorway_cells' },
        pairDist = 0.85,
        interactDist = 2.25,
        interactOffset = vector3(0.0, 0.0, 0.92),
    },
    {
        stationId = 'ls_mrpd_gabz',
        label = 'PD durys (LS Gabz – auto)',
        bounds = {
            min = vector3(395.0, -1060.0, -14.0),
            max = vector3(522.0, -910.0, 72.0),
        },
        models = {
            'gabz_mrpd_reception_entrancedoor',
            'gabz_mrpd_door_03',
            --- parkingdoor valdoma per `PdDoorGroups` (garage_roll) – ne auto-scan
            'gabz_mrpd_cells_door',
            'hei_prop_station_door_lr',
            'hei_prop_station_door_sl',
            'hei_prop_station_door_ra',
            'hei_prop_station_door_rb',
            'hei_prop_station_door_lc',
            'hei_prop_station_door_rc',
            'prop_facgate_07b',
            'hei_prop_station_gate',
        },
        pairDist = 4.15,
        interactDist = 2.95,
        interactOffset = vector3(0.0, 0.0, 0.88),
        defaultLocked = true,
    },
    --- Vanilla / ne-Gabz LS MRPD: tik Rockstar durų propai
    {
        stationId = 'ls_mrpd_dyn',
        label = 'PD durys (LS – auto, vanilla)',
        bounds = {
            min = vector3(400.0, -1045.0, 23.5),
            max = vector3(505.0, -928.0, 58.0),
        },
        models = {
            'v_ilev_ph_gendoor004',
            'v_ilev_ph_gendoor003',
            'v_ilev_ph_gendoor002',
            'hei_prop_station_gate',
        },
        pairDist = 2.95,
        interactDist = 2.85,
        interactOffset = vector3(0.0, 0.0, 0.92),
    },
    {
        stationId = 'davis',
        label = 'PD durys (Davis Gabz)',
        bounds = { min = vector3(348.0, -1628.0, 20.0), max = vector3(412.0, -1562.0, 48.0) },
        models = {
            'gabz_davispd_maindoor_left',
            'gabz_davispd_maindoor_right',
            'gabz_davispd_singledoor_01',
            'gabz_davispd_singledoor_02',
            'gabz_davispd_singledoor_03',
            --- fancegate ir cele – valdomos per `PdDoorGroups` / `davis_cells`
        },
        pairDist = 3.85,
        interactDist = 2.85,
        interactOffset = vector3(0.0, 0.0, 0.88),
        defaultLocked = true,
    },
    {
        stationId = 'paleto',
        label = 'PD durys (Paleto)',
        bounds = { min = vector3(-470.0, 5975.0, 24.0), max = vector3(-395.0, 6055.0, 38.0) },
        models = {
            'gabz_paletopd_doors01',
            'gabz_paletopd_doors02',
            'gabz_paletopd_doors03',
            'gabz_paletopd_doors04',
            'gabz_paletopd_doors05',
            'gabz_paletopd_doors06',
            'gabz_paletopd_glassdoorway',
            'gabz_paletopd_glassdoorway_cells',
            'gabz_paletopd_gate_fence',
            'gabz_paletopd_gate_fence_01',
            'gabz_paletopd_cells_gate',
        },
        pairDist = 2.35,
        interactDist = 2.5,
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
