fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_mining'
description 'Skaldakasys — freelance kasimas, perdirbimas, supirkimas'
version '1.2.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

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
