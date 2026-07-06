fx_version 'cerulean'
game 'gta5'

name 'mrp_kma'
author 'FIVEMPRO'
description 'Impound lot (KMA) — retrieve out-of-garage vehicles for a fee'
lua54 'yes'

ui_page 'html/index.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
    '@mrp_dealership/config_reh_prices.lua',
}

client_scripts {
    'client.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'qb-core',
    'mrp_dealership',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}
