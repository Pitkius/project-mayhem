fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_siren_controller'
author 'FIVEMPROJEKTAS'
description 'Police & EMS premium siren controller (Neon Purple NUI)'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/audio.lua',
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
