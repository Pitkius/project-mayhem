fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_elevators'
author 'MRP'
description 'PD / EMS liftai — aukšto pasirinkimas (teleport)'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

dependencies {
    'qb-core',
    'qb-menu',
    'qb-target',
}
