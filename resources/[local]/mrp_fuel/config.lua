Config = {}

--- Kuro mažėjimas važiuojant (HUD skaito tą patį GetVehicleFuelLevel).
Config.EnableConsumption = true
Config.ConsumptionTickMs = 1000
--- Bazinis suvartojimas % per tick (variklis įjungtas, stovint).
Config.ConsumptionBase = 0.028
--- Papildomas % per tick kiekvienam km/h.
Config.ConsumptionPerKmh = 0.0011
--- Klasės daugiklis (GetVehicleClass).
Config.ClassMultiplier = {
    [0] = 0.85,  -- Compacts
    [1] = 0.95,  -- Sedans
    [2] = 1.05,  -- SUVs
    [3] = 1.0,   -- Coupes
    [4] = 1.15,  -- Muscle
    [5] = 1.2,   -- Sports Classics
    [6] = 1.25,  -- Sports
    [7] = 1.1,   -- Super
    [8] = 0.9,   -- Motorcycles
    [9] = 1.2,   -- Off-road
    [10] = 1.35, -- Industrial
    [11] = 1.3,  -- Utility
    [12] = 1.4,  -- Vans
    [13] = 0.0,  -- Cycles
    [14] = 1.5,  -- Boats
    [15] = 1.6,  -- Helicopters
    [16] = 1.5,  -- Planes
    [17] = 1.2,  -- Service
    [18] = 1.25, -- Emergency
    [19] = 1.35, -- Military
    [20] = 1.4,  -- Commercial
    [21] = 1.5,  -- Trains
}
Config.DisableGtaFuelConsumption = true
Config.ShutEngineOnEmpty = true
Config.EmptyNotifyCooldownMs = 12000

Config.BlipSprite = 361
Config.BlipColor = 2
Config.BlipScale = 0.75
Config.BlipLabel = 'Degalinė'

Config.PricePerLiter = 7
Config.MaxDistanceToPump = 4.5
Config.FuelTickMs = 450
Config.LitersPerTick = 1.2

Config.PumpModels = {
    `prop_gas_pump_1a`,
    `prop_gas_pump_1b`,
    `prop_gas_pump_1c`,
    `prop_gas_pump_1d`,
    `prop_vintage_pump`,
    `prop_gas_pump_old2`,
    `prop_gas_pump_old3`,
}

Config.Stations = {
    { x = 49.41,   y = 2778.79,  z = 58.04 },
    { x = -709.67, y = -904.17,  z = 19.21 },
    { x = 2678.89, y = 3279.43,  z = 55.24 },
    { x = 2005.05, y = 3774.43,  z = 32.40 },
    { x = 1697.35, y = 4923.46,  z = 42.06 },
    { x = -1819.54, y = 794.44,  z = 138.08 },
    { x = 263.894,  y = 2606.463, z = 44.983 },
    { x = 1039.958, y = 2671.134, z = 39.550 },
    { x = 1207.260, y = 2660.175, z = 37.899 },
    { x = 2539.685, y = 2594.192, z = 37.944 },
    { x = 2679.858, y = 3263.946, z = 55.240 },
    { x = 1701.314, y = 6416.028, z = 32.763 },
    { x = 179.857,  y = 6602.839, z = 31.868 },
    { x = -94.4619, y = 6419.594, z = 31.489 },
    { x = -2554.996, y = 2334.40, z = 33.078 },
    { x = -1437.622, y = -276.747, z = 46.207 },
    { x = -2096.243, y = -320.286, z = 13.168 },
    { x = -724.619,  y = -935.163, z = 19.213 },
    { x = -526.019,  y = -1211.003, z = 18.184 },
    { x = -70.2148,  y = -1761.791, z = 29.534 },
    { x = 265.648,   y = -1261.309, z = 29.292 },
    { x = 819.653,   y = -1028.846, z = 26.403 },
    { x = 1208.951,  y = -1402.567, z = 35.224 },
    { x = 1181.381,  y = -330.847,  z = 69.316 },
    { x = 620.843,   y = 269.100,   z = 103.089 },
    { x = 2581.321,  y = 362.039,   z = 108.468 },
    { x = 176.631,   y = -1562.025, z = 29.263 },
    { x = -319.292,  y = -1471.715, z = 30.549 },
}

