fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_vehicle_perf'
author 'MRP'
description 'Realistiški max greičiai, pagreitis, stabdymas, vairavimas ir kainos'
version '1.5.0'

shared_scripts {
    'config.lua',
    'config_surface.lua',
    'shared/pricing.lua',
    'shared/vanilla_max_kmh.lua',
}

client_scripts {
    'client.lua',
    'client/surface_handling.lua',
    'client/impact_shake.lua',
}

server_scripts {
    'server.lua',
}

dependencies {
    'qb-core',
}
