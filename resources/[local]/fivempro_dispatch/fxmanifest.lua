fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_dispatch'
description 'Fivempro unified dispatch, crews, faction blips, panic alerts'
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
}

