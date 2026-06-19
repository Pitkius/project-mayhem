fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_trucking'
description 'TruckNet Logistics — freelance trucking, companies, cargo economy'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/asset/gtav_satellite_2048.png',
}

shared_scripts {
    'config.lua',
    'shared.lua',
}

client_scripts {
    'client/main.lua',
    'client/logistics.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'qb-core',
    'oxmysql',
    'qb-target',
}

client_exports {
    'OpenTruckNet',
}

server_exports {
    'GetTruckerProfile',
    'OpenTruckNetForPlayer',
}
