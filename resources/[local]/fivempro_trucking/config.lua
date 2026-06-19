Config = {}

Config.RegisterCost = 0
Config.CompanyCreateCost = 50000
Config.CompanyMinLevel = 5
Config.IllegalMinLevel = 12
Config.IllegalPayMultiplier = 2.5
Config.ContractRefreshSec = 300
--- Vieno kontrakto galiojimo laikas (sek.) — pasibaigus automatiškai pakeičiamas nauju.
Config.ContractTtlSec = 300
Config.LoadDurationMs = 6000
Config.UnloadDurationMs = 7000
Config.PickupRadius = 18.0
Config.DeliveryRadius = 22.0

Config.LevelXp = {
    [1] = 0,
    [2] = 400,
    [3] = 900,
    [4] = 1500,
    [5] = 2400,
    [6] = 3400,
    [7] = 4600,
    [8] = 6000,
    [9] = 7600,
    [10] = 9500,
    [11] = 11500,
    [12] = 14000,
    [13] = 16800,
    [14] = 20000,
    [15] = 23500,
    [16] = 27500,
    [17] = 32000,
    [18] = 37000,
    [19] = 42500,
    [20] = 50000,
}

Config.ReputationStars = {
    [1] = 0,
    [2] = 80,
    [3] = 200,
    [4] = 380,
    [5] = 600,
}

Config.XpPerDelivery = { min = 35, max = 120 }
Config.RepPerDelivery = { min = 4, max = 18 }
Config.RepPerFailedDelivery = { min = 8, max = 20 }

--- Misija atšaukiama, jei darbinis transportas per daug pažeistas ar sunaikintas.
Config.VehicleFailBodyHealth = 280.0
Config.VehicleFailEngineHealth = 150.0

Config.Pay = {
    base = 180,
    perKm = 42,
    companyBonus = 0.18,
    ownFleetBonus = 0.12,
}

Config.DefaultStartHubId = 'ls_docks'

--- Logistikos centras (planšetė, furgonas, dėžių pakrovimas).
Config.LogisticsCenter = {
    terminal = {
        coords = vector3(1206.2418, -3157.0623, 5.5277),
        heading = 175.5256,
    },
    truckSpawn = {
        coords = vector3(1218.9822, -3193.9375, 5.5279),
        heading = 181.2378,
    },
    truckModel = 'mule',
    heavySpawn = {
        coords = vector3(1204.5, -3193.9375, 5.5279),
        heading = 181.2378,
    },
    boxProp = 'hei_prop_heist_box',
    boxCount = { min = 3, max = 8 },
    spotRadius = 1.85,
    truckLoadRadius = 4.8,
    boxSpots = {
        { coords = vector3(1218.9540, -3176.1790, 5.5279), heading = 261.4153 },
        { coords = vector3(1215.5833, -3162.7029, 5.5278), heading = 88.5626 },
        { coords = vector3(1215.6646, -3156.6306, 5.5278), heading = 82.0240 },
        { coords = vector3(1219.0490, -3147.3210, 5.5278), heading = 268.3811 },
        { coords = vector3(1227.8285, -3149.0527, 5.5278), heading = 276.8595 },
        { coords = vector3(1227.7533, -3161.2925, 5.5278), heading = 274.4042 },
        { coords = vector3(1224.2358, -3176.4561, 5.5279), heading = 84.8647 },
        { coords = vector3(1224.2406, -3169.7268, 5.5278), heading = 82.9993 },
    },
    anims = {
        pickup = { dict = 'anim@move_m@trash', clip = 'pickup', flag = 0, duration = 1100 },
        carry = { dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49 },
        place = { dict = 'anim@heists@narcotics@trash', clip = 'drop_front', flag = 0, duration = 1400 },
    },
}
--- Jei true — serverio atsarginis kelio atstumas (tik kol klientas negrąžino tikslaus)
Config.RoadDistanceFactor = 1.28

Config.Map = {
    minX = -4000.0,
    minY = -4000.0,
    maxX = 4500.0,
    maxY = 6625.0,
    imageFile = 'asset/gtav_satellite_2048.png',
}

--- Vienintelis TruckNet terminalas (žemėlapio blipas + paėmimo pradžia).
Config.RegistrationTerminals = {
    {
        id = 'logistics_center',
        label = 'Logistikos centras',
        hubId = 'ls_docks',
        coords = vector3(1206.2418, -3157.0623, 5.5277),
        heading = 175.5256,
        blip = { sprite = 477, color = 47, scale = 0.85, label = 'Logistikos centras' },
    },
}

Config.Hubs = {
    ls_docks = {
        label = 'Logistikos centras',
        region = 'los_santos',
        coords = vector3(1206.2418, -3157.0623, 5.5277),
        radius = 45.0,
    },
    airport_cargo = {
        label = 'Oro uosto kroviniai',
        region = 'los_santos',
        coords = vector3(-1024.6, -2694.2, 13.8),
        radius = 40.0,
    },
    factory_district = {
        label = 'Fabrikų rajonas',
        region = 'los_santos',
        coords = vector3(917.4, -1264.8, 25.5),
        radius = 32.0,
    },
    cypress_warehouse = {
        label = 'Cypress sandėliai',
        region = 'los_santos',
        coords = vector3(799.2, -2506.4, 20.1),
        radius = 34.0,
    },
    oil_refinery = {
        label = 'Naftos perdirbimo gamykla',
        region = 'los_santos',
        coords = vector3(2747.3, 1507.2, 24.5),
        radius = 38.0,
    },
    humane_labs = {
        label = 'Humane Labs',
        region = 'blaine',
        coords = vector3(3626.8, 3759.4, 28.5),
        radius = 36.0,
    },
    paleto_lumber = {
        label = 'Paleto medienos sandėlis',
        region = 'paleto',
        coords = vector3(-551.2, 5326.4, 70.2),
        radius = 34.0,
    },
    paleto_bay = {
        label = 'Paleto įlankos depas',
        region = 'paleto',
        coords = vector3(160.18, 6403.82, 31.22),
        radius = 30.0,
    },
    sandy_shores = {
        label = 'Sandy Shores',
        region = 'sandy',
        coords = vector3(1739.31, 3310.52, 41.22),
        radius = 32.0,
    },
    harmony = {
        label = 'Harmony',
        region = 'harmony',
        coords = vector3(612.4, 2788.2, 42.0),
        radius = 28.0,
    },
}

Config.CargoTypes = {
    food = { label = 'Maistas', minLevel = 1, minReputation = 1, category = 'standard', risk = 'low', payMult = 1.0, xpMult = 1.0, boxes = { min = 2, max = 4 } },
    furniture = { label = 'Baldai', minLevel = 1, minReputation = 1, category = 'standard', risk = 'low', payMult = 1.05, xpMult = 1.0, boxes = { min = 3, max = 5 } },
    construction = { label = 'Statybinės medžiagos', minLevel = 2, minReputation = 1, category = 'standard', risk = 'low', payMult = 1.1, xpMult = 1.05, boxes = { min = 4, max = 6 } },
    mail = { label = 'Pašto siuntos', minLevel = 1, minReputation = 1, category = 'standard', risk = 'low', payMult = 0.95, xpMult = 0.95, boxes = { min = 2, max = 3 } },
    electronics = { label = 'Elektronika', minLevel = 3, minReputation = 2, category = 'standard', risk = 'medium', payMult = 1.2, xpMult = 1.1, boxes = { min = 3, max = 5 } },
    luxury_cars = { label = 'Prabangūs automobiliai', minLevel = 10, minReputation = 3, category = 'special', risk = 'medium', payMult = 1.65, xpMult = 1.35, boxes = { min = 6, max = 8 }, minVehicleTier = 'heavy' },
    machinery = { label = 'Statybinė technika', minLevel = 10, minReputation = 3, category = 'special', risk = 'medium', payMult = 1.55, xpMult = 1.3, boxes = { min = 6, max = 8 }, minVehicleTier = 'truck' },
    valuables = { label = 'Brangūs kroviniai', minLevel = 10, minReputation = 4, category = 'special', risk = 'high', payMult = 1.8, xpMult = 1.4, boxes = { min = 4, max = 6 }, minVehicleTier = 'medium' },
    fuel = { label = 'Degalai', minLevel = 15, minReputation = 3, category = 'hazard', risk = 'high', payMult = 1.75, xpMult = 1.45, boxes = { min = 5, max = 7 }, minVehicleTier = 'truck' },
    chemicals = { label = 'Chemikalai', minLevel = 15, minReputation = 4, category = 'hazard', risk = 'high', payMult = 1.85, xpMult = 1.5, boxes = { min = 5, max = 7 }, minVehicleTier = 'truck' },
    contraband = { label = 'Kontrabanda', minLevel = 12, minReputation = 3, category = 'illegal', risk = 'extreme', payMult = 2.2, xpMult = 1.2, illegal = true, boxes = { min = 3, max = 5 } },
    weapon_parts = { label = 'Ginklų komponentai', minLevel = 14, minReputation = 4, category = 'illegal', risk = 'extreme', payMult = 2.8, xpMult = 1.3, illegal = true, boxes = { min = 4, max = 6 }, minVehicleTier = 'medium' },
}

--- Misijos transportas pagal krovinio kiekį (dėžių skaičių).
Config.MissionTrucks = {
    tiers = {
        van = { models = { 'speedo', 'pony', 'mule' } },
        medium = { models = { 'mule', 'boxville', 'benson' } },
        truck = { models = { 'benson', 'mule' } },
        heavy = { models = { 'phantom', 'hauler', 'packer' } },
    },
    trailers = {
        default = 'trailers',
        bulk = 'trailers2',
        tanker = 'tanker',
    },
}

Config.Vehicles = {
    mule = { label = 'Mule', tier = 1, minLevel = 1, class = 'van' },
    benson = { label = 'Benson', tier = 1, minLevel = 2, class = 'truck' },
    speedo = { label = 'Speedo', tier = 1, minLevel = 1, class = 'van' },
    pony = { label = 'Pony', tier = 1, minLevel = 1, class = 'van' },
    boxville = { label = 'Boxville', tier = 1, minLevel = 2, class = 'van' },
    phantom = { label = 'Phantom', tier = 2, minLevel = 5, class = 'heavy', license = 'heavy_truck' },
    hauler = { label = 'Hauler', tier = 2, minLevel = 5, class = 'heavy', license = 'heavy_truck' },
    packer = { label = 'Packer', tier = 2, minLevel = 6, class = 'heavy', license = 'heavy_truck' },
    roadtrain = { label = 'Roadtrain', tier = 2, minLevel = 8, class = 'heavy', license = 'heavy_truck' },
}

Config.FleetShop = {
    { model = 'phantom', price = 85000 },
    { model = 'hauler', price = 72000 },
    { model = 'packer', price = 68000 },
    { model = 'roadtrain', price = 95000 },
}

Config.Unlocks = {
    heavy_truck_license = 5,
    own_company = 5,
    special_cargo = 10,
    hazard_cargo = 15,
}

Config.AllowedVehicleHashes = {}
for model in pairs(Config.Vehicles) do
    Config.AllowedVehicleHashes[joaat(model)] = model
end

Config.IllegalPoliceChance = 22
