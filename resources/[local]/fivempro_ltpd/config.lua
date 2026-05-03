Config = {}

--- Darbo pavadinimas turi sutapti su `qb-core/shared/jobs.lua` įrašu `ltpd`.
Config.JobName = 'ltpd'
--- Jei true, qb-target ir serveris priima ir seną `police` darbą (kol migruoji į ltpd).
Config.AcceptLegacyPoliceJob = true

--[[
  Padaliniai – saugoma DB `ltpd_profiles.division`.
  Teisės: žemiausias grade (0–10), kuriam leidžiama (optional filtras).
]]
Config.Divisions = {
    patrol = { label = 'Patrulių tarnyba', minGrade = 0 },
    traffic = { label = 'Kelių policija', minGrade = 1 },
    criminal = { label = 'Kriminalinė policija', minGrade = 3 },
    aras = { label = 'ARAS', minGrade = 2 },
    admin = { label = 'Administracija', minGrade = 7 },
}

--- Minimalus grade (0 = Kursantas) veiksmui
Config.Permissions = {
    mdt_open = 0,
    mdt_search_basic = 0,
    mdt_search_full = 3, -- pinigai, transportas, išsamiau
    mdt_fine = 1,
    mdt_wanted = 2,
    mdt_arrest_record = 2,
    cuff = 1,
    search_inventory = 1,
    traffic_radar = 1, -- rezervas / ateities integracija
    division_admin = 8,
    armory = 0, -- bendra policijos ginklinė (stash)
    garage = 0, -- PD tarnybinio transporto išėmimas
    boss_menu = 8, -- Įdarb./atleisti/rangas (nuo Komisaras; isboss irgi leidžia)
}

--- Baudų šablonai (kodas rodomas MDT)
Config.FinePresets = {
    { code = 'SPEED', label = 'Greičio viršijimas', defaultAmount = 150 },
    { code = 'RED', label = 'Raudono šviesoforo pažeidimas', defaultAmount = 200 },
    { code = 'PARK', label = 'Netinkamas parkavimas', defaultAmount = 80 },
    { code = 'DOC', label = 'Dokumentų neturėjimas', defaultAmount = 120 },
    { code = 'NOISE', label = 'Triukšmo pažeidimas', defaultAmount = 100 },
}

--- Maks. atstumas iki ginklinės / PD garažo / vadovybės (patikra serveryje)
Config.ArmoryGarageDistance = 22.0
Config.ManagementRadius = 12.0

--- Blipai žemėlapyje (komisariatai)
Config.ShowStationBlips = true
Config.BlipSprite = 60
Config.BlipColour = 38
Config.BlipScale = 0.85
--- Stogo helipado blipas (PD sraigtasparnis)
Config.ShowHelipadBlip = false
Config.HelipadBlipSprite = 43
Config.HelipadBlipScale = 0.9

--- Tarnybinis transportas (modeliai turi būti whitelist – žr. server spawnFleet)
Config.FleetVehicles = {
    { model = 'police', label = 'Cruiser' },
    { model = 'police2', label = 'Buffalo' },
    { model = 'police3', label = 'Interceptor' },
    { model = 'policeb', label = 'Motociklas' },
    { model = 'sheriff', label = 'Sheriff Cruiser' },
    { model = 'sheriff2', label = 'Sheriff SUV' },
    { model = 'riot', label = 'Riot' },
}

--- Sraigtasparniai (stogas / helipadas) – spawn ant `heliGarage.spawn`
Config.FleetHelicopters = {
    { model = 'polmav', label = 'Police Maverick' },
    { model = 'buzzard2', label = 'Buzzard (tarnybinis)' },
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
        heading = 90.0,
        mdt = true,
        duty = true,
        armory = {
            coords = vector3(450.85, -993.26, 30.69),
            stashId = 'ltpd_armory_ls',
            label = 'Policijos ginklinė (rūbinė)',
            maxweight = 5000000,
            slots = 90,
        },
        --- PD asmeninis garažas (fivempro_garages id – mašinos perkamos salone)
        pdGarageId = 'pd_ls_main',
        --- Policijos salonas (fivempro_dealership) – tas pats UI kaip autosalonas
        policeDealership = {
            coords = vector3(459.25, -1008.02, 28.26),
            heading = 268.0,
        },
        garage = {
            coords = vector3(441.64, -1013.14, 28.62),
            spawn = vector4(441.64, -1013.14, 28.62, 175.52),
        },
        --- Trys sandėliai: visi PD / nuo 3 rango / nuo 8 rango
        stashes = {
            {
                coords = vector3(451.2, -994.1, 30.69),
                stashId = 'ltpd_stash_public_ls',
                label = 'PD sandėlis (bendras)',
                minGrade = 0,
                maxweight = 2000000,
                slots = 60,
            },
            {
                coords = vector3(452.4, -994.1, 30.69),
                stashId = 'ltpd_stash_grade3_ls',
                label = 'PD sandėlis (nuo 3 rango)',
                minGrade = 3,
                maxweight = 2500000,
                slots = 70,
            },
            {
                coords = vector3(453.6, -994.1, 30.69),
                stashId = 'ltpd_stash_grade8_ls',
                label = 'PD sandėlis (nuo 8 rango)',
                minGrade = 8,
                maxweight = 3000000,
                slots = 80,
            },
        },
        management = {
            coords = vector3(447.17, -973.33, 30.69),
            heading = 184.59,
        },
        --- Stogas: helipadas + sraigtasparnio „garažas“ (keisk Z pagal MLO)
        heliGarage = {
            coords = vector3(449.32, -981.38, 43.69),
            spawn = vector4(449.32, -981.38, 44.05, 90.0),
        },
    },
    {
        id = 'sandy',
        label = 'Sandy Shores',
        coords = vector3(1853.2, 3686.5, 34.27),
        heading = 210.0,
        mdt = true,
        duty = true,
        armory = {
            coords = vector3(1849.12, 3690.04, 34.27),
            stashId = 'ltpd_armory_sandy',
            label = 'Policijos ginklinė (Sandy)',
            maxweight = 4000000,
            slots = 70,
        },
        pdGarageId = 'pd_sandy',
        policeDealership = {
            coords = vector3(1855.5, 3688.2, 34.27),
            heading = 210.0,
        },
        garage = {
            coords = vector3(1869.5, 3695.2, 33.53),
            spawn = vector4(1869.5, 3695.2, 33.53, 210.0),
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
        heading = 45.0,
        mdt = true,
        duty = true,
        armory = {
            coords = vector3(-449.38, 6014.12, 31.72),
            stashId = 'ltpd_armory_paleto',
            label = 'Policijos ginklinė (Paleto)',
            maxweight = 4000000,
            slots = 70,
        },
        pdGarageId = 'pd_paleto',
        policeDealership = {
            coords = vector3(-451.0, 6010.5, 31.72),
            heading = 45.0,
        },
        garage = {
            coords = vector3(-459.2, 6016.3, 31.49),
            spawn = vector4(-459.2, 6016.3, 31.49, 45.0),
        },
        stashes = {
            { coords = vector3(-450.5, 6015.2, 31.72), stashId = 'ltpd_stash_public_paleto', label = 'PD sandėlis (bendras)', minGrade = 0, maxweight = 2000000, slots = 60 },
            { coords = vector3(-451.5, 6015.2, 31.72), stashId = 'ltpd_stash_grade3_paleto', label = 'PD sandėlis (nuo 3 rango)', minGrade = 3, maxweight = 2500000, slots = 70 },
            { coords = vector3(-452.5, 6015.2, 31.72), stashId = 'ltpd_stash_grade8_paleto', label = 'PD sandėlis (nuo 8 rango)', minGrade = 8, maxweight = 3000000, slots = 80 },
        },
    },
}

Config.TargetDistance = 2.5
Config.MaxFineAmount = 50000
