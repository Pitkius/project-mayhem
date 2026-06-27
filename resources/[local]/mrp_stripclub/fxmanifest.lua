fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_stripclub'
description 'Vanilla Unicorn / Gabz VU — striptizo šokėjos, privatus šokis, kėdės'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/lapdance.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'qb-core',
    'qb-target',
    'qb-menu',
}
