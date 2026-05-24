fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_hacking'
author 'FIVEMPROJEKTAS'
description 'Hacking tablets, OS, flashdrives, progressive robberies (ATM)'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'config_atm.lua',
}

client_scripts {
    'client/main.lua',
    'client/atm.lua',
    'client/vendor_debug.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/atm.lua',
    'server/debug_vendor.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'qb-core',
    'qb-target',
    'qb-menu',
    'fivempro_dispatch',
}
