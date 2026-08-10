fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_usedcars'
author 'Project Mayhem'
description 'Naudotų mašinų aikštelė — Mission Row'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/display.lua',
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
    'qb-target',
    'oxmysql',
}
