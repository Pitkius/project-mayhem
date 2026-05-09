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
    'html/app.js'
}

client_scripts {
    'client.lua'
}

exports {
    'OpenVehicleQuickMenu'
}

