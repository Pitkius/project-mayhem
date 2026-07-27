fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_jail'
author 'MRP'
description 'Admin / policijos kalėjimas — lėktuvnešis, viešieji darbai, inventoriaus saugojimas'
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
}

dependencies {
    'qb-core',
    'qb-inventory',
}
