fx_version 'cerulean'
game 'gta5'

name 'fivempro_hud'
author 'FIVEMPROJEKTAS'
description 'Minimal QBCore HUD (core survival + vehicle essentials)'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/assets/vehicles/default.svg',
    'html/assets/vehicles/*.png',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}

exports {
    'OpenVehicleQuickMenu',
    'ToggleVehicleControlPanel',
}

