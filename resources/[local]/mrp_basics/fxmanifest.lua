fx_version 'cerulean'
game 'gta5'

name 'mrp_basics'
author 'MRP'
description 'Minimalus startinis local resource'
version '1.0.0'

ui_page 'html/clothing_radial/index.html'

files {
    'html/clothing_radial/index.html',
    'html/clothing_radial/style.css',
    'html/clothing_radial/app.js',
}

shared_scripts {
    'shared/weapon_carry.lua',
}

client_scripts {
    'client.lua',
    'client/vehicle_lockpick.lua',
    'client/clothing_toggle.lua',
}

server_scripts {
    'server.lua',
    'server/clothing_toggle.lua',
}

exports {
    'IsNaturalNpcVehicle',
    'IsLongBackWeapon',
    'IsBulkyCarryItem',
    'MarkNpcVehicleUnlocked',
    'ToggleClothingSlot',
    'OpenClothingMenu',
    'RestoreAllClothing',
}
