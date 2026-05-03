fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_ambulance'
description 'Greitosios pagalbos bazė (LS ligoninės laukas)'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/boss.lua',
}

server_scripts {
    'server/main.lua',
}

dependency 'qb-core'
