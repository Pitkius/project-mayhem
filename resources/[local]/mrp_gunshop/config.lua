Config = {}

Config.LicenseItem = 'weaponlicense'
Config.LicenseLabel = 'Ginklo licencija'
Config.LicenseValidityDays = 730
Config.ShopOpenDistance = 5.0

Config.PedModel = 's_m_y_ammucity_01'
Config.PedScenario = 'WORLD_HUMAN_CLIPBOARD'

Config.Blip = {
    sprite = 110,
    colour = 1,
    scale = 0.85,
    label = 'Ginklų parduotuvė',
}

--- Licencijuota parduotuvė — tik su galiojančia ginklo licencija
Config.Shop = {
    name = 'fivempro-gun-shop',
    label = 'Ginklų parduotuvė',
    license = 'weaponlicense',
    items = {
        { name = 'weapon_pistol', amount = 50, price = 120000, slot = 1 },
        { name = 'pistol_ammo', amount = 500, price = 250, slot = 2 },
        { name = 'hunting_ammo', amount = 500, price = 55, slot = 3 },
        { name = 'weapon_knife', amount = 100, price = 1800, slot = 4 },
        { name = 'armor_light', amount = 100, price = 4500, slot = 5 },
        { name = 'flashlight_attachment', amount = 200, price = 3200, slot = 6 },
    },
}

--- Vanilla Ammu-Nation vietos + Topacio (La Mesa zona)
Config.Locations = {
    { id = 'legion', label = 'Legion Square', coords = vector4(22.56, -1105.53, 29.79, 160.0), blip = true },
    { id = 'hawick', label = 'Hawick', coords = vector4(252.89, -49.87, 69.94, 70.0), blip = true },
    { id = 'topacio', label = 'Topacio', coords = vector4(842.41, -1033.42, 28.19, 270.0), blip = true },
    { id = 'paleto', label = 'Paleto Bay', coords = vector4(-330.24, 6083.88, 31.45, 225.0), blip = true },
}
