fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_mechanic'
description 'LS mechanikų bazė – sandėlis, rūbinė, remonto vietos, garažas/salonas'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/bay_menu.lua',
    'client/boss.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependency 'qb-core'
