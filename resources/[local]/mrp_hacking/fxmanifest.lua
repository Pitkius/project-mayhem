fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_hacking'
author 'MRP'
description 'Hacking tablets, OS, flashdrives, progressive robberies (ATM + stores + banks + casino + vault)'
version '1.2.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'config_atm.lua',
    'config_robberies.lua',
}

client_scripts {
    '@mrp_hud/client/theme_nui_consumer.lua',
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
    'html/icons.svg',
    'html/style.css',
    'html/hackos.css',
    'html/tablet-ui.js',
    'html/app.js',
    'html/asset/gtav_satellite_2048.png',
}

dependencies {
    'qb-core',
    'qb-target',
    'qb-menu',
    'qb-input',
    'mrp_dispatch',
}
