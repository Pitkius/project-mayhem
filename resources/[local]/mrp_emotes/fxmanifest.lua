fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_emotes'
author 'MRP'
description 'F3 animacijų meniu — eismo stiliai, šokiai, emocijos, scenarijai'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'data/emotes.lua',
}

client_scripts {
    'client/main.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'qb-core',
}
