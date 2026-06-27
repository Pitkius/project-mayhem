fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_motel'
description 'Motelio viešas sandėlis – viena vieta, asmeninis inventoriaus ID kiekvienam žaidėjui'
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
    'qb-inventory',
    'qb-target',
}
