fx_version 'cerulean'
game 'gta5'

name 'mrp_garages'
author 'FIVEMPRO'
description 'Public garages with blips and vehicle storage'
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
    'html/app.js',
    'html/assets/vehicles/default.webp',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
