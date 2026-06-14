Config = {}

Config.IslandCenter = vector3(4840.57, -5174.42, 2.0)
Config.IslandLoadRadius = 2400.0

--- Papildomos zonos, kur forsuojamas collision (šiaurės dokai / kokos laukas)
Config.StreamZones = {
    vector3(4715.03, -4529.36, 26.82),
    vector3(4519.86, -4514.64, 4.50),
    vector3(4489.08, -4453.93, 4.22),
}

--- Blipas žemėlapyje (salos centras)
Config.IslandBlip = {
    enabled = true,
    coords = vector3(4840.57, -5174.42, 2.0),
    sprite = 836,
    color = 2,
    scale = 0.95,
    label = 'Cayo Perico',
}
