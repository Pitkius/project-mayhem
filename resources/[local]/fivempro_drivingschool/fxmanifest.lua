fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_drivingschool'
description 'Vairavimo mokykla — A/B/C kategorijos (teorija + praktika)'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'qb-core',
    'qb-target',
    'qb-menu',
}
