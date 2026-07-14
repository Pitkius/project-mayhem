fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_antighostpeek'
author 'MRP'
description 'Anti ghost peek — blokuoja nesąžiningus šūvius per kampą (tik PvP, ne taikymąsi į sieną)'
version '2.0.0'

dependencies {
    'qb-core',
}

shared_scripts {
    'config.lua',
}

client_scripts {
    '@mrp_hud/client/theme_nui_consumer.lua',
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
