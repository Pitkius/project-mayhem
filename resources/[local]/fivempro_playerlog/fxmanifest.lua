fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_playerlog'
author 'FIVEMPROJEKTAS'
description 'Player activity audit log to MySQL (display name, Steam, QBCore hooks)'
version '1.0.0'

dependency 'qb-core'

shared_scripts {
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}
