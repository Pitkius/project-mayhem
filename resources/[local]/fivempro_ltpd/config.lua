Config = {}

--- Darbo pavadinimas turi sutapti su `qb-core/shared/jobs.lua` įrašu `ltpd`.
Config.JobName = 'ltpd'

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
}

--- Baudų šablonai (kodas rodomas MDT)
Config.FinePresets = {
    { code = 'SPEED', label = 'Greičio viršijimas', defaultAmount = 150 },
    { code = 'RED', label = 'Raudono šviesoforo pažeidimas', defaultAmount = 200 },
    { code = 'PARK', label = 'Netinkamas parkavimas', defaultAmount = 80 },
    { code = 'DOC', label = 'Dokumentų neturėjimas', defaultAmount = 120 },
    { code = 'NOISE', label = 'Triukšmo pažeidimas', defaultAmount = 100 },
}

--- Maks. atstumas iki ginklinės / PD garažo taško (patikra serveryje)
Config.ArmoryGarageDistance = 22.0

--- Blipai žemėlapyje (komisariatai)
Config.ShowStationBlips = true
Config.BlipSprite = 60
Config.BlipColour = 38
Config.BlipScale = 0.85

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
            coords = vector3(461.45, -981.21, 30.69),
            stashId = 'ltpd_armory_ls',
            label = 'Policijos ginklinė',
            maxweight = 5000000,
            slots = 90,
        },
        garage = {
            coords = vector3(459.85, -1014.55, 28.26),
            spawn = vector4(459.85, -1014.55, 28.26, 271.29),
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
        garage = {
            coords = vector3(1869.5, 3695.2, 33.53),
            spawn = vector4(1869.5, 3695.2, 33.53, 210.0),
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
        garage = {
            coords = vector3(-459.2, 6016.3, 31.49),
            spawn = vector4(-459.2, 6016.3, 31.49, 45.0),
        },
    },
}

Config.TargetDistance = 2.5
Config.MaxFineAmount = 50000
