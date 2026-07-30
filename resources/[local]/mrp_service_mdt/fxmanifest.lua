fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_service_mdt'
description 'EMS / Mechanic MDT — žemėlapis, dispatch, sąskaitos, EMS + mechanic bylos'
version '1.2.0-phase5'

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
    'server/mdt_incidents.lua',
    'server/main.lua',
}

files {
    'html/index.html',
    'html/app.js',
    'html/incidents.js',
    'html/mechanic_incidents.js',
    'html/style.css',
    'html/gtav_map_core.js',
    'html/mdt_map.js',
    'html/vendor/leaflet.js',
    'html/vendor/leaflet.css',
}

dependencies {
    'qb-core',
    'mrp_dispatch',
    'mrp_ltpd',
    'mrp_mdt_core',
}
