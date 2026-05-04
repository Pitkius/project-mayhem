Config = Config or {}

--- Pause žemėlapio legenda: tas pats skaičius visiems garažų blipams = viena grupė (kaip vienas „tipas“).
--- 0 = nekeisti. Kiti variantai – eksperimentuok pagal savo kliento versiją.
Config.GarageMapBlipCategory = 134

-- Žemėlapyje vienas bendras garažų blipas (qb-target zonos lieka kiekviename garaže).
Config.UseSingleGarageMapBlip = false
Config.GarageMapBlipLabel = 'Garažai'
-- Jei nil – blipas ties pirmo sąrašo garažo koordinatėmis (miesto centras).
Config.GarageMapBlipCoords = nil

Config.Garages = {
    { id = 'pillboxgarage', label = 'Pillbox Garage', coords = vector3(215.8, -809.2, 30.73), heading = 157.0, spawn = vector4(223.1, -804.2, 30.55, 248.0), previewLateralM = -0.85 },
    { id = 'legionsquare', label = 'Legion Garage', coords = vector3(-342.1, -874.7, 31.32), heading = 351.0, spawn = vector4(-334.9, -890.9, 31.07, 168.0) },
    { id = 'delperro', label = 'Del Perro Garage', coords = vector3(-1183.1, -1511.1, 4.36), heading = 126.0, spawn = vector4(-1188.4, -1498.3, 4.37, 124.0) },
    { id = 'vespucci', label = 'Vespucci Garage', coords = vector3(-1159.4, -739.2, 19.88), heading = 311.0, spawn = vector4(-1144.8, -745.6, 19.63, 312.0) },
    { id = 'hawick', label = 'Hawick Garage', coords = vector3(273.0, -344.3, 44.92), heading = 252.0, spawn = vector4(284.1, -332.3, 44.92, 252.0) },
    { id = 'airport', label = 'Airport Garage', coords = vector3(-979.5, -2710.7, 13.86), heading = 330.0, spawn = vector4(-966.6, -2698.4, 13.83, 330.0) },
    { id = 'mirrorpark', label = 'Mirror Park Garage', coords = vector3(1036.4, -763.8, 57.99), heading = 225.0, spawn = vector4(1047.8, -778.9, 58.02, 90.0) },
    { id = 'rancho', label = 'Rancho Garage', coords = vector3(367.2, -2037.1, 21.7), heading = 320.0, spawn = vector4(378.6, -2041.3, 21.56, 51.0) },
    { id = 'sandy', label = 'Sandy Shores Garage', coords = vector3(1737.7, 3710.2, 34.14), heading = 22.0, spawn = vector4(1722.9, 3713.9, 34.2, 20.0) },
    { id = 'grapeseed', label = 'Grapeseed Garage', coords = vector3(1718.7, 4933.2, 42.08), heading = 146.0, spawn = vector4(1718.7, 4933.2, 42.08, 146.0) },
    { id = 'paleto', label = 'Paleto Garage', coords = vector3(110.8, 6617.4, 31.89), heading = 224.0, spawn = vector4(128.6, 6621.6, 31.78, 225.0) },
    { id = 'zancudo', label = 'Route 68 Garage', coords = vector3(-2553.8, 2334.5, 33.06), heading = 92.0, spawn = vector4(-2545.9, 2331.4, 33.06, 92.0) },
    { id = 'chumash', label = 'Chumash Garage', coords = vector3(-3142.3, 1128.7, 20.86), heading = 339.0, spawn = vector4(-3134.8, 1112.9, 20.85, 339.0) },
    { id = 'vinewood', label = 'Vinewood Garage', coords = vector3(596.2, 90.7, 92.13), heading = 69.0, spawn = vector4(604.9, 97.7, 92.12, 248.0) },
    { id = 'casino', label = 'Casino Garage', coords = vector3(895.0, -1.7, 78.76), heading = 328.0, spawn = vector4(909.1, -6.9, 78.76, 147.0) },
    --- Policijos garažai (tik ltpd/police + tarnyba) – tas pats UI kaip kiti garažai
    { id = 'pd_ls_main', label = 'Policijos garažas', coords = vector3(441.64, -1013.14, 28.62), heading = 175.52, spawn = vector4(441.64, -1013.14, 28.62, 175.52), policeOnly = true, hideBlip = true },
    { id = 'pd_sandy', label = 'Policijos garažas (Sandy)', coords = vector3(1869.5, 3695.2, 33.53), heading = 210.0, spawn = vector4(1869.5, 3695.2, 33.53, 210.0), policeOnly = true, hideBlip = true },
    { id = 'pd_paleto', label = 'Policijos garažas (Paleto)', coords = vector3(-459.2, 6016.3, 31.49), heading = 45.0, spawn = vector4(-459.2, 6016.3, 31.49, 45.0), policeOnly = true, hideBlip = true },
    --- Mechanikas / EMS (job: mechanic, ambulance) – tik qb-target iš darbo resursų
    { id = 'mech_ls', label = 'Mechanikų garažas', coords = vector3(-350.41, -117.01, 38.95), heading = 246.37, spawn = vector4(-347.5, -119.2, 38.95, 246.37), mechanicOnly = true, hideBlip = true },
    { id = 'ems_ls', label = 'Greitosios pagalbos garažas', coords = vector3(-460.42, -324.28, 34.50), heading = 91.30, spawn = vector4(-464.42, -324.37, 34.50, 91.30), emsOnly = true, hideBlip = true },
    { id = 'taxi_ls', label = 'Taksi garažas', coords = vector3(902.12, -172.41, 74.08), heading = 56.0, spawn = vector4(908.42, -168.95, 74.12, 146.0), taxiOnly = true, hideBlip = true },
}

--- Tik šie modeliai rodomi / priimami PD garažuose (`pd_*`).
Config.PoliceVehicleModels = {
    police = true, police2 = true, police3 = true, police4 = true, police5 = true,
    policeb = true, policet = true, sheriff = true, sheriff2 = true,
    riot = true, fbi = true, fbi2 = true, pranger = true,
    policeold1 = true, policeold2 = true,
    polmav = true, buzzard2 = true,
}

Config.MechanicVehicleModels = {
    flatbed = true, towtruck = true, towtruck2 = true, minivan = true, sadler = true,
}

Config.EmsVehicleModels = {
    ambulance = true, granger = true,
}

Config.TaxiVehicleModels = {
    taxi = true,
    cabby = true,
}

Config.TargetDistance = 2.2

-- Žemės apskritimas + [E] — matosi priartėjus; spawn = parkuoti, coords = atidaryti garažą
Config.EnableGroundMarkers = true
Config.MarkerDrawDistance = 32.0
Config.MarkerOpenRadius = 2.5
Config.MarkerParkRadius = 6.5
Config.MarkerParkMaxSpeedKmh = 12.0
Config.MarkerSpawnScale = { x = 4.2, y = 4.2, z = 0.32 }
Config.MarkerDeskScale = { x = 2.2, y = 2.2, z = 0.22 }
