Config = {}

Config.IslandCenter = vector3(4840.57, -5174.42, 2.0)

--- Kada pradėti krauti salą (tik šiam klientui, pagal atstumą)
Config.StreamRadius = 2800.0
--- Kada iškrauti (šiek tiek didesnis — kad nejunginėtų prie sienos)
Config.UnloadRadius = 3100.0
--- Kada rodyti salos minimapą / interior radar
Config.MinimapRadius = 2000.0

--- @deprecated naudok MinimapRadius
Config.IslandLoadRadius = Config.MinimapRadius

--- Papildomos zonos, kur forsuojamas collision (šiaurės dokai / kokos laukas)
Config.StreamZones = {
    vector3(4715.03, -4529.36, 26.82),
    vector3(4519.86, -4514.64, 4.50),
    vector3(4489.08, -4453.93, 4.22),
}

--- Blipas žemėlapyje (salos centras) — rodomas visada, IPL nereikia
Config.IslandBlip = {
    enabled = true,
    coords = vector3(4840.57, -5174.42, 2.0),
    sprite = 836,
    color = 2,
    scale = 0.95,
    label = 'Cayo Perico',
}
