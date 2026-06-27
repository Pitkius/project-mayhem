Config = {}

Config.IslandCenter = vector3(4840.57, -5174.42, 2.0)

--- Kada krauti salos IPL / tekstūras (tik šiam klientui)
Config.StreamRadius = 2200.0
--- Kada iškrauti IPL (histerėzė — kad nejunginėtų prie sienos)
Config.UnloadRadius = 2550.0
--- Kada įjungti Cayo pause žemėlapį + salos minimapą (tik ant salos)
Config.MapRadius = 1800.0
--- @deprecated naudok MapRadius
Config.MinimapRadius = Config.MapRadius
Config.IslandLoadRadius = Config.MapRadius

--- Papildomos zonos, kur forsuojamas collision
Config.StreamZones = {
    vector3(4715.03, -4529.36, 26.82),
    vector3(4519.86, -4514.64, 4.50),
    vector3(4489.08, -4453.93, 4.22),
}

--- Blipas — rodomas tik kai IPL įkrauti (priartėjus)
Config.IslandBlip = {
    enabled = true,
    coords = vector3(4840.57, -5174.42, 2.0),
    sprite = 836,
    color = 2,
    scale = 0.95,
    label = 'Cayo Perico',
}
