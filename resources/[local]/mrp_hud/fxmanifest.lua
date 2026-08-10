fx_version 'cerulean'
game 'gta5'

name 'mrp_hud'
author 'MRP'
description 'Minimal QBCore HUD (core survival + vehicle essentials)'
version '1.0.1'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/assets/icons/*.png',
    'html/assets/vehicles/default.svg',
    'html/assets/vehicles/car-schema-topdown.svg',
    'html/assets/vehicles/vehicle-topdown.png',
    'html/assets/vehicles/*.png',
    'html/assets/mayhem_logo.png',
    'html/assets/mayhem_icon.png',
    'html/assets/mayhem_mark.png',
}

client_scripts {
    'client/ui_theme.lua',
    'client.lua',
    'client/theme_nui_consumer.lua',
}

server_scripts {
    'server.lua',
}

exports {
    'OpenVehicleQuickMenu',
    'ToggleVehicleControlPanel',
    'GetPlayerTheme',
    'BuildPlayerTheme',
}
