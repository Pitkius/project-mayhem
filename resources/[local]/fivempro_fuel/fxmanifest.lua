fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_fuel'
description 'Degalinės, kuro suvartojimas važiuojant, pildymas'
version '1.1.0'

exports {
    'GetFuel',
    'SetFuel',
}

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

