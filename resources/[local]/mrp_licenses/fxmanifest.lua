fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_licenses'
description 'RP license card display (NUI)'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/assets/mayhem_logo.png',
}

dependencies {
    'qb-core',
}
