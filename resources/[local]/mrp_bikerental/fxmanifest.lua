fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_bikerental'
description 'Dviračių nuoma — taškai po visą mapą su blipais'
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
