fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_interrogation'
author 'MRP'
description 'Policijos apklausa ir RP spaudimas (be žalojimo) + MDT'
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


server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/kits.lua',
}

client_scripts {
    '@mrp_hud/client/theme_nui_consumer.lua',
    'client/scene.lua',
    'client/gang_kit.lua',
    'client/police.lua',
    'client/test_shop.lua',
    'client/main.lua',
}

dependencies {
    'qb-core',
    'qb-target',
    'qb-menu',
    'qb-input',
    'oxmysql',
    'mrp_ltpd',
}
