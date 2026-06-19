fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_service_mdt'
description 'EMS / Mechanic MDT — žemėlapis, dispatch, sąskaitos'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

files {
    'html/index.html',
    'html/app.js',
    'html/style.css',
    'html/gtav_map_core.js',
    'html/mdt_map.js',
    'html/vendor/leaflet.js',
    'html/vendor/leaflet.css',
}

dependencies {
    'qb-core',
    'fivempro_dispatch',
    'fivempro_ltpd',
}
