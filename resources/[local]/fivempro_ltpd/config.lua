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
    boss_menu = 7, -- Įdarb./atleisti/rangas (isboss arba ≥ šis grade – qb-core rangų sutapimas)
    --- PD sirenos / laikina įranga ant civilinės mašinos
    pd_siren_controller = 0,
    pd_emergency_kit = 0,
    --- PD išorinių / vidinių durų ir vartų užraktas (E) – tik tarnyboje
    pd_doors = 0,
}

--- Šviesų ir sirenos valdymas (masinoje): režimas per entity statebag (sinchr. visiems žaidėjams)
Config.EmergencyVehicle = {
    --- qb-menu komandos
    sirenMenuCommand = 'pdsirenai',
    kitMenuCommand = 'pdiranga',
    --- kai išlipi iš vairuotojo vietos – išjungti sirenos režimą ir garsą
    resetModeWhenLeaveDriverSeat = true,
    --- nuo transporto centro atstumas (m), kuriuo serveris priima veiksmus
    validateDistance = 28.0,
}

--- Baudų šablonai (kodas rodomas MDT)
Config.FinePresets = {
    { code = 'SPEED', label = 'Greičio viršijimas', defaultAmount = 150 },
    { code = 'RED', label = 'Raudono šviesoforo pažeidimas', defaultAmount = 200 },
    { code = 'PARK', label = 'Netinkamas parkavimas', defaultAmount = 80 },
    { code = 'DOC', label = 'Dokumentų neturėjimas', defaultAmount = 120 },
    { code = 'NOISE', label = 'Triukšmo pažeidimas', defaultAmount = 100 },
}

--- Maks. atstumas iki ginklinės / sandėlių / PD garažo (patikra serveryje)
Config.ArmoryGarageDistance = 38.0
--- Vadovybės meniu serverio patikra – priartėk prie „management“ taško
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
        --- Policijos salonas (fivempro_dealership) – sujungta su garažu: vienas qb-target „garažo“ taške
        policeDealership = {
            coords = vector3(441.64, -1013.14, 28.62),
            heading = 175.52,
        },
        garage = {
            coords = vector3(441.64, -1013.14, 28.62),
            spawn = vector4(441.64, -1013.14, 28.62, 175.52),
        },
        --- Rūbinė (qb-clothing outfit meniu) – patikrink su savo MLO (persirengimo zona)
        locker = {
            coords = vector3(461.85, -998.35, 30.69),
            heading = 90.0,
        },
        --- Trys sandėliai (prie ginklinės / rūbinės eilės – patikrink MLO)
        stashes = {
            {
                coords = vector3(449.55, -993.45, 30.69),
                stashId = 'ltpd_stash_public_ls',
                label = 'PD sandėlis (bendras)',
                minGrade = 0,
                maxweight = 2000000,
                slots = 60,
            },
            {
                coords = vector3(449.55, -992.35, 30.69),
                stashId = 'ltpd_stash_grade3_ls',
                label = 'PD sandėlis (nuo 3 rango)',
                minGrade = 3,
                maxweight = 2500000,
                slots = 70,
            },
            {
                coords = vector3(449.55, -991.25, 30.69),
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

--- Tarnybinė PD apranga (ne asmeniniai qb-clothing išsaugoti outfitai). Drawable pagal mp freemode – keisk pagal savo MLO / odę.
Config.DutyOutfits = {
    {
        label = 'Uniforma 1 (marškiniai, be liemenės)',
        description = 'Patrulio bazinė apranga',
        minGrade = 0,
        armour = 0,
        male = { [4] = 35, [6] = 25, [8] = 58, [11] = 55, [9] = 0 },
        female = { [4] = 34, [6] = 25, [8] = 35, [11] = 48, [9] = 0 },
    },
    {
        label = 'Uniforma 2 + policijos liemenė',
        description = 'Lengva balistinė',
        minGrade = 0,
        armour = 50,
        male = { [4] = 35, [6] = 25, [8] = 58, [11] = 55, [9] = 2 },
        female = { [4] = 34, [6] = 25, [8] = 35, [11] = 48, [9] = 2 },
    },
    {
        label = 'Uniforma 3 (stipresnė liemenė)',
        description = 'Nuo 2 rango',
        minGrade = 2,
        armour = 100,
        male = { [4] = 35, [6] = 25, [8] = 58, [11] = 55, [9] = 4 },
        female = { [4] = 34, [6] = 25, [8] = 35, [11] = 48, [9] = 4 },
    },
}

Config.TargetDistance = 2.5
Config.MaxFineAmount = 50000

--- PD durys / vartai (Gabz MRPD LS + automatinis Sandy / Paleto MLO skenavimas)
Config.PdDoorToggleReach = 4.2
Config.PdDoorGroups = {
    {
        id = 'ls_mrpd_reception',
        label = 'Reception entrance',
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
        label = 'Side entrance',
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
        label = 'Rear entrance',
        interact = vector3(468.6, -1014.4, 26.4),
        interactDist = 2.5,
        defaultLocked = true,
        doors = {
            { model = 'gabz_mrpd_door_03', coords = vector3(469.7, -1014.4, 26.4) },
            { model = 'gabz_mrpd_door_03', coords = vector3(467.3, -1014.4, 26.4) },
        },
    },
    {
        id = 'ls_mrpd_back_gate',
        label = 'Rear yard gate',
        interact = vector3(488.8, -1020.2, 30.0),
        interactDist = 14.0,
        defaultLocked = true,
        doors = {
            { model = 'hei_prop_station_gate', coords = vector3(488.8, -1017.2, 27.1) },
        },
    },
    {
        id = 'ls_mrpd_front_gate',
        label = 'Front gate',
        interact = vector3(419.9, -1021.04, 30.5),
        interactDist = 18.0,
        defaultLocked = true,
        doors = {
            { model = 'prop_facgate_07b', coords = vector3(419.99, -1025.0, 28.99) },
        },
    },
    {
        id = 'ls_mrpd_garage_park',
        label = 'Garage (parking)',
        interact = vector3(464.1, -997.5, 26.3),
        interactDist = 2.0,
        defaultLocked = true,
        doors = {
            { model = 'gabz_mrpd_room13_parkingdoor', coords = vector3(464.1, -997.5, 26.3) },
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
        interact = vector3(1854.92, 3701.15, 33.73),
        interactDist = 3.8,
        defaultLocked = true,
        doors = {
            { model = 'hedwig_sheriff_garage_gardoor', coords = vector3(1854.92, 3701.15, 33.73) },
        },
    },
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
    --- Vanilla / ne-Gabz LS MRPD: tik Rockstar durų propai — ne dubliuoja `PdDoorGroups` Gabz įrašų
    {
        stationId = 'ls_mrpd_dyn',
        label = 'PD durys (LS – auto, vanilla durys)',
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
        },
        pairDist = 2.35,
        interactDist = 2.5,
    },
}
