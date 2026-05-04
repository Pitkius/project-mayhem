fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_taxi'
description 'Taxi darbas: rangai, apranga, garažas, boss meniu ir saugus taxometras'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/boss.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependency 'qb-core'
