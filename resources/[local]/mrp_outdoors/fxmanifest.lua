fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_outdoors'
description 'Freelance žvejyba ir medžioklė — licencijos, minigame, Gabz ranger'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'shared/animal_loot.lua',
}

client_scripts {
    '@mrp_hud/client/theme_nui_consumer.lua',
    'client/main.lua',
    'client/animals.lua',
    'client/musket.lua',
}

server_scripts {
    'server/main.lua',
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
    'qb-inventory',
}
