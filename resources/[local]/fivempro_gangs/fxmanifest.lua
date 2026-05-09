fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_gangs'
description 'Gang tablet, turf and drug selling system'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

dependencies {
    'qb-core',
    'qb-menu',
    'qb-input',
}
