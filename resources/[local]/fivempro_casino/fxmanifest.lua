fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_casino'
author 'FIVEMPROJEKTAS'
description 'Diamond Casino — ratas, blackjack, ruletė, automatai, /dice'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
}

client_scripts {
    'client/ipl.lua',
    'client/entrance.lua',
    'client/main.lua',
    'client/dice.lua',
    'client/wheel.lua',
    'client/blackjack.lua',
    'client/roulette.lua',
    'client/slots.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'qb-core',
    'qb-target',
    'qb-menu',
    'oxmysql',
}
