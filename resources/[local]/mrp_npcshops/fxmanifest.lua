fx_version 'cerulean'
game 'gta5'

name 'mrp_npcshops'
author 'FIVEMPRO'
description 'NPC barber, 24/7, clothing, tattoo, pharmacy shops (server-synced peds)'
lua54 'yes'

dependency 'mrp_fonts'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
    'config_jobshops.lua',
    'shared/npc_registry.lua',
}

client_scripts {
    'client/barber.lua',
    'client/peds.lua',
    'client/job_markers.lua',
    'client/junk_markers.lua',
    'client_jobshops.lua',
}

server_scripts {
    'server.lua',
    'server_jobshops.lua',
    'server/peds.lua',
}
