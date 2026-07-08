--- CCTV ir bodycam (MDT integracija)
Config.Surveillance = Config.Surveillance or {}

--- Laikinai išjungta kol sutvarkoma (MDT langai lieka, rodoma „neveikia“ žinutė).
--- Neįtakoja: PANIC mygtuko, dispatch blipų įprastame žemėlapyje.
--- MDT GPS žemėlapis: Config.MdtMapMaintenance (atskirai).
Config.Surveillance.MaintenanceMode = true
Config.Surveillance.MaintenanceMessage =
    'Sistema laikinai neveikia. Dėl finansavimo skyrimo ir įrengimo kreipkitės į miesto merą.'

Config.Surveillance.BodycamItem = 'police_bodycam'

--- CCTV per MDT: leidžiama su mdt_cctv. Fizinis terminalas – tik prie stoties.
Config.Surveillance.CctvWatchStations = {
    { coords = vector3(441.2, -981.0, 31.25), radius = 55.0, label = 'MRPD' },
    { coords = vector3(1852.5, 3688.0, 34.75), radius = 40.0, label = 'Sandy PD' },
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
  Apiplėšimai: exports['mrp_ltpd']:TamperCctv(camId, seconds) arba TamperCctvRadius(coords, radius, seconds)
]]
Config.Surveillance.CctvCameras = {
    -- Bankai (Fleeca / Pacific) — pozicija iš CCTV prop
    { id = 'fleeca_legion', label = 'Kasos zona', zone = 'bank', bankId = 'fleeca_legion', siteId = 'fleeca_legion', coords = vector3(149.12, -1041.85, 31.2), lookAt = vector3(147.05, -1046.05, 29.37), fov = 48.0, audio = true, spawnProp = false },
    { id = 'fleeca_legion_vault', label = 'Seifas', zone = 'bank', bankId = 'fleeca_legion', siteId = 'fleeca_legion', coords = vector3(145.85, -1044.55, 31.0), lookAt = vector3(147.05, -1046.05, 29.37), fov = 46.0, audio = true, spawnProp = false },
    { id = 'fleeca_alta', label = 'Kasos zona', zone = 'bank', bankId = 'fleeca_alta', siteId = 'fleeca_alta', coords = vector3(313.45, -279.15, 55.5), lookAt = vector3(311.0, -283.0, 54.16), fov = 50.0, audio = true, spawnProp = false },
    { id = 'fleeca_hawick', label = 'Kasos zona', zone = 'bank', bankId = 'fleeca_hawick', siteId = 'fleeca_hawick', coords = vector3(-353.35, -53.85, 50.5), lookAt = vector3(-353.55, -55.45, 49.04), fov = 50.0, audio = true, spawnProp = false },
    { id = 'fleeca_ocean', label = 'Kasos zona', zone = 'bank', bankId = 'fleeca_ocean', siteId = 'fleeca_ocean', coords = vector3(-2960.85, 483.25, 17.0), lookAt = vector3(-2957.85, 481.35, 15.70), fov = 50.0, audio = true, spawnProp = false },
    { id = 'fleeca_paleto', label = 'Kasos zona', zone = 'bank', bankId = 'fleeca_paleto', siteId = 'fleeca_paleto', coords = vector3(-111.85, 6462.35, 33.0), lookAt = vector3(-109.5, 6464.0, 31.63), fov = 50.0, audio = true, spawnProp = false },
    { id = 'fleeca_route68', label = 'Kasos zona', zone = 'bank', bankId = 'fleeca_route68', siteId = 'fleeca_route68', coords = vector3(1176.45, 2705.85, 39.5), lookAt = vector3(1175.65, 2712.90, 38.09), fov = 50.0, audio = true, spawnProp = false },
    { id = 'pacific_entrance', label = 'Įėjimas', zone = 'bank', bankId = 'pacific', siteId = 'pacific', coords = vector3(255.85, 218.45, 107.5), lookAt = vector3(253.25, 228.45, 101.68), fov = 46.0, audio = true, spawnProp = false },
    { id = 'pacific_lobby', label = 'Lobby', zone = 'bank', bankId = 'pacific', siteId = 'pacific', coords = vector3(247.35, 223.85, 107.5), lookAt = vector3(253.25, 228.45, 101.68), fov = 44.0, audio = true, spawnProp = false },

    -- Juvelyrika / kazino
    { id = 'vangelico_front', label = 'Vitrina', zone = 'jewelry', siteId = 'vangelico', coords = vector3(-622.5, -232.0, 39.5), lookAt = vector3(-624.5, -232.5, 38.55), fov = 50.0, audio = true, spawnProp = false },
    { id = 'vangelico_vault', label = 'Salė', zone = 'jewelry', siteId = 'vangelico', coords = vector3(-629.0, -238.5, 39.5), lookAt = vector3(-631.0, -239.0, 38.55), fov = 55.0, audio = true, spawnProp = false },
    { id = 'casino_main', label = 'Aptarnavimo įėjimas', zone = 'casino', siteId = 'casino', coords = vector3(924.77, 46.85, 81.11), lookAt = vector3(936.52, 55.08, 81.11), fov = 55.0, audio = true, spawnProp = false },
    { id = 'casino_service', label = 'Sandėlio zona', zone = 'casino', siteId = 'casino', coords = vector3(936.52, 55.08, 81.11), lookAt = vector3(948.32, 33.44, 81.11), fov = 55.0, audio = true, spawnProp = false },

    -- Policija
    { id = 'mrpd_lobby', label = 'Vestibiulis', zone = 'police', siteId = 'mrpd', propModel = `prop_cctv_cam_01a`, propCoords = vector4(438.5, -985.8, 33.85, 200.0), lookAt = vector3(441.2, -981.5, 30.2), lookDistance = 14.0, pitchOffset = -18.0, yawMax = 50.0, pitchMax = 16.0, fov = 52.0, audio = true, spawnProp = false, propSearchRadius = 22.0 },
    { id = 'mrpd_parking', label = 'Parkavimas', zone = 'police', siteId = 'mrpd', propModel = `prop_cctv_cam_02a`, propCoords = vector4(458.5, -1003.0, 28.75, 225.0), lookAt = vector3(454.0, -1000.5, 28.2), lookDistance = 13.0, pitchOffset = -16.0, yawMax = 50.0, pitchMax = 16.0, fov = 58.0, audio = true, spawnProp = false, propSearchRadius = 22.0 },
    { id = 'mrpd_roof', label = 'Stogas', zone = 'police', siteId = 'mrpd', propModel = `prop_cctv_cam_03a`, propCoords = vector4(463.0, -984.0, 44.5, 210.0), lookAt = vector3(459.0, -988.0, 42.5), lookDistance = 14.0, pitchOffset = -14.0, yawMax = 52.0, pitchMax = 18.0, fov = 60.0, audio = false, spawnProp = false, propSearchRadius = 22.0 },
    { id = 'sandy_pd', label = 'Sandy Shores PD', zone = 'police', coords = vector3(1852.5, 3688.0, 34.75), lookAt = vector3(1846.0, 3692.0, 34.2), fov = 55.0, audio = true },

    -- Parduotuvės (24/7 / LTD)
    { id = '247_grove', label = '24/7 – Grove St', zone = 'store', coords = vector3(-48.2, -1757.8, 30.4), lookAt = vector3(-47.0, -1758.0, 29.4), fov = 54.0, audio = true, spawnProp = false },
    { id = '247_innocence', label = '24/7 – Innocence Blvd', zone = 'store', coords = vector3(27.5, -1342.5, 31.2), lookAt = vector3(26.0, -1340.0, 29.45), fov = 52.0, audio = true, spawnProp = false },
    { id = '247_mirror', label = '24/7 – Mirror Park', zone = 'store', coords = vector3(1158.0, -316.5, 70.0), lookAt = vector3(1156.0, -318.0, 69.1), fov = 54.0, audio = true, spawnProp = false },
    { id = '247_sandy', label = '24/7 – Sandy Shores', zone = 'store', coords = vector3(1960.5, 3744.0, 33.2), lookAt = vector3(1959.0, 3742.0, 32.25), fov = 54.0, audio = true, spawnProp = false },
    { id = 'ltd_grove', label = 'LTD – Davis', zone = 'store', coords = vector3(-46.0, -1750.5, 30.2), lookAt = vector3(-48.0, -1752.0, 29.4), fov = 52.0, audio = true, spawnProp = false },
    { id = 'ltd_rockford', label = 'LTD – Rockford Hills', zone = 'store', coords = vector3(-1826.0, 798.5, 139.0), lookAt = vector3(-1824.0, 796.0, 138.2), fov = 52.0, audio = true, spawnProp = false },

    -- Degalinės
    { id = 'gas_legion', label = 'Degalinė – Legion', zone = 'gas', coords = vector3(287.0, -1264.0, 30.2), lookAt = vector3(285.0, -1262.0, 29.4), fov = 56.0, audio = true, spawnProp = false },
    { id = 'gas_innocence', label = 'Degalinė – Strawberry', zone = 'gas', coords = vector3(263.0, -1259.0, 30.1), lookAt = vector3(260.0, -1256.0, 29.3), fov = 56.0, audio = true, spawnProp = false },
    { id = 'gas_paleto', label = 'Degalinė – Paleto', zone = 'gas', coords = vector3(168.5, 6636.5, 32.3), lookAt = vector3(165.0, 6642.0, 31.5), fov = 56.0, audio = true, spawnProp = false },
    { id = 'gas_route68', label = 'Degalinė – Route 68', zone = 'gas', coords = vector3(1037.5, 2669.0, 40.2), lookAt = vector3(1035.0, 2666.0, 39.5), fov = 56.0, audio = true, spawnProp = false },
    { id = 'gas_greatocean', label = 'Degalinė – Great Ocean', zone = 'gas', coords = vector3(-2553.0, 2318.5, 34.0), lookAt = vector3(-2550.0, 2320.0, 33.1), fov = 56.0, audio = true, spawnProp = false },

    -- Miesto centrai
    { id = 'legion_square', label = 'Legion Square', zone = 'city', coords = vector3(213.0, -918.0, 31.8), lookAt = vector3(210.0, -915.0, 30.7), fov = 62.0, audio = true, spawnProp = false },
    { id = 'pillbox_front', label = 'Pillbox – priekis', zone = 'city', coords = vector3(309.0, -590.0, 45.2), lookAt = vector3(306.0, -588.0, 44.2), fov = 58.0, audio = true, spawnProp = false },
    { id = 'cityhall', label = 'City Hall', zone = 'city', coords = vector3(-542.0, -202.0, 39.1), lookAt = vector3(-539.0, -200.0, 38.2), fov = 58.0, audio = true, spawnProp = false },
    { id = 'maze_bank_plaza', label = 'Maze Bank – plaza', zone = 'city', coords = vector3(-73.5, -816.5, 327.0), lookAt = vector3(-70.0, -812.0, 326.0), fov = 55.0, audio = false, spawnProp = false },

    -- Sankryžos
    { id = 'int_airport', label = 'Sankryža – LSIA prieiga', zone = 'traffic', coords = vector3(-1032.0, -2731.0, 14.7), lookAt = vector3(-1028.0, -2728.0, 13.8), fov = 60.0, audio = true, spawnProp = false },
    { id = 'int_delperro', label = 'Sankryža – Del Perro', zone = 'traffic', coords = vector3(-1510.0, -650.0, 30.0), lookAt = vector3(-1506.0, -648.0, 29.1), fov = 60.0, audio = true, spawnProp = false },
    { id = 'int_vinewood', label = 'Sankryža – Vinewood Blvd', zone = 'traffic', coords = vector3(291.5, 182.0, 105.2), lookAt = vector3(288.0, 185.0, 104.2), fov = 60.0, audio = true, spawnProp = false },
    { id = 'int_strawberry', label = 'Sankryža – Strawberry Ave', zone = 'traffic', coords = vector3(238.5, -1368.0, 31.4), lookAt = vector3(235.0, -1365.0, 30.5), fov = 60.0, audio = true, spawnProp = false },
    { id = 'int_palomino', label = 'Sankryža – Palomino Fwy', zone = 'traffic', coords = vector3(2556.5, 382.5, 109.4), lookAt = vector3(2553.0, 385.0, 108.5), fov = 60.0, audio = true, spawnProp = false },

    -- Kita RP
    { id = 'docs_warehouse', label = 'Docks – sandėliai', zone = 'other', coords = vector3(890.5, -3220.0, 6.9), lookAt = vector3(887.0, -3216.0, 5.95), fov = 58.0, audio = true, spawnProp = false },
    { id = 'docs_main', label = 'Docks – pagrindinis kelias', zone = 'other', coords = vector3(795.5, -2986.0, 6.9), lookAt = vector3(792.0, -2982.0, 5.95), fov = 58.0, audio = true, spawnProp = false },
    { id = 'sandy_airfield', label = 'Sandy – aerodromas', zone = 'other', coords = vector3(1745.5, 3275.0, 42.0), lookAt = vector3(1742.0, 3278.0, 41.1), fov = 62.0, audio = true, spawnProp = false },
    { id = 'grapeseed_main', label = 'Grapeseed – centras', zone = 'other', coords = vector3(1698.5, 4935.0, 42.9), lookAt = vector3(1695.0, 4938.0, 42.0), fov = 58.0, audio = true, spawnProp = false },
    { id = 'humane_labs', label = 'Humane Labs – vartai', zone = 'other', coords = vector3(3626.5, 3754.0, 29.6), lookAt = vector3(3623.0, 3757.0, 28.7), fov = 55.0, audio = false, spawnProp = false },
}
