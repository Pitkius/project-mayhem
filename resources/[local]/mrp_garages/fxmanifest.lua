fx_version 'cerulean'
game 'gta5'

name 'mrp_garages'
author 'FIVEMPRO'
description 'Public garages with blips and vehicle storage'
lua54 'yes'

ui_page 'html/index.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
    '@mrp_dealership/config_reh_prices.lua',
}

client_scripts {
    '@mrp_hud/client/theme_nui_consumer.lua',
    'client.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/assets/vehicles/default.webp',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

dependencies {
    'qb-core',
    'mrp_dealership',
    'mrp_bossmenu',
}
