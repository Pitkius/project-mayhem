fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_fuel'
description 'Vanilla degalinės: blipai ir kuro pildymas ant QBCore/QB-fuel bazės'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}

dependency 'qb-core'

