fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_radio'
description 'Fizinės racijos UI — dažnis ranka, serverio teisės, overlay'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'shared/frequency.lua',
}

client_scripts {
    '@mrp_hud/client/theme_nui_consumer.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'qb-core',
}
