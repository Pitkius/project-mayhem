Config = {}

Config.GarageId = 'usedcarlot'
Config.ReturnGarage = 'pillboxgarage'
Config.BuySpawn = vector4(404.85, -1630.42, 29.29, 230.0)

Config.Booth = {
    coords = vector3(409.2, -1622.8, 29.29),
    size = vector3(1.6, 1.6, 2.0),
    heading = 230.0,
    label = 'Naudotų auto aikštelė',
}

Config.LotZone = {
    center = vector3(415.0, -1635.0, 29.29),
    radius = 28.0,
}

Config.Slots = {
    vector4(411.15, -1638.20, 29.29, 230.0),
    vector4(413.35, -1639.55, 29.29, 230.0),
    vector4(415.55, -1640.90, 29.29, 230.0),
    vector4(417.75, -1642.25, 29.29, 230.0),
    vector4(419.95, -1643.60, 29.29, 230.0),
    vector4(422.15, -1644.95, 29.29, 230.0),
    vector4(424.35, -1646.30, 29.29, 230.0),
    vector4(426.55, -1647.65, 29.29, 230.0),
}

Config.Blip = {
    enabled = true,
    sprite = 225,
    color = 5,
    scale = 0.75,
    label = 'Naudotos mašinos',
}

Config.FeePercent = 0.07
Config.MaxListingsPerPlayer = 3
Config.MinPrice = 1000
Config.MaxPrice = 5000000

Config.SpawnDistance = 28.0
Config.DespawnDistance = 42.0
Config.ProximityTickMs = 1250

Config.TargetDistance = 2.4
Config.VehicleTargetDistance = 3.0

-- Fleet / service models that cannot be listed
Config.BlockedModels = {
    polmav = true, buzzard2 = true,
    mrpd1 = true, mrpd2 = true, mrpd3 = true, mrpd4 = true,
    mrpd5 = true, mrpd6 = true, mrpd7 = true, mrpd8 = true,
    mrpd9 = true, mrpd10 = true, mrpd11 = true, mrpd12 = true,
    mrpd13 = true, mrpd14 = true, mrpd15 = true, mrpd16 = true,
    mrpd17 = true, mrpd18 = true, mrpd19 = true, mrpd20 = true,
    mrpd22 = true, mrpd21 = true, mrpd23 = true, mrpd24 = true, mrpd25 = true, mrpd26 = true, mrpd27 = true,
    ambulance = true, granger = true, ems1 = true, ems2 = true,
    flatbed = true, towtruck = true, towtruck2 = true,
    taxi = true, cabby = true,
    pranger = true, ripley = true,
}
