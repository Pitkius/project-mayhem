fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_vehicle_perf'
author 'FIVEMPROJEKTAS'
description 'Realistiški max greičiai, pagreitis, stabdymas, vairavimas ir kainos'
version '1.2.0'

shared_scripts {
    'config.lua',
    'shared/pricing.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}

dependencies {
    'qb-core',
}
