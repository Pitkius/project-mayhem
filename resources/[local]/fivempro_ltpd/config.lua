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
}

--- Baudų šablonai (kodas rodomas MDT)
Config.FinePresets = {
    { code = 'SPEED', label = 'Greičio viršijimas', defaultAmount = 150 },
    { code = 'RED', label = 'Raudono šviesoforo pažeidimas', defaultAmount = 200 },
    { code = 'PARK', label = 'Netinkamas parkavimas', defaultAmount = 80 },
    { code = 'DOC', label = 'Dokumentų neturėjimas', defaultAmount = 120 },
    { code = 'NOISE', label = 'Triukšmo pažeidimas', defaultAmount = 100 },
}

--- Policijos postai (keisk pagal savo MLO – čia pagrindinės LS / Sandy / Paleto vietos)
Config.Stations = {
    {
        id = 'ls_main',
        label = 'Los Santos – pagrindinė komisariatas',
        coords = vector3(441.84, -982.05, 30.69),
        heading = 90.0,
        mdt = true,
        duty = true,
    },
    {
        id = 'sandy',
        label = 'Sandy Shores',
        coords = vector3(1853.2, 3686.5, 34.27),
        heading = 210.0,
        mdt = true,
        duty = true,
    },
    {
        id = 'paleto',
        label = 'Paleto Bay',
        coords = vector3(-448.15, 6012.0, 31.72),
        heading = 45.0,
        mdt = true,
        duty = true,
    },
}

Config.TargetDistance = 2.5
Config.MaxFineAmount = 50000
