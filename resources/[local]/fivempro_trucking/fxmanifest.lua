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
}

shared_scripts {
    'config.lua',
    'shared.lua',
}

client_scripts {
    'client/main.lua',
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

exports {
    'OpenTruckNet',
    'GetTruckerProfile',
}
