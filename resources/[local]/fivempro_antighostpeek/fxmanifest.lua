fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_antighostpeek'
author 'FIVEMPROJEKTAS'
description 'Anti ghost peek — blokuoja saudymą per sienas, rodo violetinį indikatorių'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}
