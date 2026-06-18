fx_version 'cerulean'
game 'gta5'

name 'fivempro_basics'
author 'FIVEMPROJEKTAS'
description 'Minimalus startinis local resource'
version '1.0.0'

client_scripts {
    'client.lua',
    'client/vehicle_lockpick.lua',
    'client/clothing_toggle.lua',
    'client/reports.lua',
}

server_scripts {
    'server.lua',
    'server/clothing_toggle.lua',
    'server/reports.lua',
}

exports {
    'IsNaturalNpcVehicle',
    'IsLongBackWeapon',
    'MarkNpcVehicleUnlocked',
    'ToggleClothingSlot',
    'OpenClothingMenu',
}
