fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_vehiclemenu'
description 'M klavišo transporto meniu, lock/doors/engine ir variklio gedimo logika'
version '1.0.0'

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}

dependencies {
    'qb-core',
    'qb-menu',
    'fivempro_hud',
}

exports {
    'IsEngineStartBlocked',
    'GetEngineStartBlockSecondsLeft',
}

