--- CCTV ir bodycam (MDT integracija)
Config.Surveillance = Config.Surveillance or {}

Config.Surveillance.BodycamItem = 'police_bodycam'

--- CCTV per MDT: leidžiama su mdt_cctv. Fizinis terminalas – tik prie stoties.
Config.Surveillance.CctvWatchStations = {
    { coords = vector3(441.2, -981.0, 31.25), radius = 55.0, label = 'MRPD' },
    { coords = vector3(379.5, -1591.5, 30.5), radius = 48.0, label = 'Davis PD' },
    { coords = vector3(1852.5, 3688.0, 34.75), radius = 40.0, label = 'Sandy PD' },
    { coords = vector3(-447.5, 6012.0, 32.75), radius = 40.0, label = 'Paleto PD' },
}

--- Po apiplėšimo/hack: min. sekundės tarp CCTV sabotavimo bangų
Config.Surveillance.CctvTamperCooldownSec = 45
Config.Surveillance.Bodycam = {
    batteryEnabled = true,
    batteryMax = 100,
    drainPerMinute = 2.5,
    lowBatteryPct = 15,
    autoOnPanic = true,
    viewMaxDistance = 0.0, --- 0 = neribota (tik duty + permission)
}

--- MDT: vietos (objektai) — kameros grupuojamos pagal siteId / bankId
Config.Surveillance.CctvSites = {
    fleeca_legion = { label = 'Fleeca – Legion Square', zone = 'bank' },
    fleeca_alta = { label = 'Fleeca – Alta', zone = 'bank' },
    fleeca_hawick = { label = 'Fleeca – Hawick', zone = 'bank' },
    fleeca_ocean = { label = 'Fleeca – Great Ocean', zone = 'bank' },
    fleeca_paleto = { label = 'Fleeca – Paleto Bay', zone = 'bank' },
    fleeca_route68 = { label = 'Fleeca – Route 68', zone = 'bank' },
    pacific = { label = 'Pacific Standard Bank', zone = 'bank' },
    vangelico = { label = 'Vangelico juvelyrika', zone = 'jewelry' },
    casino = { label = 'Diamond Casino', zone = 'casino' },
    mrpd = { label = 'Mission Row PD', zone = 'police' },
    sandy_pd = { label = 'Sandy Shores PD', zone = 'police' },
    paleto_pd = { label = 'Paleto Bay PD', zone = 'police' },
}

--- Kategorijos MDT filtre
Config.Surveillance.CctvCategories = {
    bank = 'Bankai',
    store = 'Parduotuvės',
    gas = 'Degalinės',
    jewelry = 'Juvelyrika',
    casino = 'Kazino',
    police = 'Policija',
    city = 'Miesto centras',
    traffic = 'Sankryžos',
    other = 'Kita',
}

--[[
  coords = kameros pozicija, lookAt = kur žiūri.
  Apiplėšimai: exports['fivempro_ltpd']:TamperCctv(camId, seconds) arba TamperCctvRadius(coords, radius, seconds)
]]
Config.Surveillance.CctvCameras = {
    -- Bankai (Fleeca / Pacific) — pozicija iš CCTV prop
    { id = 'fleeca_legion', label = 'Kasos zona', zone = 'bank', bankId = 'fleeca_legion', siteId = 'fleeca_legion', propModel = `prop_cctv_cam_01a`, propCoords = vector4(149.12, -1041.85, 29.37, 340.0), lookDistance = 13.0, pitchOffset = -16.0, yawMax = 48.0, pitchMax = 16.0, fov = 48.0, audio = true, spawnProp = true },
    { id = 'fleeca_legion_vault', label = 'Seifas', zone = 'bank', bankId = 'fleeca_legion', siteId = 'fleeca_legion', propModel = `prop_cctv_cam_02a`, propCoords = vector4(145.85, -1044.55, 29.37, 250.0), lookDistance = 11.0, pitchOffset = -20.0, yawMax = 42.0, pitchMax = 14.0, fov = 46.0, audio = true, spawnProp = true },
    { id = 'fleeca_alta', label = 'Kasos zona', zone = 'bank', bankId = 'fleeca_alta', siteId = 'fleeca_alta', propModel = `prop_cctv_cam_01b`, propCoords = vector4(313.45, -279.15, 54.16, 340.0), lookDistance = 13.0, pitchOffset = -16.0, yawMax = 48.0, pitchMax = 16.0, fov = 50.0, audio = true, spawnProp = true },
    { id = 'fleeca_hawick', label = 'Kasos zona', zone = 'bank', bankId = 'fleeca_hawick', siteId = 'fleeca_hawick', propModel = `prop_cctv_cam_01a`, propCoords = vector4(-353.35, -53.85, 49.04, 250.0), lookDistance = 12.0, pitchOffset = -16.0, yawMax = 45.0, pitchMax = 15.0, fov = 50.0, audio = true, spawnProp = true },
    { id = 'fleeca_ocean', label = 'Kasos zona', zone = 'bank', bankId = 'fleeca_ocean', siteId = 'fleeca_ocean', propModel = `prop_cctv_cam_03a`, propCoords = vector4(-2960.85, 483.25, 15.70, 85.0), lookDistance = 12.0, pitchOffset = -16.0, yawMax = 45.0, pitchMax = 15.0, fov = 50.0, audio = true, spawnProp = true },
    { id = 'fleeca_paleto', label = 'Kasos zona', zone = 'bank', bankId = 'fleeca_paleto', siteId = 'fleeca_paleto', propModel = `prop_cctv_cam_01a`, propCoords = vector4(-111.85, 6462.35, 31.63, 45.0), lookDistance = 12.0, pitchOffset = -16.0, yawMax = 45.0, pitchMax = 15.0, fov = 50.0, audio = true, spawnProp = true },
    { id = 'fleeca_route68', label = 'Kasos zona', zone = 'bank', bankId = 'fleeca_route68', siteId = 'fleeca_route68', propModel = `prop_cctv_cam_02a`, propCoords = vector4(1176.45, 2705.85, 38.09, 180.0), lookDistance = 12.0, pitchOffset = -16.0, yawMax = 45.0, pitchMax = 15.0, fov = 50.0, audio = true, spawnProp = true },
    { id = 'pacific_entrance', label = 'Įėjimas', zone = 'bank', bankId = 'pacific', siteId = 'pacific', propModel = `prop_cctv_cam_04a`, propCoords = vector4(255.85, 218.45, 106.29, 160.0), lookDistance = 16.0, pitchOffset = -14.0, yawMax = 50.0, pitchMax = 18.0, fov = 46.0, audio = true, spawnProp = true },
    { id = 'pacific_lobby', label = 'Lobby', zone = 'bank', bankId = 'pacific', siteId = 'pacific', propModel = `prop_cctv_cam_03a`, propCoords = vector4(247.35, 223.85, 106.29, 70.0), lookDistance = 18.0, pitchOffset = -18.0, yawMax = 52.0, pitchMax = 18.0, fov = 44.0, audio = true, spawnProp = true },

    -- Juvelyrika / kazino
    { id = 'vangelico_front', label = 'Vitrina', zone = 'jewelry', siteId = 'vangelico', propModel = `prop_cctv_cam_01a`, propCoords = vector4(-622.5, -232.0, 38.55, 210.0), lookDistance = 11.0, pitchOffset = -16.0, yawMax = 48.0, pitchMax = 16.0, fov = 50.0, audio = true, spawnProp = true },
    { id = 'vangelico_vault', label = 'Salė', zone = 'jewelry', siteId = 'vangelico', propModel = `prop_cctv_cam_02a`, propCoords = vector4(-629.0, -238.5, 38.55, 45.0), lookDistance = 12.0, pitchOffset = -18.0, yawMax = 50.0, pitchMax = 16.0, fov = 55.0, audio = true, spawnProp = true },
    { id = 'casino_main', label = 'Pagrindinė salė', zone = 'casino', siteId = 'casino', propModel = `prop_cctv_cam_03a`, propCoords = vector4(917.0, 43.5, 84.2, 320.0), lookDistance = 14.0, pitchOffset = -14.0, yawMax = 52.0, pitchMax = 18.0, fov = 55.0, audio = true, spawnProp = true },
    { id = 'casino_garage', label = 'Garažas', zone = 'casino', siteId = 'casino', propModel = `prop_cctv_cam_04a`, propCoords = vector4(936.0, 0.5, 78.25, 300.0), lookDistance = 12.0, pitchOffset = -16.0, yawMax = 48.0, pitchMax = 16.0, fov = 55.0, audio = true, spawnProp = true },

    -- Policija
    { id = 'mrpd_lobby', label = 'Vestibiulis', zone = 'police', siteId = 'mrpd', propModel = `prop_cctv_cam_01a`, propCoords = vector4(438.5, -985.8, 33.85, 200.0), lookDistance = 12.0, pitchOffset = -16.0, yawMax = 50.0, pitchMax = 16.0, fov = 52.0, audio = true, spawnProp = true },
    { id = 'mrpd_parking', label = 'Parkavimas', zone = 'police', siteId = 'mrpd', propModel = `prop_cctv_cam_02a`, propCoords = vector4(458.5, -1003.0, 28.75, 225.0), lookDistance = 13.0, pitchOffset = -16.0, yawMax = 50.0, pitchMax = 16.0, fov = 58.0, audio = true, spawnProp = true },
    { id = 'mrpd_roof', label = 'Stogas', zone = 'police', siteId = 'mrpd', propModel = `prop_cctv_cam_03a`, propCoords = vector4(463.0, -984.0, 44.5, 210.0), lookDistance = 14.0, pitchOffset = -14.0, yawMax = 52.0, pitchMax = 18.0, fov = 60.0, audio = false, spawnProp = true },
    { id = 'sandy_pd', label = 'Sandy Shores PD', zone = 'police', coords = vector3(1852.5, 3688.0, 34.75), lookAt = vector3(1846.0, 3692.0, 34.2), fov = 55.0, audio = true },
    { id = 'paleto_pd', label = 'Paleto Bay PD', zone = 'police', coords = vector3(-447.5, 6012.0, 32.75), lookAt = vector3(-441.0, 6016.0, 32.2), fov = 55.0, audio = true },

    -- Parduotuvės (24/7 / LTD)
    { id = '247_grove', label = '24/7 – Grove St', zone = 'store', coords = vector3(-50.5, -1754.5, 29.85), lookAt = vector3(-47.0, -1758.0, 29.4), fov = 54.0, audio = true },
    { id = '247_innocence', label = '24/7 – Innocence Blvd', zone = 'store', coords = vector3(31.8, -1348.2, 31.65), lookAt = vector3(26.0, -1340.0, 29.45), fov = 52.0, audio = true },
    { id = '247_mirror', label = '24/7 – Mirror Park', zone = 'store', coords = vector3(1160.5, -314.5, 69.55), lookAt = vector3(1156.0, -318.0, 69.1), fov = 54.0, audio = true },
    { id = '247_sandy', label = '24/7 – Sandy Shores', zone = 'store', coords = vector3(1963.5, 3746.0, 32.7), lookAt = vector3(1959.0, 3742.0, 32.25), fov = 54.0, audio = true },
    { id = 'ltd_grove', label = 'LTD – Davis', zone = 'store', coords = vector3(-43.5, -1748.0, 29.85), lookAt = vector3(-48.0, -1752.0, 29.4), fov = 52.0, audio = true },
    { id = 'ltd_rockford', label = 'LTD – Rockford Hills', zone = 'store', coords = vector3(-1828.5, 800.0, 138.65), lookAt = vector3(-1824.0, 796.0, 138.2), fov = 52.0, audio = true },

    -- Degalinės
    { id = 'gas_legion', label = 'Degalinė – Legion', zone = 'gas', coords = vector3(289.5, -1266.5, 29.85), lookAt = vector3(285.0, -1262.0, 29.4), fov = 56.0, audio = true },
    { id = 'gas_innocence', label = 'Degalinė – Strawberry', zone = 'gas', coords = vector3(265.0, -1261.0, 29.75), lookAt = vector3(260.0, -1256.0, 29.3), fov = 56.0, audio = true },
    { id = 'gas_paleto', label = 'Degalinė – Paleto', zone = 'gas', coords = vector3(170.0, 6638.0, 31.95), lookAt = vector3(165.0, 6642.0, 31.5), fov = 56.0, audio = true },
    { id = 'gas_route68', label = 'Degalinė – Route 68', zone = 'gas', coords = vector3(1039.5, 2671.0, 39.95), lookAt = vector3(1035.0, 2666.0, 39.5), fov = 56.0, audio = true },
    { id = 'gas_greatocean', label = 'Degalinė – Great Ocean', zone = 'gas', coords = vector3(-2555.0, 2316.5, 33.55), lookAt = vector3(-2550.0, 2320.0, 33.1), fov = 56.0, audio = true },

    -- Miesto centrai
    { id = 'legion_square', label = 'Legion Square', zone = 'city', coords = vector3(215.5, -920.0, 31.25), lookAt = vector3(210.0, -915.0, 30.7), fov = 62.0, audio = true },
    { id = 'pillbox_front', label = 'Pillbox – priekis', zone = 'city', coords = vector3(311.5, -592.0, 44.75), lookAt = vector3(306.0, -588.0, 44.2), fov = 58.0, audio = true },
    { id = 'cityhall', label = 'City Hall', zone = 'city', coords = vector3(-544.5, -204.0, 38.65), lookAt = vector3(-539.0, -200.0, 38.2), fov = 58.0, audio = true },
    { id = 'maze_bank_plaza', label = 'Maze Bank – plaza', zone = 'city', coords = vector3(-75.5, -818.5, 326.5), lookAt = vector3(-70.0, -812.0, 326.0), fov = 55.0, audio = false },

    -- Sankryžos
    { id = 'int_airport', label = 'Sankryža – LSIA prieiga', zone = 'traffic', coords = vector3(-1034.5, -2733.0, 14.25), lookAt = vector3(-1028.0, -2728.0, 13.8), fov = 60.0, audio = true },
    { id = 'int_delperro', label = 'Sankryža – Del Perro', zone = 'traffic', coords = vector3(-1512.5, -652.0, 29.55), lookAt = vector3(-1506.0, -648.0, 29.1), fov = 60.0, audio = true },
    { id = 'int_vinewood', label = 'Sankryža – Vinewood Blvd', zone = 'traffic', coords = vector3(293.5, 180.0, 104.75), lookAt = vector3(288.0, 185.0, 104.2), fov = 60.0, audio = true },
    { id = 'int_strawberry', label = 'Sankryža – Strawberry Ave', zone = 'traffic', coords = vector3(240.5, -1370.0, 30.95), lookAt = vector3(235.0, -1365.0, 30.5), fov = 60.0, audio = true },
    { id = 'int_palomino', label = 'Sankryža – Palomino Fwy', zone = 'traffic', coords = vector3(2558.5, 380.5, 108.95), lookAt = vector3(2553.0, 385.0, 108.5), fov = 60.0, audio = true },

    -- Kita RP
    { id = 'docs_warehouse', label = 'Docks – sandėliai', zone = 'other', coords = vector3(892.5, -3222.0, 6.45), lookAt = vector3(887.0, -3216.0, 5.95), fov = 58.0, audio = true },
    { id = 'docs_main', label = 'Docks – pagrindinis kelias', zone = 'other', coords = vector3(797.5, -2988.0, 6.45), lookAt = vector3(792.0, -2982.0, 5.95), fov = 58.0, audio = true },
    { id = 'sandy_airfield', label = 'Sandy – aerodromas', zone = 'other', coords = vector3(1747.5, 3273.0, 41.55), lookAt = vector3(1742.0, 3278.0, 41.1), fov = 62.0, audio = true },
    { id = 'grapeseed_main', label = 'Grapeseed – centras', zone = 'other', coords = vector3(1700.5, 4933.0, 42.45), lookAt = vector3(1695.0, 4938.0, 42.0), fov = 58.0, audio = true },
    { id = 'humane_labs', label = 'Humane Labs – vartai', zone = 'other', coords = vector3(3628.5, 3752.0, 29.15), lookAt = vector3(3623.0, 3757.0, 28.7), fov = 55.0, audio = false },
}
