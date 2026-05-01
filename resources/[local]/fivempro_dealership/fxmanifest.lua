fx_version 'cerulean'
game 'gta5'

name 'fivempro_dealership'
author 'FIVEMPRO'
description 'Custom dealership menu and purchases'
lua54 'yes'

ui_page 'html/index.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
