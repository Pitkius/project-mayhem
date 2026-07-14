fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_burglary'
author 'FIVEMPRO'
description 'Namų / butų plėšimai — 4 dydžiai, loot, miegantis NPC, policija'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
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
    'qb-target',
    'oxmysql',
}
