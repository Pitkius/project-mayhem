fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_dashboard'
author 'Mayhem Roleplay'
description 'ESC Dashboard / player menu NUI + loot crates'
version '1.1.0'

ui_page 'html/index.html'

shared_scripts {
    'shared/config.lua',
    'shared/crates.lua',
}

files {
    'html/index.html',
    'html/assets/crates/*.png',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/progress.lua',
    'server/crates.lua',
    'server/shop.lua',
}

dependency 'qb-core'
dependency 'oxmysql'
