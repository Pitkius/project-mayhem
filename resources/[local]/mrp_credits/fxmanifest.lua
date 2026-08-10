fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_credits'
author 'Mayhem Roleplay'
description 'Premium credits (1 EUR = 1 CR) + Tebex delivery'
version '1.0.0'

shared_scripts {
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

dependency 'qb-core'
dependency 'oxmysql'
