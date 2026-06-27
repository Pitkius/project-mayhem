fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_ambulance'
description 'Greitosios pagalbos postai (Pillbox / Sandy / Paleto MLO)'
version '1.0.0'

shared_scripts {
    'config.lua',
    'config_duty_outfits.lua',
    'config_elevators.lua',
}

client_scripts {
    'client/main.lua',
    'client/boss.lua',
    'client/elevator.lua',
}

server_scripts {
    'server/main.lua',
}

dependency 'qb-core'
