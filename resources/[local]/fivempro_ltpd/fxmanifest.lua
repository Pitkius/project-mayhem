fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_ltpd'
author 'FIVEMPROJEKTAS'
description 'Lietuvos policija – rangai, padaliniai, MDT (QBCore)'
version '1.0.0'

ui_page 'html/mdt/index.html'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

files {
    'html/mdt/index.html',
    'html/mdt/app.js',
    'html/mdt/style.css',
}

dependency 'qb-core'
-- qb-menu (garažo meniu), qb-inventory (ginklinė / stash), qb-target (zonos)
