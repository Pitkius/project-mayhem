fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_hacking'
author 'FIVEMPROJEKTAS'
description 'Hacking tablets, OS, flashdrives, progressive robberies (ATM + stores + banks + casino + vault)'
version '1.2.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'config_atm.lua',
    'config_robberies.lua',
}

client_scripts {
    'client/main.lua',
    'client/minigames.lua',
    'client/bank_doors.lua',
    'client/heist_doors.lua',
    'client/casino_heist.lua',
    'client/atm.lua',
    'client/robberies.lua',
    'client/vendor_debug.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/atm.lua',
    'server/robberies.lua',
    'server/debug_vendor.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/hackos.css',
    'html/tablet-ui.js',
    'html/app.js',
}

dependencies {
    'qb-core',
    'qb-target',
    'qb-menu',
    'fivempro_dispatch',
}
