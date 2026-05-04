fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_phone'
description 'Bazinis telefonas: skambučiai, žinutės, kontaktai, skelbimai, social feed'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/death.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependency 'qb-core'
dependency 'qb-inventory'
