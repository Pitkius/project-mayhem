fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_spawnfix'
author 'FIVEMPROJEKTAS'
description 'Direct spawn at last disconnect — no multichar / spawn picker'
version '2.0.0'

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
    'oxmysql',
}

server_exports {
    'SyncQBCoreAdmin',
}
