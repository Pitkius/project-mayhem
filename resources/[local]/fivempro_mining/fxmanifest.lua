fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_mining'
description 'Skaldakasys — freelance kasimas, perdirbimas, supirkimas'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependency 'qb-core'
