fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_housing'
author 'MRP'
description 'Dynasty 8 — būsto klasės, interjerų užraktas, Su baldais / Be baldų, raktai'
version '1.1.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'shared.lua',
}

client_scripts {
    '@mrp_hud/client/theme_nui_consumer.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'qb-core',
    'oxmysql',
    'qb-target',
    'qb-inventory',
}

--- Raktų meniu (duoti / atšaukti)
-- qb-menu, qb-input
