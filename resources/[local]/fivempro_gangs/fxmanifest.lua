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
    'html/app.js',
    'html/asset/gtav_satellite.jpg',
    'html/vendor/leaflet.css',
    'html/vendor/leaflet.js',
    'html/vendor/images/marker-icon.png',
    'html/vendor/images/marker-icon-2x.png',
    'html/vendor/images/marker-shadow.png',
}

shared_scripts {
    'config.lua',
    'config_missions.lua',
}

client_scripts {
    'client.lua',
    'client_missions.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
    'server_missions.lua',
}

exports {
    'ApplyGangTurfTask',
    'OnHackSuccess',
    'OnHackFailed',
}

dependencies {
    'qb-core',
    'qb-menu',
    'qb-input',
}
