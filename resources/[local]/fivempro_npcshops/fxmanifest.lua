fx_version 'cerulean'
game 'gta5'

name 'fivempro_npcshops'
author 'FIVEMPRO'
description 'NPC barber, 24/7, clothing, tattoo, pharmacy shops'
lua54 'yes'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
    'config_jobshops.lua',
}

client_scripts {
    'client.lua',
    'client_jobshops.lua',
}

server_scripts {
    'server.lua',
    'server_jobshops.lua',
}
