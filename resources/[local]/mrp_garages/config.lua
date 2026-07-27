Config = Config or {}

--[[
  mrp_garages — garažų sąrašas + job-specific garažai.

  Laukai:
    id            — unikalus; naudojamas DB player_vehicles.garage
    coords        — qb-target zona (interakcija)
    spawn         — vector4 kur spawnina išimtą transportą
    policeOnly    — tik police + on duty (PD garažai)
    hideBlip      — nerodyti viešame žemėlapyje (darbo garažai)

  PD susiejimas:
    mrp_ltpd Config.Stations[].pdGarageId → šio failo id (pd_ls_main, pd_sandy)
    mrp_dealership PoliceDealership.garageByStation — kur įrašyti nupirktą TP
]]

--- Pause žemėlapio legenda: tas pats skaičius visiems garažų blipams = viena grupė (kaip vienas „tipas“).
--- 0 = nekeisti. Kiti variantai – eksperimentuok pagal savo kliento versiją.
Config.GarageMapBlipCategory = 134

-- Žemėlapyje vienas bendras garažų blipas (qb-target zonos lieka kiekviename garaže).
Config.UseSingleGarageMapBlip = false
Config.GarageMapBlipLabel = 'Garažai'
-- Jei nil – blipas ties pirmo sąrašo garažo koordinatėmis (miesto centras).
Config.GarageMapBlipCoords = nil

Config.Garages = {
    { id = 'pillboxgarage', label = 'Pillbox garažas', coords = vector3(215.8, -809.2, 30.73), heading = 157.0, spawn = vector4(223.1, -804.2, 30.55, 248.0), previewLateralM = -0.85 },
    { id = 'legionsquare', label = 'Legion aikštės garažas', coords = vector3(-342.1, -874.7, 31.32), heading = 351.0, spawn = vector4(-334.9, -890.9, 31.07, 168.0) },
    { id = 'delperro', label = 'Del Perro garažas', coords = vector3(-1183.1, -1511.1, 4.36), heading = 126.0, spawn = vector4(-1188.4, -1498.3, 4.37, 124.0) },
    { id = 'vespucci', label = 'Vespucci garažas', coords = vector3(-1159.4, -739.2, 19.88), heading = 311.0, spawn = vector4(-1144.8, -745.6, 19.63, 312.0) },
    { id = 'hawick', label = 'Hawick garažas', coords = vector3(273.0, -344.3, 44.92), heading = 252.0, spawn = vector4(284.1, -332.3, 44.92, 252.0) },
    { id = 'airport', label = 'Oro uosto garažas', coords = vector3(-979.5, -2710.7, 13.86), heading = 330.0, spawn = vector4(-966.6, -2698.4, 13.83, 330.0) },
    { id = 'mirrorpark', label = 'Mirror Park garažas', coords = vector3(1036.4, -763.8, 57.99), heading = 225.0, spawn = vector4(1047.8, -778.9, 58.02, 90.0) },
    { id = 'rancho', label = 'Rancho garažas', coords = vector3(367.2, -2037.1, 21.7), heading = 320.0, spawn = vector4(378.6, -2041.3, 21.56, 51.0) },
    { id = 'sandy', label = 'Sandy Shores garažas', coords = vector3(1737.7, 3710.2, 34.14), heading = 22.0, spawn = vector4(1722.9, 3713.9, 34.2, 20.0) },
    { id = 'ls_marina', label = 'Laivų garažas (LS)', garageType = 'boat', coords = vector3(-802.92, -1352.35, 5.15), heading = 110.0, spawn = vector4(-794.0, -1382.0, 0.12, 110.0), blipSprite = 357, blipColor = 3, hideBlip = true },
    { id = 'sandy_marina', label = 'Laivų garažas (Sandy)', garageType = 'boat', coords = vector3(714.35, 4096.85, 30.73), heading = 180.0, spawn = vector4(708.5, 4122.0, 29.8, 180.0), blipSprite = 357, blipColor = 3, hideBlip = true },
    { id = 'ls_heli', label = 'Malūnsparnių garažas (LS)', garageType = 'heli', coords = vector3(-1142.5, -2864.8, 13.95), heading = 330.0, spawn = vector4(-1145.2, -2865.5, 13.95, 330.0), blipSprite = 43, blipColor = 3, hideBlip = true },
    { id = 'sandy_heli', label = 'Malūnsparnių garažas (Sandy)', garageType = 'heli', coords = vector3(1770.15, 3239.85, 42.13), heading = 15.0, spawn = vector4(1772.0, 3246.0, 42.13, 15.0), blipSprite = 43, blipColor = 3, hideBlip = true },
    { id = 'grapeseed', label = 'Grapeseed garažas', coords = vector3(1718.7, 4933.2, 42.08), heading = 146.0, spawn = vector4(1718.7, 4933.2, 42.08, 146.0) },
    { id = 'paleto', label = 'Paleto garažas', coords = vector3(110.8, 6617.4, 31.89), heading = 224.0, spawn = vector4(128.6, 6621.6, 31.78, 225.0) },
    { id = 'zancudo', label = 'Route 68 garažas', coords = vector3(-2553.8, 2334.5, 33.06), heading = 92.0, spawn = vector4(-2545.9, 2331.4, 33.06, 92.0) },
    { id = 'chumash', label = 'Chumash garažas', coords = vector3(-3142.3, 1128.7, 20.86), heading = 339.0, spawn = vector4(-3134.8, 1112.9, 20.85, 339.0) },
    { id = 'vinewood', label = 'Vinewood garažas', coords = vector3(596.2, 90.7, 92.13), heading = 69.0, spawn = vector4(604.9, 97.7, 92.12, 248.0) },
    { id = 'casino', label = 'Kazino garažas', coords = vector3(895.0, -1.7, 78.76), heading = 328.0, spawn = vector4(909.1, -6.9, 78.76, 147.0) },
    --- Cayo Perico (vieši garažai — blipai tik priartėjus prie salos)
    { id = 'cayo_vehicle', label = 'Cayo Perico garažas', garageType = 'car', requireIsland = true, coords = vector3(4519.86, -4514.64, 4.50), heading = 28.0, spawn = vector4(4512.63, -4516.42, 4.17, 27.77) },
    { id = 'cayo_heli', label = 'Cayo Perico malūnsparnių garažas', garageType = 'heli', requireIsland = true, coords = vector3(4489.08, -4453.93, 4.22), heading = 200.0, spawn = vector4(4489.08, -4453.93, 6.50, 200.0), blipSprite = 43, blipColor = 3 },
    { id = 'cayo_boat', label = 'Cayo Perico laivų garažas', garageType = 'boat', requireIsland = true, coords = vector3(4930.77, -5145.10, 2.47), heading = 70.0, spawn = vector4(4933.00, -5135.00, 0.12, 65.0), blipSprite = 410, blipColor = 3 },
    --- Policijos garažai — susieta su mrp_ltpd pdGarageId + mrp_dealership salonu
    --- coords = interakcija; spawn = kur atsiranda išimtas / nupirktas TP
    { id = 'pd_ls_main', label = 'Policijos garažas (MRPD)', coords = vector3(447.9836, -967.4344, 22.8469), heading = 84.1690, spawn = vector4(472.4337, -967.5765, 22.6502, 180.2519), policeOnly = true, hideBlip = true },
    { id = 'pd_sandy', label = 'Policijos garažas (Sandy)', coords = vector3(1869.5, 3695.2, 33.53), heading = 210.0, spawn = vector4(1869.5, 3695.2, 33.53, 210.0), policeOnly = true, hideBlip = true },
    --- Mechanikas / EMS (job: mechanic, ambulance) – tik qb-target iš darbo resursų
    { id = 'mech_ls', label = 'Mechanikų garažas', coords = vector3(128.5848, -3013.5708, 7.0409), heading = 178.1475, spawn = vector4(125.9513, -3023.2095, 7.0409, 87.3217), mechanicOnly = true, hideBlip = true },
    { id = 'ems_ls', label = 'Greitosios pagalbos garažas (Pillbox)', coords = vector3(339.32, -584.32, 28.80), heading = 70.0, spawn = vector4(331.58, -543.68, 28.74, 340.0), emsOnly = true, hideBlip = true },
    { id = 'ems_sandy', label = 'EMS garažas (Sandy)', coords = vector3(1843.5, 3663.8, 33.85), heading = 210.0, spawn = vector4(1843.5, 3663.8, 33.85, 210.0), emsOnly = true, hideBlip = true },
    { id = 'ems_paleto', label = 'EMS garažas (Paleto)', coords = vector3(-254.0, 6347.0, 32.50), heading = 135.0, spawn = vector4(-254.0, 6347.0, 32.50, 135.0), emsOnly = true, hideBlip = true },
    { id = 'taxi_ls', label = 'Taksi garažas', coords = vector3(902.12, -172.41, 74.08), heading = 56.0, spawn = vector4(908.42, -168.95, 74.12, 146.0), taxiOnly = true, hideBlip = true },
    { id = 'ranger_main', label = 'Gamtos apsaugos garažas', coords = vector3(371.33, 791.31, 187.47), heading = 261.0, spawn = vector4(371.33, 791.31, 187.47, 261.0), rangerOnly = true, hideBlip = true },
}

--- Tik MRPD pack'ai + sraigtasparniai (`pd_*` garažai). Spawn: mrpd1-24.
Config.PoliceVehicleModels = {
    polmav = true, buzzard2 = true,
    mrpd1 = true, mrpd2 = true, mrpd3 = true, mrpd4 = true,
    mrpd5 = true, mrpd6 = true, mrpd7 = true, mrpd8 = true,
    mrpd9 = true, mrpd10 = true, mrpd11 = true, mrpd12 = true, mrpd24 = true,
    mrpd13 = true, mrpd14 = true, mrpd15 = true, mrpd16 = true, mrpd23 = true,
    mrpd17 = true, mrpd18 = true, mrpd19 = true, mrpd20 = true,
    mrpd21 = true, mrpd22 = true,
}

Config.MechanicVehicleModels = {
    flatbed = true, towtruck = true, towtruck2 = true, minivan = true, sadler = true,
}

Config.EmsVehicleModels = {
    ambulance = true, granger = true,
    ems1 = true, ems2 = true,
}

Config.TaxiVehicleModels = {
    taxi = true,
    cabby = true,
}

Config.RangerVehicleModels = {
    pranger = true,
    ripley = true,
    blazer = true,
    granger = true,
    maverick = true,
}

Config.TargetDistance = 2.2

-- Žemės apskritimas + [E] — matosi priartėjus; spawn = parkuoti, coords = atidaryti garažą
Config.EnableGroundMarkers = true
Config.MarkerDrawDistance = 38.0
Config.MarkerOpenRadius = 3.0
Config.MarkerParkRadius = 6.5
Config.MarkerParkMaxSpeedKmh = 12.0
Config.MarkerSpawnScale = { x = 4.2, y = 4.2, z = 0.32 }
Config.MarkerDeskScale = { x = 2.2, y = 2.2, z = 0.22 }
