fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_gangs'
description 'Gang tablet, turf and drug selling system'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/admin.css',
    'html/app.js',
    'html/admin.js',
    'html/gtav_map_core.js',
    'html/map.js',
    'html/asset/gtav_satellite.jpg',
    'html/asset/gtav_satellite_2048.png',
    'html/vendor/leaflet.css',
    'html/vendor/leaflet.js',
    'html/vendor/images/marker-icon.png',
    'html/vendor/images/marker-icon-2x.png',
    'html/vendor/images/marker-shadow.png',
}

shared_scripts {
    'config.lua',
    'config_turf_cells.lua',
    'config_missions.lua',
}

client_scripts {
    'client_progress.lua',
    'client.lua',
    'client_missions.lua',
    'client_graffiti.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server_admin.lua',
    'server.lua',
    'server_missions.lua',
}

exports {
    'ApplyGangTurfTask',
    'AddTurfInfluence',
    'CompleteGangMission',
    'OnHackSuccess',
    'OnHackFailed',
}

dependencies {
    'qb-core',
    'qb-menu',
    'qb-input',
}
