fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_phone'
description 'PhoneID-centrinė Legal + DarkNet telefonų sistema'
version '3.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/apps.js',
    'html/phone-apps.css',
    'html/phone-ads.css',
    'html/phone-bank.css',
    'html/phone-camera.js',
    'html/phone-carplay.js',
    'html/phone-ads.js',
    'html/phone-image.js',
    'html/phone-bank-icons.js',
    'html/phone-bank.js',
    'html/phone-weather.js',
    'html/phone-weather.css',
    'html/phone-notes.js',
    'html/phone-notes.css',
    'html/phone-darknet.css',
    'html/phone-darknet.js',
    'html/death-screen.css',
    'html/death-screen.js',
    'html/locale/lt.js',
    'html/assets/icons/*.svg',
}

shared_scripts {
    'config.lua',
    'shared/phone_types.lua',
    'shared/phone_states.lua',
    'shared/apps.lua',
}

client_scripts {
    'client/main.lua',
    'client/device.lua',
    'client/camera.lua',
    'client/carplay.lua',
    'client/bank.lua',
    'client/death.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/core/db.lua',
    'server/core/identity.lua',
    'server/core/pin.lua',
    'server/core/session.lua',
    'server/core/phones.lua',
    'server/core/factory_reset.lua',
    'server/core/police.lua',
    'server/core/lifecycle.lua',
    'server/media.lua',
    'server/main.lua',
    'server/data_phoneid.lua',
    'server/bank.lua',
    'server/carplay.lua',
    'server/apps/darknet_bridge.lua',
    'server/apps/encrypted.lua',
}

dependency 'mrp_fonts'
dependency 'qb-core'
dependency 'qb-inventory'
dependency 'screenshot-basic'
