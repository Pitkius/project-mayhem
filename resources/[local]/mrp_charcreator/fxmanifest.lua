fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_charcreator'
author 'MRP'
description 'Premium neon purple personažo kūrimas (LT) – pakeičia QB multichar'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

shared_scripts {
    'shared/countries.lua',
    'config.lua',
    'shared/tattoos.lua',
}

client_scripts {
    '@mrp_hud/client/theme_nui_consumer.lua',
    'client/appearance.lua',
    'client/tattoos.lua',
    'client/camera.lua',
    'client/main.lua',
    'client/shops.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

exports {
    'OpenWizard',
    'IsInCreator',
    'OpenBarber',
    'OpenClothing',
    'OpenTattoo',
    'ApplyTattoos',
}

dependencies {
    'mrp_fonts',
    'qb-core',
    'qb-clothing',
    'oxmysql',
}
