fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_mechanic'
description 'LS mechanikų bazė – sandėlis, rūbinė, remonto vietos, garažas/salonas'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/doors.lua',
    'client/bay_menu.lua',
    'client/boss.lua',
    'client/vendor_debug.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/doors.lua',
}

dependency 'qb-core'
