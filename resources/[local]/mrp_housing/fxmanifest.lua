fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_housing'
author 'MRP'
description 'Dynasty 8 nekilnojamasis turtas — unikalūs namai/butai, interjero pasirinkimas'
version '1.0.0'

ui_page 'html/index.html'

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

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'qb-core',
    'oxmysql',
    'qb-target',
    'qb-inventory',
}
