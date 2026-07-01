fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_restraints'
description 'Apieškojimas ir surakinimas (qb-target ALT meniu)'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/progress.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'qb-core',
    'qb-target',
    'qb-inventory',
}
