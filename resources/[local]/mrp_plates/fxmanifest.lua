fx_version 'cerulean'
game 'gta5'

name 'mrp_plates'
author 'MRP'
description 'MRP EU/LT style license plates and 111 AAA number format'
lua54 'yes'

shared_scripts {
    'config.lua',
    'shared.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

files {
    'textures/plate01.png',
}
