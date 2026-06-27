fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_ranger'
description 'Gamtosaugininkai — baudos, antrankiai, garažas, sandėlis'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
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

dependencies {
    'qb-core',
    'qb-target',
    'qb-menu',
    'qb-input',
    'qb-inventory',
    'mrp_garages',
}
