fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_mechanic'
description 'LS mechanikų bazė – sandėlis, rūbinė, remonto vietos, garažas/salonas'
version '1.1.0'

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
}

shared_scripts {
    'config.lua',
}

client_scripts {
    '@mrp_hud/client/theme_nui_consumer.lua',
    'client/main.lua',
    'client/field_repair.lua',
    'client/material_supply.lua',
    'client/craft_ui.lua',
    'client/doors.lua',
    'client/workshop_ui.lua',
    'client/boss.lua',
    'client/vendor_debug.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/material_supply.lua',
    'server/doors.lua',
}

dependency 'qb-core'
dependency 'mrp_hud'
