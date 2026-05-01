fx_version 'cerulean'
game 'gta5'

name 'fivempro_garages'
author 'FIVEMPRO'
description 'Public garages with blips and vehicle storage'
lua54 'yes'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
