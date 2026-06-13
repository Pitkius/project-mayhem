fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_phone'
description 'Bazinis telefonas: skambučiai, žinutės, kontaktai, skelbimai, social feed'
version '2.1.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/apps.js',
    'html/phone-apps.css',
    'html/phone-bank.css',
    'html/phone-camera.js',
    'html/phone-carplay.js',
    'html/phone-ads.js',
    'html/phone-bank-icons.js',
    'html/phone-bank.js',
    'html/death-screen.css',
    'html/death-screen.js',
    'html/locale/lt.js',
    'html/assets/icons/*.svg',
}

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/camera.lua',
    'client/carplay.lua',
    'client/bank.lua',
    'client/death.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/bank.lua',
    'server/carplay.lua',
}

dependency 'fivempro_fonts'
dependency 'qb-core'
dependency 'qb-inventory'
dependency 'screenshot-basic'
