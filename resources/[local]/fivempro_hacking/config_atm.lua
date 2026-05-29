Config.Atm = {}

Config.Atm.Models = {
    'prop_atm_01',
    'prop_atm_02',
    'prop_atm_03',
    'prop_fleeca_atm',
}

--- Fizinis ištraukimas
Config.Atm.DrillTimeMs = 18000
Config.Atm.PullMinDistance = 45.0
Config.Atm.PullMaxSpeedKmh = 12.0
Config.Atm.AttachedModel = 'prop_atm_01'

--- Grandinė: linija nuo bankomato, ALT prie automobilio galo
Config.Atm.ChainAttachControl = 19
Config.Atm.ChainAttachMaxDist = 4.2
Config.Atm.ChainRopeColor = { r = 180, g = 180, b = 190, a = 220 }

--- Laužimas saugioje vietoje
Config.Atm.CrackSteps = 4
Config.Atm.CrackTimeMs = 16000
Config.Atm.DyePackChance = 0.22
Config.Atm.DyeDamagePct = 0.55

--- Balansas
Config.Atm.PlayerCooldownSec = 900
Config.Atm.LocationCooldownSec = 1800
Config.Atm.CashMin = 650
Config.Atm.CashMax = 2200
Config.Atm.MarkedBillMin = 1
Config.Atm.MarkedBillMax = 3
Config.Atm.MarkedBillWorth = 420

--- Drop-off zonos (nugabenti ATM)
Config.Atm.Dropoffs = {
    { coords = vector3(1389.2, 3605.5, 34.9), radius = 12.0, label = 'Sandy – sandėlis' },
    { coords = vector3(-472.5, 6288.0, 13.6), radius = 12.0, label = 'Paleto – hangaras' },
    { coords = vector3(970.5, -1825.5, 31.1), radius = 14.0, label = 'Cypress – angaras' },
}

--- Transportas (klasės / modeliai)
Config.Atm.AllowedVehicleClasses = {
    [0] = false, [1] = true, [2] = true, [3] = true, [4] = true,
    [5] = false, [6] = true, [7] = false, [8] = false, [9] = true,
    [10] = true, [11] = true, [12] = true, [13] = false, [14] = false,
    [15] = false, [16] = false, [17] = true, [18] = true, [19] = false,
    [20] = true, [21] = false,
}
