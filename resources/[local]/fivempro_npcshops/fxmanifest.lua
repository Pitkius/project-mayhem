fx_version 'cerulean'
game 'gta5'

name 'fivempro_npcshops'
author 'FIVEMPRO'
description 'NPC barber, food, and clothing shops'
lua54 'yes'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}
