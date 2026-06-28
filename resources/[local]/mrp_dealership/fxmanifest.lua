fx_version 'cerulean'
game 'gta5'

name 'mrp_dealership'
author 'FIVEMPRO'
description 'Custom dealership menu and purchases'
lua54 'yes'

ui_page 'html/index.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
    'config_reh_prices.lua',
}

client_scripts {
    'client.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/images/vehicles/*.webp',
    'html/images/vehicles/*.jpg',
    'html/images/vehicles/*.png',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

dependencies {
    'qb-core',
    'mrp_vehicle_perf',
    'mrp_plates',
}
