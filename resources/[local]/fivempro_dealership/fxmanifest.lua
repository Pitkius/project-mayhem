fx_version 'cerulean'
game 'gta5'

name 'fivempro_dealership'
author 'FIVEMPRO'
description 'Custom dealership menu and purchases'
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
